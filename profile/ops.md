<!--toc:start-->
## Status

**Forestrie platform:** [![status][forestrie-status-badge]][forestrie-status]

Green when the public per-lane SCRAPI endpoints (scitt-configuration,
register-grant, onboard — lanes a &amp; b) are available **and** the forest-2 DNS
(external-dns) + cert-manager machinery is healthy.

[forest-1]: https://github.com/forestrie/forest-1
[arbor]: https://github.com/forestrie/arbor
[arbor-flux]: https://github.com/forestrie/arbor-flux


| Repository |  |  
|--|--|
| [forest-1][forest-1] |[![status][forest-1-infra-badge]][forest-1-infra] |
| [arbor][arbor]  | [![status][arbor-badge]][arbor-ci] |
| [canopy][canopy] | [![status][canopy-badge]][canopy-ci] |


| [forest-1][forest-1] | | |
|:------|:------|:------|
|[![status][forest-1-infra-badge]][forest-1-infra] | infrastructure | [forest-1][forest-1] terraform and gitops infra defining and managing the cluster |
|[![status][forest-1-flux-sync-badge]][forest-1-flux-sync] | cluster | [forest-1][forest-1] cluster kubernetes automation using flux for client projects: [arbor-flux][arbor-flux] |
|[![status][forest-1-bootstrap-badge]][forest-1-bootstrap] | bootstrap | [forest-1][forest-1] one-time platform bootstrap workflow |
|[![status][forestrie-status-badge]][forestrie-status] | platform | whole-platform health: per-lane SCRAPI endpoints + external-dns / cert-manager (FOR-403) |




[forest-1-infra]: https://github.com/forestrie/forest-1/actions/workflows/infra.yaml
[forest-1-infra-badge]: https://github.com/forestrie/forest-1/actions/workflows/infra.yaml/badge.svg
[forest-1-flux-sync]: https://github.com/forestrie/forest-1/actions/workflows/flux-sync.yaml
[forest-1-flux-sync-badge]: https://github.com/forestrie/forest-1/actions/workflows/flux-sync.yaml/badge.svg
[forest-1-bootstrap]: https://github.com/forestrie/forest-1/actions/workflows/bootstrap.yaml
[forest-1-bootstrap-badge]: https://github.com/forestrie/forest-1/actions/workflows/bootstrap.yaml/badge.svg
[forestrie-status]: https://github.com/forestrie/forest-1/actions/workflows/forestrie-status.yaml
[forestrie-status-badge]: https://github.com/forestrie/forest-1/actions/workflows/forestrie-status.yaml/badge.svg


[arbor-ci]: https://github.com/forestrie/arbor/actions/workflows/build-deploy.yml
[arbor-badge]: https://github.com/forestrie/arbor/actions/workflows/build-deploy.yml/badge.svg


[canopy]: https://github.com/forestrie/canopy
[canopy-ci]: https://github.com/forestrie/canopy/actions/workflows/test.yml
[canopy-badge]: https://github.com/forestrie/canopy/actions/workflows/test.yml/badge.svg
