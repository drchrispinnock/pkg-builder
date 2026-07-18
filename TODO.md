# Release 1

## Tezos Foundation

- [ ] Migrate snapshot service to new packages
- [ ] Migrate boot nodes to new packages
- [ ] Migrate archive nodes to new packages
- [ ] Adjust and simplify upgrade pipelines to use APT

## Signer

- [ ] Resurrect package
- [ ] Is there a better way to handle magic bytes and command line arguments to the signer?
- [ ] Check systemd scripts
- [ ] Write Hermes deployment tests

## APT Repos

- [ ] Handle revision upgrades
- [ ] Handle multiple debian repositories - should we have one per codename? What is the best practice?
- [ ] Check upgrades are working (e.g. with 25.1)
- [ ] Get others to sign the tzinit package key

## Nomadic Labs/Unoff -> Tzinit migration

- [ ] Set up a machine with NL and move it to tzinit packages
- [ ] Set up a machine with Unoff packages and move it to tzinit packages

# Release 2

## RPM Repos

- [ ] Set up a Rocky repository
- [ ] Look at other RPM Linux distributions
- [ ] Fix Rocky Linux 10 builds
- [ ] What about arm64?
- [ ] Need Hermes tests

## Client

- [ ] Include bash completion script?

## EVM node

- [ ] Write a Hermes deployment test and fix bugs

## Teztale

- [ ] Migrate TF to new Teztale packages
- [ ] File a keepalive PR for octez-teztale-archiver

## Versioning

- [ ] Will NL continue to release EVM, Smart Rollup separately from the main stream binaries?
- [ ]
