# `secret-egress-lint`

Fails any workflow that moves secret-derived data across a job boundary.

Plan [2608-04](https://github.com/forestrie/devdocs/blob/main/plans/plan-2608-04-secret-egress-audit-and-lint.md)
· FOR-517 / FOR-519. Policy: [docs/ci-policy.md](../../docs/ci-policy.md).

## The behaviour it exists to catch

**GitHub silently drops a job output whose value contains a registered secret.**
It logs `Skip output '…' since it may contain secret` in a job nobody reads,
sets the output to the empty string, and fails nothing. The consumer job gets
`""` and breaks somewhere unrelated.

In canopy this meant the T3 tier had been passing the ES256 bootstrap PEM
through a job output since the tier was built. The path was dead the whole time
and stayed invisible until a chain-anchor gate made key identity matter — then
it cost a full debugging cycle to find (canopy#211). Nothing about the workflow
source says it cannot work. That is precisely why it needs a machine to say so.

## Rules

| Rule | Flags                                                                                                                              |
| ---- | ---------------------------------------------------------------------------------------------------------------------------------- |
| R1   | a job that references `secrets.*` **anywhere** (job env, step env, `with:`, `run:` body, or `secrets:` on a reusable-workflow call) and whose `outputs:` map any `steps.*.outputs.*` |
| R2   | a reusable workflow whose `on.workflow_call.outputs` re-export the outputs of such a job — the same egress, one boundary further out |

Job-aware on purpose. The discovered instance used **job-level** env plus a
job-level `outputs:` map, so the secret and the output mapping were never in the
same step: a step-granular scan sees nothing.

The scanner is deliberately blunt about what counts as exposure. It cannot tell
a token used to *call* an API from a token about to be written into an output,
so it flags both and asks a human to say which this is. That decision is
recorded in the file, next to the code it justifies:

```yaml
jobs:
  # secret-egress-ok: GH_TOKEN authenticates the lookup; the output is the tag name it returned, not secret-derived
  release-meta:
    outputs:
      tag: ${{ steps.meta.outputs.tag }}
```

The annotation may sit above the job or anywhere inside it (for R2, on the
output entry). Waived findings are still printed, with their reason, so the
exception trail stays readable rather than disappearing.

## Usage

Beside `actionlint`, in the same workflow-lint job:

```yaml
- uses: forestrie/.github/actions/secret-egress-lint@main
```

Scan somewhere other than `.github/workflows`:

```yaml
- uses: forestrie/.github/actions/secret-egress-lint@main
  with:
    paths: .github/workflows some/other/workflows
```

## The fix, not the annotation

The remediation pattern is canopy#211's: **the consumer reads the env-scoped
secret at point of use.** Secret-derived data never crosses a job boundary, and
there is no sanctioned exception path — a genuine future need restructures its
jobs. The annotation is for jobs that were never carrying a secret across in the
first place.

## Limits

- Scanning nothing fails. An empty target is a broken invocation, and a lint
  that passes over zero files is how coverage rots.
- The **log-echo** class is policy-enforced only: GitHub's masking covers exact
  secret strings, so a base64 or a prefix of a secret prints in clear. v1 does
  not detect that; the rule is written in the policy doc and a lint can follow
  if the class recurs.

## Tests

```
bash actions/secret-egress-lint/selftest.sh
```

Fixtures in [`fixtures/`](./fixtures) cover the job-level true positive (the
canopy#211 shape), the step-level one, the `workflow_call` re-export, an
annotated benign job, the clean point-of-use pattern, and the empty-target case.
Each fixture states its expectation in its own header. They run in this repo's
CI.
