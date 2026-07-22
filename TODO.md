# Release 1

## Tezos Foundation

- [x] Migrate snapshot service to new packages
- [ ] Migrate boot nodes to new packages
- [ ] Migrate archive and cutter nodes to new packages
- [ ] Adjust and simplify upgrade pipelines to use APT

## Signer

- [X] Resurrect package
- [X] Check systemd scripts
- [ ] Write Hermes deployment tests

## APT Repos

- [X] Check upgrades are working (e.g. with 25.1)
- [ ] Get others to sign the tzinit package key

## Nomadic Labs/Unoff -> Tzinit migration

- [ ] Set up a machine with NL and move it to tzinit packages
- [ ] Set up a machine with Unoff packages and move it to tzinit packages

# Future

## Log Rotation

- [ ] Each package should have a default log.rotate.d script
  - [ ] octez-signer
  - [ ] octez-node
  - [ ] octez-dal-node
  - [ ] octez-baker
  - [ ] octez-accuser
  - [ ] octez-smart-rollup-node
  - [ ] octez-evm-node
  - [ ] octez-teztale-archiver

## APT Repos

- [ ] Handle revision upgrades
- [ ] Handle multiple debian repositories - should we have one per codename? What is the best practice? deb13, .

## RPM Repos

- [ ] Set up a Rocky repository
- [ ] Look at other RPM Linux distributions
- [X] Fix Rocky Linux 10 builds
- [X] What about arm64?
- [X] Need Hermes tests

## Signer

- [ ] Is there a better way to handle magic bytes and command line arguments to the signer?

## Client

- [ ] Include bash completion script? ./src/bin_client/bash-completion.sh

## EVM node

- [ ] Write a Hermes deployment test and fix bugs

## Teztale

- [ ] Migrate TF to new Teztale packages
- [ ] File a keepalive PR for octez-teztale-archiver

## Versioning

- [ ] Will NL continue to release EVM, Smart Rollup separately from the main stream binaries?
