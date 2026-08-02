# .github

Organisation profile repository, and the single home for CI machinery shared
across forestrie repositories.

## Policy

[**docs/ci-policy.md**](./docs/ci-policy.md) — binding for every repository
here: secrets never cross a job boundary, a version bump is publishing intent,
scheduled health workflows report their verdict, and a soft path must name the
assertion that catches its silence.

## Reusable actions

| Action                                                       | What it does                                                                    |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| [`linear-health-alert`](./actions/linear-health-alert)       | one self-resolving Linear issue per `alert_key`, so a red canary is owned within one cycle |
| [`secret-egress-lint`](./actions/secret-egress-lint)         | fails a job that exports secret-derived data — the class GitHub drops silently   |
| [`auto-tag`](./actions/auto-tag)                             | pushes the release / package tags a merge implies                                |

```yaml
- uses: forestrie/.github/actions/<name>@main
```

Each action's README carries its own rationale, inputs and failure modes. They
are tested where they live — see [`.github/workflows/ci.yml`](./.github/workflows/ci.yml).

## Public status badges

`status-*.yml` plus [`scripts/status-mirror.sh`](./scripts/status-mirror.sh)
mirror private workflow verdicts into public badges that go **red on silence**,
so a source that stops reporting is never mistaken for a healthy one.

## Org profile

[`profile/`](./profile) renders on <https://github.com/forestrie>.
