# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

This is an **Octez package builder** — it automates building `.deb` and `.rpm` packages for [Octez](https://gitlab.com/tezos/tezos) (the Tezos node and related binaries) across multiple Linux platforms. The actual Octez source is checked out on remote VMs at build time; this repo only contains the packaging infrastructure.

Packages produced: `node`, `baker`, `client`, `dal-node`, `signer`, `smart-rollup`, `evm-node`, `teztale-archiver`, `zcash-params`.

## Prerequisites

- `gcloud` CLI authenticated and configured
- GCS bucket and GCP project set in `environment` file (see below)
- For local package builds: `dpkg-deb` (Debian) or `rpmbuild` (RPM)

## Configuration

Copy and edit `environment` before running anything:
```
PROJECT=<gcp-project-id>
SERVICEACCT=<service-account-email>
BUCKET=gs://<bucket-name>
```

`platforms` — one target OS per line, controls which VMs are spun up. Current targets are in the file; defaults to `debian-13` if the file is absent.

`latest-releases.env` — pin `EVMBRANCH` and `SRNBRANCH` to specific git branches when they differ from the main Octez branch.

## Main commands

**Full build** (spawns GCP VMs, builds, copies packages to GCS, re-indexes):
```sh
sh build_pkg.sh <branch> [target-os] [revision]
# e.g.
sh build_pkg.sh octez-v21.0
sh build_pkg.sh latest-release           # uses latest-releases.env
sh build_pkg.sh master debian-13 2       # single target, rev 2
```

**Manual index update** (after packages are already in GCS):
```sh
sh helpers/sync_pkg.sh down   # pull current state from GCS bucket
sh helpers/index.sh           # rebuild HTML index files
sh helpers/sync_pkg.sh up     # push back to GCS
```

**Local Debian package build** (must run inside the Octez source tree after `make`):
```sh
OCTEZ_PKGNAME=octez OCTEZ_PKGREV=1 sh ~/pkgscripts/dpkg/make_dpkg.sh "node baker client"
```

**Local RPM package build** (same prerequisite):
```sh
OCTEZ_PKGNAME=octez OCTEZ_PKGREV=1 sh ~/pkgscripts/rpm/make_rpm.sh "node baker client"
```

## Architecture

### Build flow

1. `build_pkg.sh` reads `platforms` and spins up one GCP VM per target OS using `gcloud compute instances create`.
2. It copies `helpers/_buildscript.sh` and `pkgscripts/` to each VM, then launches `_buildscript.sh` in the background.
3. `_buildscript.sh` runs on the VM: installs system deps, installs OPAM + Rust, clones `https://gitlab.com/tezos/tezos.git`, runs `make build-deps && make BLST_PORTABLE=yes`, then invokes the appropriate packaging script.
4. The orchestrator polls `/tmp/status` on each VM every 3 minutes until all report `FINISHED` or `FAILED:*`.
5. Finished packages are `gcloud storage cp`-ed to `${BUCKET}/<os>/` (or `.../testing/<os>/` when `DEVELOPER=1`).
6. After all VMs finish, the orchestrator syncs the bucket locally, rebuilds HTML indices, and syncs back.

### Package definition pattern

Each package is declared by a set of files in `pkgscripts/`:

| File | Purpose |
|------|---------|
| `dpkg/<name>-control.in` | Debian control file template — tokens: `@PKG@`, `@VERSION@`, `@ARCH@`, `@MAINT@`, `@DEPENDS@`, `@DPKG@` |
| `rpm/<name>-spec.in` | RPM spec template — same tokens plus `@REVISION@`, `@FAKESRC@` |
| `pkg-common/<name>-binaries` | Newline-separated list of binary paths to install to `/usr/bin/` |
| `pkg-common/<name>.service` | systemd unit file — copied to `/lib/systemd/system/octez-<name>.service` |
| `pkg-common/<name>.default` | `/etc/defaults/octez-<name>` environment file for the service |
| `pkg-common/<name>.conf` | Optional example config file |
| `pkg-common/<name>.initd` | Optional SysV init script (for distros without systemd) |
| `pkg-common/<name>.vmeth` | Shell script to determine package version (used when it differs from the main Octez version — currently only `evm-node`) |
| `dpkg/<name>.postinst` etc. | dpkg maintainer scripts |

To add a new package, create `dpkg/<name>-control.in` (and/or `rpm/<name>-spec.in`) plus `pkg-common/<name>-binaries`. The build scripts auto-discover packages by globbing for `*-control.in` / `*-spec.in`.

### VM detection (Debian vs RPM)

`_buildscript.sh` and both packaging scripts detect the OS at runtime: if `apt` is in PATH → Debian path (`make_dpkg.sh`), otherwise → RPM path (`make_rpm.sh`). The `DEBIAN` variable controls this.

### GCS bucket layout

```
gs://<bucket>/
  <os>/            # e.g. debian-13/, ubuntu-2404-lts-amd64/
    *.deb / *.rpm
    index.html
    dev/
      *.deb / *.rpm
      index.html
  testing/         # DEVELOPER=1 builds land here
    <os>/...
```

`Sources/pkgbeta-tzinit-org/` is the local mirror used by `sync_pkg.sh` and `index.sh`. The `mks3idx` helper generates a minimal HTML directory listing at each level.

### Version numbering

- Release branches (`octez-v*`): version taken from `dune exec octez-version` in the Octez tree, tilde-cleaned for dpkg/RPM compatibility.
- Dev/non-release branches: version is `99<short-sha>` to sort after all real releases.
- EVM node: version comes from `octez-evm-node --version` (via `evmnode.vmeth`).
- `OCTEZ_PKGREV` is the package revision (appended after the version).

### Important env vars

| Variable | Default | Meaning |
|----------|---------|---------|
| `BLST_PORTABLE` | unset | Must be `yes` for portable binaries; build warns if absent |
| `OCTEZ_PKGNAME` | `octez` | Prefix for all package names |
| `OCTEZ_PKGMAINTAINER` | `chris@chrispinnock.com` | Maintainer field in packages |
| `OCTEZ_PKGREV` | `1` | Package revision number |
| `EVMBRANCH` / `SRNBRANCH` | `$BRANCH` | Override branches for EVM node / smart-rollup node |
| `DEVELOPER` | `1` (in scripts) | Routes builds to `testing/` in GCS and skips VM deletion |
