#!/usr/bin/env python3
"""Job-aware scanner for secret-derived data crossing a job boundary.

Plan 2608-04 (FOR-517/FOR-519). The class it exists to catch:

    jobs:
      resolve:
        env:
          PEM: ${{ secrets.E2E_UNIVOCITY_ES256_BOOTSTRAP_PEM }}   # job-level
        outputs:
          pem: ${{ steps.resolve.outputs.pem }}                   # egress
      tests:
        needs: resolve
        env:
          PEM: ${{ needs.resolve.outputs.pem }}                   # always empty

GitHub **silently drops** any job output whose value contains a registered
secret — one `Skip output '…' since it may contain secret` line in a job nobody
reads — and the consumer receives an empty string with no error anywhere. In
canopy that path had been dead since the tier was built and stayed invisible
until a chain-anchor gate made key identity matter; it cost a full debugging
cycle (canopy#211). Nothing about the workflow source says it cannot work, so
this scanner is the only thing that can say it at authoring time.

Two rules, both job-aware, because the discovered instance used **job-level**
env plus a job-level `outputs:` map — step-granular scanning misses it entirely:

  R1  a job that references `secrets.*` anywhere (job env, step env, `with:`,
      `run:` bodies) and whose `outputs:` map any `steps.*.outputs.*`.
  R2  a reusable workflow whose `on.workflow_call.outputs` re-export the
      outputs of a job that references `secrets.*` — the same egress, one
      boundary further out.

Triaged-benign cases are annotated in place with `# secret-egress-ok: <reason>`
inside the job (or the output entry for R2). The reason is printed, so the
exception trail is readable rather than silent.

Usage:  secret-egress-lint.py [PATH ...]      (default: .github/workflows)
Exit 1 when any unannotated finding remains.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - the action installs it first
    sys.stderr.write(
        "::error::PyYAML is required by secret-egress-lint and is not importable\n"
    )
    raise SystemExit(1)

SECRET_RE = re.compile(r"secrets\.[A-Za-z_][A-Za-z0-9_-]*")
STEP_OUTPUT_RE = re.compile(r"steps\.[A-Za-z0-9_-]+\.outputs\.")
JOB_OUTPUT_RE = re.compile(r"jobs\.([A-Za-z0-9_-]+)\.outputs\.")
ANNOTATION_RE = re.compile(r"#\s*secret-egress-ok:\s*(\S.*?)\s*$")

WORKFLOW_SUFFIXES = (".yml", ".yaml")


class Finding:
    def __init__(self, path, line, job, rule, detail, waiver=None):
        self.path = path
        self.line = line
        self.job = job
        self.rule = rule
        self.detail = detail
        self.waiver = waiver

    @property
    def waived(self):
        return self.waiver is not None


def child(node, key):
    """Value node for `key` in a mapping node, or None."""
    if not isinstance(node, yaml.MappingNode):
        return None
    for k, v in node.value:
        if isinstance(k, yaml.ScalarNode) and k.value == key:
            return v
    return None


def child_pair(node, key):
    """(key node, value node) for `key`, so the key's own line is available."""
    if not isinstance(node, yaml.MappingNode):
        return None, None
    for k, v in node.value:
        if isinstance(k, yaml.ScalarNode) and k.value == key:
            return k, v
    return None, None


def scalars(node):
    """Every scalar string reachable from `node`."""
    if node is None:
        return
    if isinstance(node, yaml.ScalarNode):
        yield node.value
    elif isinstance(node, yaml.SequenceNode):
        for item in node.value:
            yield from scalars(item)
    elif isinstance(node, yaml.MappingNode):
        for k, v in node.value:
            yield from scalars(k)
            yield from scalars(v)


def references_secret(node):
    return any(SECRET_RE.search(s or "") for s in scalars(node))


def waiver_for(lines, key_node, value_node):
    """The `# secret-egress-ok:` reason covering this block, if any.

    The span runs from the contiguous comment block immediately above the key
    down to the end of its value, so the annotation can sit either above the
    job (the natural place for a written justification) or inside it.
    """
    start = key_node.start_mark.line
    while start > 0 and lines[start - 1].strip().startswith("#"):
        start -= 1
    end = min(value_node.end_mark.line, len(lines))
    for raw in lines[start:end]:
        m = ANNOTATION_RE.search(raw)
        if m:
            return m.group(1)
    return None


def scan_file(path: Path):
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    try:
        root = yaml.compose(text)
    except yaml.YAMLError as exc:
        return [Finding(path, 1, "-", "parse", f"unparseable YAML: {exc}")]

    if not isinstance(root, yaml.MappingNode):
        return []

    jobs = child(root, "jobs")
    if jobs is None:
        return []  # an action.yml or a fragment, not a workflow

    findings = []
    exposed_jobs = {}

    for job_key, job_val in jobs.value:
        if not isinstance(job_key, yaml.ScalarNode):
            continue
        name = job_key.value
        # `secrets:` on a reusable-workflow call passes secrets into the callee
        # (including `secrets: inherit`), so it counts as exposure even though
        # no `${{ secrets.* }}` appears in this job.
        exposed = references_secret(job_val) or child(job_val, "secrets") is not None
        exposed_jobs[name] = exposed
        if not exposed:
            continue

        out_key, out_val = child_pair(job_val, "outputs")
        if out_val is None:
            continue
        egress = [s for s in scalars(out_val) if STEP_OUTPUT_RE.search(s or "")]
        if not egress:
            continue

        findings.append(
            Finding(
                path,
                out_key.start_mark.line + 1,
                name,
                "R1",
                "job touches `secrets.*` and maps step outputs into `outputs:` — "
                "GitHub drops any output containing a secret value, silently",
                waiver_for(lines, job_key, job_val),
            )
        )

    # `compose` keeps keys as literal scalars, so the bare `on:` key stays the
    # string "on" here. A loaded document would have resolved it to True (YAML
    # 1.1 booleans) and this lookup would silently find nothing — one more
    # reason the scanner works on the node tree rather than on loaded objects.
    on_node = child(root, "on")
    wc_outputs = child(child(on_node, "workflow_call"), "outputs")
    if isinstance(wc_outputs, yaml.MappingNode):
        for out_key, out_val in wc_outputs.value:
            if not isinstance(out_key, yaml.ScalarNode):
                continue
            for text_val in scalars(out_val):
                for job_name in JOB_OUTPUT_RE.findall(text_val or ""):
                    if not exposed_jobs.get(job_name):
                        continue
                    findings.append(
                        Finding(
                            path,
                            out_key.start_mark.line + 1,
                            job_name,
                            "R2",
                            f"`workflow_call` re-exports `{out_key.value}` from job "
                            f"`{job_name}`, which touches `secrets.*` — the egress "
                            "just crosses one boundary further out",
                            waiver_for(lines, out_key, out_val),
                        )
                    )

    return findings


def collect(paths):
    files = []
    for p in paths:
        path = Path(p)
        if path.is_dir():
            files.extend(
                sorted(f for f in path.rglob("*") if f.suffix in WORKFLOW_SUFFIXES)
            )
        elif path.suffix in WORKFLOW_SUFFIXES:
            files.append(path)
        else:
            sys.stderr.write(f"::error::{p} is neither a directory nor a workflow\n")
            raise SystemExit(1)
    return files


def main(argv):
    paths = argv[1:] or [".github/workflows"]
    files = collect(paths)
    if not files:
        # Nothing scanned is not the same as nothing wrong. Say so and fail:
        # a lint that silently passes over zero files is how coverage rots.
        sys.stderr.write(
            f"::error::secret-egress-lint found no workflow files under {', '.join(paths)}\n"
        )
        return 1

    findings = []
    for f in files:
        findings.extend(scan_file(f))

    violations = [f for f in findings if not f.waived]
    waived = [f for f in findings if f.waived]

    for f in violations:
        print(
            f"::error file={f.path},line={f.line}::[{f.rule}] job '{f.job}': {f.detail}"
        )
    for f in waived:
        print(f"{f.path}:{f.line} [{f.rule}] job '{f.job}': waived — {f.waiver}")

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    out = open(summary_path, "a", encoding="utf-8") if summary_path else sys.stdout
    try:
        print(f"\n## secret-egress-lint\n", file=out)
        print(
            f"{len(files)} workflow file(s) scanned · "
            f"**{len(violations)} violation(s)** · {len(waived)} annotated exception(s)\n",
            file=out,
        )
        if findings:
            print("| Where | Job | Rule | Disposition |", file=out)
            print("| --- | --- | --- | --- |", file=out)
            for f in findings:
                disp = f"annotated: {f.waiver}" if f.waived else "**VIOLATION**"
                print(f"| `{f.path}:{f.line}` | `{f.job}` | {f.rule} | {disp} |", file=out)
            print("", file=out)
        if violations:
            print(
                "Secret-derived data must never cross a job boundary: read the "
                "env-scoped secret at point of use instead. Annotate a triaged-benign "
                "job with `# secret-egress-ok: <reason>`. See "
                "[the CI policy](https://github.com/forestrie/.github/blob/main/docs/ci-policy.md).",
                file=out,
            )
    finally:
        if summary_path:
            out.close()

    return 1 if violations else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
