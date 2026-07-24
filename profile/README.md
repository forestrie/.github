Forestrie is a trust‑minimized digital provenance ledger

The software was originally created by DataTrails, Inc. as the underlay for their digital provenance platform and released under an MIT license to promote system transparency.

DataTrails was acquired by [OnID](https://onid.co/) in 2025, who continue to operate the platform.

The original software continues to be available and maintained at: <https://github.com/datatrails/>

This project (Forestrie) is an independent effort to continue the evolution of standards‑based, interoperable, and highly scalable provenance ledgers.

See the [architecture](./architecture.md) for how the core elements fit together, and the [roadmap](./roadmap.md) for where it is going.

## Status: Forestrie

| Forestrie | latest (from the last qualified Lane A T3) |
|:----------|:-------------------------------------------|
| endpoints (liveness) | [![status][forestrie-status-badge]][forestrie-status] |
| Lane A qualification (dev T3) | [![status][qualify-dev-badge]][qualify-dev] |
| Lane B qualification (stage T3) | [![status][qualify-stage-badge]][qualify-stage] |
| univocity deploy | [v0.1.8][univocity-deploy] |
| lane A manifest | [release-manifest][lane-a-manifest] |
| lane B manifest | [lane-b.jsonc][lane-b-manifest] |

The **endpoints (liveness)** badge is a reachability probe, not a test gate. It
is green when the public per-lane SCRAPI endpoints (scitt-configuration,
register-grant, onboard — lanes a &amp; b) are available and the forest-2
external-dns / cert-manager machinery is healthy. It does **not** run the
system (T3) tests, so it cannot go red on a test regression — a green liveness
badge is not a statement that the platform is qualifying.

The **qualification** badges track the end-to-end system (T3) suites that gate
promotion, each reproducing the wire manifest (CLI/service pins per ADR-0054)
from the latest qualified release-manifest and running orchestrator-system-e2e:
Lane A via release-orchestrator qualify-dev, Lane B via qualify-stage. A red
qualification badge means the lane is failing its T3 gate even while its
endpoints stay live.

All three badges check the lane's full declared spec inventory
(release-orchestrator `config/t3-inventory.json`) rather than just the GitHub
Actions conclusion: a spec that silently `test.skip`s — because a secret is
unset or an env gate is unwired — fails the lane instead of passing it.

**Silence is red, not green.** The three source workflows live in private
repositories (`forest-1`, `release-orchestrator`), whose `badge.svg` GitHub
serves only to viewers who can see the repo — anonymous visitors got a broken
image. Each badge above is therefore a public mirror in this repository:
the private workflow reports its verdict by `repository_dispatch`, and the
mirror also ticks on a schedule and **fails when no verdict has arrived within
the source's expected interval**. So a badge that stops being updated goes red
rather than holding its last colour, and a lane that has never reported is red
rather than grey. Grey previously hid a Lane B whose T3 suite was failing.

| Repository                |  | | |
|:--------------------------|:------|:------|------:|
| [canopy][canopy] |[![status][canopy-ci-badge]][canopy-ci] | ingestion with a SCITT/SCRAPI personality | active development |
| [arbor][arbor] |[![status][arbor-ci-badge]][arbor-ci] | core platform services | active development |
| [univocity][univocity] |[![status][univocity-ci-badge]][univocity-ci] | split-view protection via on-chain checkpoint verification | active development |
| [mandate][mandate] |[![status][mandate-ci-badge]][mandate-ci] | BYOK instance management: operator console, delegation, provisioning | active development |
| [forestrie-cli][forestrie-cli] |[![status][forestrie-cli-ci-badge]][forestrie-cli-ci] | single-binary participant CLI | active development |

## Status: Ledger tooling & packages

| Repository                |  | | |
|:--------------------------|:------|:------|------:|
| [veracity][veracity] |[![status][veracity-ci-badge]][veracity-ci] |  ledger cli| forked and maintained |
| [go-merklelog][go-merklelog] |[![status][go-merklelog-ci-badge]][go-merklelog-ci] | core ledger format | forked and maintained |
| [go-merklelog-azure][go-merklelog-azure] |[![status][go-merklelog-azure-ci-badge]][go-merklelog-azure-ci] | azure blob storage provider | maintained |
| [go-merklelog-fs][go-merklelog-fs] |[![status][go-merklelog-fs-ci-badge]][go-merklelog-fs-ci] | file system storage provider, pitched at replication and local receipts | maintained |


See also:
- [ietf-126-demo][ietf-126-demo] — live forestrie walkthrough for the IETF SCITT WG
- [ops](./ops.md)
- [extras](./extras.md)

[forestrie-status]: https://github.com/forestrie/.github/actions/workflows/status-endpoints.yml
[forestrie-status-badge]: https://github.com/forestrie/.github/actions/workflows/status-endpoints.yml/badge.svg
[qualify-dev]: https://github.com/forestrie/.github/actions/workflows/status-lane-a.yml
[qualify-dev-badge]: https://github.com/forestrie/.github/actions/workflows/status-lane-a.yml/badge.svg
[qualify-stage]: https://github.com/forestrie/.github/actions/workflows/status-lane-b.yml
[qualify-stage-badge]: https://github.com/forestrie/.github/actions/workflows/status-lane-b.yml/badge.svg
[univocity-deploy]: https://github.com/forestrie/univocity/releases/tag/v0.1.8
[lane-a-manifest]: https://github.com/forestrie/release-orchestrator/blob/main/manifests/releases/29648215010/release-manifest.jsonc
[lane-b-manifest]: https://github.com/forestrie/system-testing/blob/main/manifests/lane-b.jsonc

[canopy]: https://github.com/forestrie/canopy
[arbor]: https://github.com/forestrie/arbor
[univocity]: https://github.com/forestrie/univocity
[mandate]: https://github.com/forestrie/mandate
[forestrie-cli]: https://github.com/forestrie/forestrie-cli
[ietf-126-demo]: https://github.com/forestrie/ietf-126-demo
[canopy-ci-badge]: https://github.com/forestrie/canopy/actions/workflows/ci.yml/badge.svg
[canopy-ci]: https://github.com/forestrie/canopy/actions/workflows/ci.yml
[arbor-ci-badge]: https://github.com/forestrie/arbor/actions/workflows/go-test.yml/badge.svg
[arbor-ci]: https://github.com/forestrie/arbor/actions/workflows/go-test.yml
[univocity-ci-badge]: https://github.com/forestrie/univocity/actions/workflows/ci.yml/badge.svg
[univocity-ci]: https://github.com/forestrie/univocity/actions/workflows/ci.yml
[mandate-ci-badge]: https://github.com/forestrie/mandate/actions/workflows/test.yml/badge.svg
[mandate-ci]: https://github.com/forestrie/mandate/actions/workflows/test.yml
[forestrie-cli-ci-badge]: https://github.com/forestrie/forestrie-cli/actions/workflows/ci.yml/badge.svg
[forestrie-cli-ci]: https://github.com/forestrie/forestrie-cli/actions/workflows/ci.yml
[veracity]: https://github.com/forestrie/veracity
[go-merklelog]: https://github.com/forestrie/go-merklelog
[go-merklelog-azure]: https://github.com/forestrie/go-merklelog-azure
[go-merklelog-fs]: https://github.com/forestrie/go-merklelog-fs
[veracity-ci-badge]: https://github.com/forestrie/veracity/actions/workflows/ci.yml/badge.svg
[veracity-ci]: https://github.com/forestrie/veracity/actions/workflows/ci.yml
[go-merklelog-ci-badge]: https://github.com/forestrie/go-merklelog/actions/workflows/ci.yml/badge.svg
[go-merklelog-ci]: https://github.com/forestrie/go-merklelog/actions/workflows/ci.yml
[go-merklelog-fs-ci-badge]: https://github.com/forestrie/go-merklelog-fs/actions/workflows/ci.yml/badge.svg
[go-merklelog-fs-ci]: https://github.com/forestrie/go-merklelog-fs/actions/workflows/ci.yml
[go-merklelog-azure-ci-badge]: https://github.com/forestrie/go-merklelog-azure/actions/workflows/ci.yml/badge.svg
[go-merklelog-azure-ci]: https://github.com/forestrie/go-merklelog-azure/actions/workflows/ci.yml

