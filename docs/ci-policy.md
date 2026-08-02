# Forestrie CI policy

Binding for every repository in this organisation. Three sections, each written
because something went wrong in the way it describes.

Sources: plans [2608-04](https://github.com/forestrie/devdocs/blob/main/plans/plan-2608-04-secret-egress-audit-and-lint.md)
(secret egress) and [2608-05](https://github.com/forestrie/devdocs/blob/main/plans/plan-2608-05-kit-publish-discipline.md)
(publish discipline), consolidated by
[2608-06](https://github.com/forestrie/devdocs/blob/main/plans/plan-2608-06-qualification-promotion-remediation/README.md).

---

## 1. Secrets never cross a job boundary

**Rule.** Secret-derived data must not appear in job outputs, workflow outputs,
logs, or artifacts. A consumer that needs a secret reads the env-scoped secret
**at its own point of use**.

There is no sanctioned exception path. A genuine future need restructures its
jobs.

### Why this one is a rule and not a guideline

**GitHub silently drops job outputs containing secret values.** It writes
`Skip output '…' since it may contain secret` into a job log nobody reads, sets
the output to the empty string, and fails nothing at all.

That is a failure mode with no authoring-time signal and no runtime signal. In
canopy, the T3 tier passed the ES256 bootstrap PEM through a job output; the
path was dead from the day the tier was built and stayed invisible until a
chain-anchor gate made key identity matter. It then presented as an
inexplicable empty value several jobs downstream and cost a full debugging cycle
(canopy#211). The same latent hazard existed for the KS256 key, fixed in the
same PR.

### The pattern

```yaml
# WRONG — the output is dropped, `tests` reads ""
jobs:
  resolve:
    env: { PEM: "${{ secrets.BOOTSTRAP_PEM }}" }
    outputs: { pem: "${{ steps.r.outputs.pem }}" }

# RIGHT — the consumer reads the env-scoped secret itself
jobs:
  tests:
    environment: dev
    steps:
      - env: { PEM: "${{ secrets.BOOTSTRAP_PEM }}" }
```

Non-secret metadata (a tag name, an address, a version) crosses freely. It is
*secret-derived* data that is prohibited.

### Log echo

GitHub's log masking covers **exact secret strings only**. A base64 of a secret,
a prefix, a hash, or any other transformation prints in clear — in logs, in
step summaries, and in uploaded artifacts. Do not emit them.

This half is policy-enforced only. `secret-egress-lint` v1 targets the outputs
class; a detector for transformations can follow if the class recurs.

### Enforcement

[`secret-egress-lint`](../actions/secret-egress-lint) runs beside `actionlint`
in each repository's workflow-lint job:

```yaml
- uses: forestrie/.github/actions/secret-egress-lint@main
```

A job that touches `secrets.*` and maps step outputs is flagged. The scanner
cannot tell a token used to *call* an API from a token about to be written into
an output, so a triaged-benign job is annotated in place, with its reasoning:

```yaml
jobs:
  # secret-egress-ok: GH_TOKEN authenticates the lookup; the output is the tag name it returned
  release-meta:
```

Waived findings are still printed with their reason. The exception trail is
meant to be readable.

---

## 2. Publish discipline

**A version bump is publishing intent.** A merge that changes a published
package's `package.json` version pushes `<pkg>-v<version>`, and the existing
tag-triggered publish workflow fires unchanged. No marker, no second decision
point.

**Service repositories auto-tag on merge.** canopy, mandate, arbor and
univocity-tools cut the next patch release tag on every merge to main,
suppressed by `[no-release]` in the merge commit. Tags are cheap *candidates*;
qualification is the quality gate. Nothing can silently run ahead of its
published tags again.

Both shapes are [`auto-tag`](../actions/auto-tag).

**npm versions are immutable.** Supersede, never re-tag. A bad publish is fixed
by publishing the next version.

**Publishing cadence rises under this policy, deliberately.** That is the
accepted cost of never repeating `canopy-e2e-kit` at npm 0.6.1 while the repo
was at 0.9.1 — three unpublished versions spanning exactly the window in which
the platform contract changed, so every consumer of the published kit, the T3
qualification harness included, silently exercised the old contract.

### ⚠️ Tags created by `GITHUB_TOKEN` trigger nothing

A ref created with the default `GITHUB_TOKEN` produces **no workflow run**. The
tag appears, looks entirely normal, and nothing publishes — with no error
anywhere. Auto-tagging must use a **GitHub App installation token or a PAT**.

Nothing at runtime distinguishes them, so the assertions that catch the silence
are named rather than assumed:

- the live rehearsal each repository performs when it adopts `auto-tag` (merge a
  bump → tag → publish run → npm latest moves, with no human step);
- the frontier resolver's hard fail on a `components.jsonc` pin that does not
  resolve on npm, which names the package, the declared version and npm's actual
  latest at the next qualification cycle.

### Provenance identities stay per-repo

Each repository keeps its own `EXPECTED_IDENTITIES` copy in
`verify-forestrie-provenance.mjs`. That duplication is deliberate supply-chain
posture: a shared registry would be a single point of compromise.

The cost is a manual step, so it is written down rather than remembered. **When
a published package gains a new `@forestrie` dependency, register the publisher
identity in every named consumer.** This bit twice in 48 hours — once in a
mandate slice, once stopping the first release-T3 (system-testing#76).

| Package                     | Consumers that must register the identity     |
| --------------------------- | --------------------------------------------- |
| `canopy-e2e-kit`            | system-testing                                 |
| mandate kits                | mandate, system-testing                        |
| `deploy-core`               | mandate, system-testing (via mandate-ui-e2e-kit) |

---

## 3. Scheduled health workflows report their verdict

Any workflow whose job is to detect breakage must say so somewhere a human
looks. `qualify-dev` was red for six days and the canopy metering canary for
three, in the same week, and both were found by accident.

Every scheduled health workflow ends with
[`linear-health-alert`](../actions/linear-health-alert):

```yaml
- name: Report health
  if: always()
  uses: forestrie/.github/actions/linear-health-alert@main
  with:
    alert_key: metering-canary
    state: ${{ job.status == 'success' && 'green' || 'failing' }}
    title: "Metering canary is red"
    linear_api_key: ${{ secrets.LINEAR_API_KEY }}
```

One issue per `alert_key`, edited rather than duplicated while the failure
persists, closed automatically when it recovers.

`LINEAR_API_KEY` is an organisation Actions secret, scoped to the repositories
that adopt the action — **but only public repositories can read it.**

On GitHub's **free** plan, organisation secrets are available to public
repositories only. The API does not say so: `PUT
/orgs/{org}/actions/secrets/{name}/repositories/{id}` succeeds for a private
repo and lists it afterwards, so the scoping looks correct while
`secrets.LINEAR_API_KEY` resolves to an empty string in every run. The
adopting workflow then fails on the missing credential, which is the right
behaviour and the wrong diagnosis.

**A private repo needs a repo-level secret:**

```sh
gh secret set LINEAR_API_KEY --repo forestrie/<repo> --body "$LINEAR_API_KEY"
```

This cost two failed release-orchestrator runs on 2026-08-02 before the plan
was identified, and it was invisible until then because every repo the action
had been proven on — canopy, univocity-tools — is public. Check the
repository's visibility before assuming the grant is the problem.

**Known gap:** issue-lifecycle alerting cannot see absence. A workflow that
stops running entirely raises nothing. The public status badges in this
repository cover part of that class by going red on silence; a general heartbeat
watcher is a candidate follow-on.

---

## 4. The standing rule underneath all three

**A soft path must name the assertion that catches its silence.**

Four separate silent degradations in a single session shipped two green releases
carrying a wrong pin: a missing credential that fell back instead of failing, a
`catch` that swallowed a `ReferenceError`, an unasserted edit that no-opped, and
GitHub dropping a job output without saying so.

In release and qualification machinery the asymmetry is stark. A run that fails
is cheap — the loop retries. A run that goes **green while carrying the wrong
artefact** is expensive, because a human may promote it.

So:

- a missing **credential** is misconfiguration, not weather: exit non-zero;
- `continue-on-error`, `|| true` and early `exit 0` must name the downstream
  assertion or liveness signal that catches their silence;
- staleness and quarantine are **declared** with a reason, never inferred;
- anchor pass/fail greps — a bare `grep "Tests "` matches `Failed Tests 4`;
- after a change meant to alter deployed behaviour, verify the **effect** (a log
  line, an artefact's content), not the run's colour.
