# Forestrie is a trust‑minimized digital provenance ledger

<!--toc:start-->
- [Forestrie is a trust‑minimized digital provenance ledger](#forestrie-is-a-trustminimized-digital-provenance-ledger)
  - [Status](#status)
<!--toc:end-->

The software was originally created by DataTrails, Inc. as the underlay for their digital provenance platform and released under an MIT license to promote system transparency.

DataTrails was acquired by [OnID](https://onid.co/) in 2025, who continue to operate the platform.

The original software continues to be available and maintained at: <https://github.com/datatrails/>

This project (Forestrie) is an independent effort to continue the evolution of standards‑based, interoperable, and highly scalable provenance ledgers.

Per the [roadmap](./roadmap.md)

## Status

* [![unit tests](https://github.com/forestrie/merklelog-ci/actions/workflows/go-test.yml/badge.svg)](https://github.com/forestrie/merklelog-ci/actions/workflows/go-test.yml)
* [![unit tests][veracity-ci-badge]][veracity-ci]



| Repository                |  | | |
|:--------------------------|:------|:------|------:|
| [veracity][veracity] |[![status][veracity-ci-badge]][veracity-ci] |  ledger cli| forked and maintained |
| [go-merklelog][go-merklelog] | | core ledger format | forked and maintained |
| [go-merklelog-azure][go-merklelog-azure] | | azure blob storage provider | maintained |
| [go-merklelog-fs][go-merklelog-fs] | | file system storage provider, pitched at replication and local receipts | maintained |
| [go-merklelog-provider-testing][go-merklelog-provider-testing]|  | common go lang test facilities for merklelog storage providers | maintained |
| [go-datatrails-common][go-datatrails-common]       | | datatrails legacy | working to remove |
| [go-datatrails-simplehash][go-datatrails-simplehash] | | a datatrails specific pre-image scheme | working to remove |
| [go-datatrails-serialization][go-datatrails-serialization] | | datatrails specific serialization and pre-image support | working to remove |

[veracity]: https://github.com/forestrie/veracity
[go-merklelog]: https://github.com/forestrie/go-merklelog
[go-merklelog-azure]: https://github.com/forestrie/go-merklelog-azure
[go-merklelog-fs]: https://github.com/forestrie/go-merklelog-fs
[go-merklelog-provider-testing]: https://github.com/forestrie/go-merklelog-provider-testing
[go-datatrails-common]: https://github.com/robinbryce/go-datatrails-common
[go-datatrails-simplehash]: https://github.com/datatrails/go-datatrails-simplehash
[go-datatrails-serialization]: https://github.com/datatrails/go-datatrails-serialization
[veracity-ci-badge]: https://github.com/forestrie/veracity/actions/workflows/ci.yml/badge.svg
[veracity-ci]: https://github.com/forestrie/veracity/actions/workflows/ci.yml
