# `linear-health-alert`

Turns a scheduled workflow's verdict into a Linear issue that raises itself,
updates itself, and closes itself.

Plan [2608-02](https://github.com/forestrie/devdocs/blob/main/plans/plan-2608-02-qualification-red-alerting.md)
· FOR-517.

## Why an issue, not an email

`qualify-dev` was red for six days and the canopy metering canary for three, in
the same week, and both were found by accident. GitHub's own scheduled-failure
email goes to whoever last committed the workflow file and fires once per run —
under an hourly retry policy that is spam, not a signal. A Linear issue puts the
alert where the remediation work already lives, and the natural unit of an alert
is the failing *thing*, not the run.

## Usage

```yaml
- name: Report health
  if: always()
  uses: forestrie/.github/actions/linear-health-alert@main
  with:
    alert_key: metering-canary
    state: ${{ job.status == 'success' && 'green' || 'failing' }}
    title: "Metering canary is red"
    body_md: |
      The nightly metering canary failed on lane A.
    labels: cicd
    linear_api_key: ${{ secrets.LINEAR_API_KEY }}
```

Put it last, guarded with `if: always()`, so it sees the job's real verdict.
`job.status` is `success`, `failure` or `cancelled` — the pattern above reports
a cancellation as failing, which is what you want for a health probe (a canary
that could not finish did not prove anything).

## Behaviour

| `state`   | Open issue for the key? | Effect                                                              |
| --------- | ----------------------- | ------------------------------------------------------------------- |
| `failing` | no                      | creates one, carrying `body_md`                                      |
| `failing` | yes, same content       | writes nothing (`action=unchanged`)                                  |
| `failing` | yes, changed content    | edits title/description; comments when `body_md` itself changed      |
| `green`   | yes                     | comments with the qualifying run, moves the issue to the Done state  |
| `green`   | no                      | no-op success                                                        |

The issue is found by a marker in its description
(`<!-- health-alert-key: … -->`), so it survives renames and stays one issue per
key. The run link lives in the description too, but is deliberately excluded
from the change hash: it moves every cycle and must not read as new information.
A changed `body_md` — a longer streak, a different suspect pin delta — does earn
a comment.

## It is loud on purpose

An alerter that silently no-ops is the disease this cures, so every one of these
fails the step, and therefore the health run:

- `linear_api_key` missing or rejected;
- Linear unreachable, or answering with a GraphQL `errors` array;
- `alert_key` that is not a slug (it is embedded in an HTML comment that doubles
  as the search filter);
- an unknown label name;
- **more than one** open issue carrying the key — the alerter will not guess;
- the key already owned by a **different** workflow.

That last one is the collision case. Two workflows sharing a key would fight
over one issue, each resolving the other's alert, and the result would look
healthy. Ownership (`repo` + workflow path) is recorded on the issue and a
mismatch stops the run: give the second workflow its own key.

## Setup

`LINEAR_API_KEY` is an organisation Actions secret scoped to the repositories
that adopt this action. It is a Linear personal API key and goes in the
`Authorization` header with no `Bearer` prefix.

The key is read from the step environment and never printed, never written to
`GITHUB_OUTPUT`, and never crosses a job boundary — see
[the CI policy](../../docs/ci-policy.md).

## Known limitation: the dead-man gap

Issue-lifecycle alerting cannot see absence. If a scheduled workflow stops
running entirely — disabled by GitHub after repository inactivity, or an Actions
outage — nothing fails, so nothing alerts. The public status badges
(`status-*.yml` in this repo) cover part of this class by going red on silence;
a general heartbeat watcher is a candidate follow-on, recorded in plan 2608-02
rather than solved here.
