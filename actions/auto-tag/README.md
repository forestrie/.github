# `auto-tag`

Pushes the release tags a merge implies, so no human has to remember to.

Plans [2608-01 Q4](https://github.com/forestrie/devdocs/blob/main/plans/plan-2608-01-continuous-dev-qualification.md)
and [2608-05 Q1](https://github.com/forestrie/devdocs/blob/main/plans/plan-2608-05-kit-publish-discipline.md)
· FOR-517 / FOR-520.

## Why

`@forestrie/canopy-e2e-kit` sat at npm 0.6.1 while the repo reached 0.9.1 —
three unpublished versions spanning exactly the window in which the platform
contract changed (mandatory mint bindings, chain-anchored genesis). Every
consumer of the *published* kit, the T3 qualification harness included, silently
exercised the old contract.

The publish workflows were never the problem. They are tag-triggered and they
work; the tag was the step a human had to remember. In one 24-hour period five
tags were pushed by hand, remembered only because the sessions doing the bumps
happened to be paying attention. That is not a mechanism.

## ⚠️ The token is load-bearing

**A ref created with the default `GITHUB_TOKEN` triggers no workflow runs.** The
tag appears, looks completely normal, and nothing publishes. There is no error
and no warning anywhere.

So `token` is required with no default, and must be a **GitHub App installation
token or a PAT**. The estate already mints App tokens for exactly this class of
work (`GITAPP_PRIVATE_KEY`).

Nothing at runtime can tell the two apart, so the assertions that catch the
silence are named rather than implied:

- the **live rehearsal** each repo does when it adopts this action (plan 2608-06
  Phase 2: merge a bump, watch the tag, watch the publish run, watch npm move);
- the frontier resolver's **hard fail on an unresolvable pin** — a
  `components.jsonc` version that never reached npm fails the next
  qualification cycle by name (plan 2608-05 Q3).

## `mode: service`

Cuts the next patch tag on the merge commit.

```yaml
on:
  push:
    branches: [main]

permissions:
  contents: write

jobs:
  tag:
    runs-on: ubuntu-latest
    steps:
      - uses: forestrie/.github/actions/auto-tag@main
        with:
          mode: service
          token: ${{ steps.app-token.outputs.token }}
```

Highest existing `vX.Y.Z` + 1 patch. No tags yet → `v0.0.1`. Prereleases and
other tag families are ignored: bumping off `v1.0.0-rc.1` would produce nonsense.

Skipped when the merge commit message contains `[no-release]`, or when the
commit already carries a release tag.

Tags are cheap **candidates** — qualification is the quality gate. The point is
that nothing can silently run ahead of its published tags again.

## `mode: packages`

Tags every declared package at its current `package.json` version. **A version
bump is publishing intent** — no marker, no second decision point.

`.github/auto-tag-packages.json`:

```json
{
  "packages": [
    { "dir": "packages/canopy-e2e-kit", "tag_prefix": "canopy-e2e-kit" },
    { "dir": "packages/encoding", "tag_prefix": "encoding" }
  ]
}
```

```yaml
- uses: forestrie/.github/actions/auto-tag@main
  with:
    mode: packages
    token: ${{ steps.app-token.outputs.token }}
```

`tag_prefix` must match what the existing `publish-*.yml` workflow already
triggers on — the mapping exists in those files today; this config just names it
in one place.

Both modes are idempotent: an existing tag is a skip, never an error, so
re-running a merge does nothing. A declared package whose directory or `version`
is missing is a **hard failure** — config rot here means silently unpublished
releases, which is the thing being fixed.
