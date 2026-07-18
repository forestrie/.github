Forestrie is a trust‑minimized digital provenance ledger

The software was originally created by DataTrails, Inc. as the underlay for their digital provenance platform and released under an MIT license to promote system transparency.

DataTrails was acquired by [OnID](https://onid.co/) in 2025, who continue to operate the platform.

The original software continues to be available and maintained at: <https://github.com/datatrails/>

This project (Forestrie) is an independent effort to continue the evolution of standards‑based, interoperable, and highly scalable provenance ledgers.

See the [architecture](./architecture.md) for how the core elements fit together, and the [roadmap](./roadmap.md) for where it is going.

## Status: Forestrie platform

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

