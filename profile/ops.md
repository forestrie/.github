<!--toc:start-->
## Status

[forest-1]: https://github.com/forestrie/forest-1
[arbor]: https://github.com/forestrie/arbor
[arbor-flux]: https://github.com/forestrie/arbor-flux

* [![status][arbor-badge]][arbor-ci] - [arbor][arbor]
* [![status][canopy-badge]][canopy-ci] - [canopy][canopy]


|  | | |
|:------|:------|------:|
|[![status][forest-1-infra-badge]][forest-1-infra] | infrastructure | terraform and gitops infra defining and managing the [forest-1][forest-1] cluster |
|[![status][forest-1-flux-sync-badge]][forest-1-flux-sync] | cluster | cluster automation using flux for [forest-1][forest-1] and client project [arbor-flux][arbor-flux] |
|[![status][forest-1-arbor-flux-auth-badge]][forest-1-arbor-flux-auth] |  [forest-1][forest-1] gcp worload identity based github authorization for flux on arbor |  |




[forest-1-infra]: https://github.com/forestrie/forest-1/actions/workflows/infra.yaml
[forest-1-infra-badge]: https://github.com/forestrie/forest-1/actions/workflows/infra.yaml/badge.svg
[forest-1-flux-sync]: https://github.com/forestrie/forest-1/actions/workflows/flux-sync.yaml
[forest-1-flux-sync-badge]: https://github.com/forestrie/forest-1/actions/workflows/flux-sync.yaml/badge.svg
[forest-1-arbor-flux-auth]: https://github.com/forestrie/forest-1/actions/workflows/setup-arbor-flux-auth.yaml
[forest-1-arbor-flux-auth-badge]: https://github.com/forestrie/forest-1/actions/workflows/setup-arbor-flux-auth.yaml/badge.svg


[arbor-ci]: https://github.com/forestrie/arbor/actions/workflows/build-deploy.yml
[arbor-badge]: https://github.com/forestrie/arbor/actions/workflows/build-deploy.yml/badge.svg


[canopy]: https://github.com/forestrie/canopy
[canopy-ci]: https://github.com/forestrie/canopy/actions/workflows/test.yml
[canopy-badge]: https://github.com/forestrie/canopy/actions/workflows/test.yml/badge.svg
