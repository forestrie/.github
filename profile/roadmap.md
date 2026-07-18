# Roadmap

## Project vision

1. Be an independent, production‑grade, interoperable transparency ledger.
2. Maintain compatibility with the evolving IETF drafts:
   - `draft-bryce-cose-receipts-mmr-profile-00`
   - `draft-ietf-cose-merkle-tree-proofs-16`
3. Maintain **veracity** as a vendor‑neutral tool for working with Forestrie logs.

## Current focus

- **IETF SCITT adoption** — demo and tooling supporting the adoption call for the MMR profile draft ([ietf-126-demo](https://github.com/forestrie/ietf-126-demo)).
- **A reliable production platform** — hardening [canopy](https://github.com/forestrie/canopy) and [arbor](https://github.com/forestrie/arbor) into production‑quality ingestion, sequencer, and attestor services on cloud‑vendor‑neutral object storage.
- **Split‑view protection, on chain** — [univocity](https://github.com/forestrie/univocity): an EVM smart contract as the single source of truth for the verified history of log checkpoints, proven out on a public network.
- **Self‑custodied sealing** — [mandate](https://github.com/forestrie/mandate): bring‑your‑own‑key instances with delegated and self‑hosted sealers, so receipts can be signed by keys the log owner controls.
- **Permissionless network economics** — early designs for attestor accountability, staking, and checkpoint fees.

## Ledger format and standards

The Forestrie ledger uses binary‑encoded Merkle Mountain Ranges (MMRs), organized as a linear set of "tiles" — proofs stay local to a single storage object. Receipts and checkpoints are COSE/CBOR, per the IETF drafts:

- MMR profile: <https://www.ietf.org/archive/id/draft-bryce-cose-receipts-mmr-profile-00.html>
- COSE Merkle tree proofs (the registry it profiles): <https://www.ietf.org/archive/id/draft-ietf-cose-merkle-tree-proofs-16.html>
- SCITT reference architecture (which references both): <https://www.ietf.org/archive/id/draft-ietf-scitt-architecture-20.html>

Format documentation:

- Navigating the format: <https://docs.datatrails.ai/developers/developer-patterns/navigating-merklelogs/>
- Peak stack / offset tables: <https://docs.datatrails.ai/developers/developer-patterns/massif-blob-offset-tables/>

## Further reading

- Relation to Certificate Transparency and Sunlight tiles: <https://github.com/robinbryce/mmriver-supplimental/blob/main/if-you-go-down-to-the-woods-today.md>
- 1‑D↔2‑D Merkle tree equivalences: <https://github.com/robinbryce/draft-bryce-cose-merkle-mountain-range-proofs/blob/main/1d-2d-tree-equivalences.md>
- Python reference algorithms: <https://github.com/robinbryce/draft-bryce-cose-merkle-mountain-range-proofs/blob/main/algorithms.py>
- TypeScript minimal implementation: <https://github.com/robinbryce/mmriver-tiles-ts/blob/main/README.md>

## Tags and branches

The authoritative list of repositories and active branches for this project (tags are `@ref`s, branches are `^ref`s):
<https://github.com/forestrie/merklelog-ci/blob/main/veracity/.env.bootstrap>
