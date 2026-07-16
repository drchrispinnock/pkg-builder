# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

This is an **Octez package builder** — it automates building `.deb` and `.rpm` packages for [Octez](https://gitlab.com/tezos/tezos) (the Tezos node and related binaries) across multiple Linux platforms, then publishes them to Google Cloud Storage as raw downloads, an APT repository, and a download website. The actual Octez source is cloned and built on throwaway GCP VMs at build time; this repo only contains the packaging infrastructure.

**Packages built by default:** `zcash-params`, `client`, `node`, `baker`, `dal-node`, `teztale-archiver`, `evm-node`, `smart-rollup-node`. Templates also exist for `signer` and `experimental`, but they are not in the default build list. The `baker` package additionally bundles the `octez-vdf` (and accuser) systemd units.

## Prerequisites

- `gcloud` CLI authenticated and configured (used to create VMs, resolve images, and sync buckets)
- `PROJECT`, `SERVICEACCT`, and `BUCKET` set in the `environment` file (see below)
- For building the APT repo locally: `reprepro`
- For the download website: `gpg` with a key for `packages@tezos.foundation` (packages are detached-signed)
- For local package builds only: `dpkg-deb` (Debian) or `rpmbuild` (RPM)

## Configuration

`environment` (git-ignored) is sourced by `build_pkg.sh`. Create it before running anything:
```
PROJECT=<gcp-project-id>
SERVICEACCT=<service-account-email>
BUCKET=gs://<bucket-name>          # e.g. gs://pkgbeta-tzinit-org
```
Optional overrides (VM sizing): `X86`, `X86ZONE`, `ARM64`, `ARMZONE`, `SIZE`. Defaults are `e2-standard-8`/`europe-west6-a` for x86, `c4a-standard-8`/`europe-west6-b` for arm64, 200 GB disk.

`platforms` — one target OS family per line; controls which VMs are spun up. Defaults to `debian-13` if the file is absent. Current entries: `debian-13`, `debian-13-arm64`, `ubuntu-2404-lts-amd64`, `ubuntu-2404-lts-arm64`. Any name containing `arm64` is built on an ARM VM. The name is resolved to a GCP image by `helpers/parse_images.pl` via `gcloud compute images list`.

`latest-releases.env` — pins `EVMBRANCH` and `SRNBRANCH` for release builds (the EVM node and smart-rollup node are versioned independently of the main Octez release). Only sourced when `BRANCH` is a release/`latest-release` build **and** neither branch was passed on the command line.

## Main commands

All options are **flags** — `build_pkg.sh` does not take positional arguments (a bare word is silently ignored). If no `--branch` is given it defaults to `latest-release`.

**Full build** (creates GCP VMs, builds on each, uploads packages to GCS, optionally rebuilds the APT repo and website):
```sh
sh build_pkg.sh                                    # latest-release, all platforms in `platforms`
sh build_pkg.sh --branch octez-v21.0
sh build_pkg.sh --branch master --targets debian-13 --revision 2
sh build_pkg.sh --branch octez-v22.0-rc1 --buildapt --buildsite
sh build_pkg.sh --branch master --devmode          # route to testing/, keep VMs alive
```
Key flags: `--branch/-B`, `--targets/-T "<os> <os>"`, `--revision/-R`, `--evm-branch`, `--srn-branch`, `--pkgname`, `--override-version/-O`, `--devmode/-D`, `--blst-portable`, `--(no-)sync`, `--buildapt`, `--buildsite`, `--sleep <seconds>`, plus `--project/-P`, `--service-account/-S`, `--bucket/-b` to override the `environment` values.

**Rebuild the APT repository** (from packages already synced under `./incoming`, uses `reprepro`, pushes to `gs://apt-tzinit-org`):
```sh
bash helpers/aptrepo.sh --root release      # or: dev | rc
```

**Rebuild the download website** (signs packages, generates index pages, pushes to `gs://packages-tzinit-org`):
```sh
bash helpers/mksite.sh
```

**Sync packages down from the bucket** (into `./incoming`, needed before `aptrepo.sh`/`mksite.sh` if run separately):
```sh
bash helpers/dwn_pkg.sh
```

**Local Debian package build** (run inside the Octez source tree after `make`; flag-driven):
```sh
sh pkgscripts/dpkg/make_dpkg.sh --packages "node baker client" --pkgname octez --revision 1
```

**Local RPM package build** (env-var driven, takes packages as a positional arg):
```sh
OCTEZ_PKGNAME=octez OCTEZ_PKGREV=1 OCTEZ_PKGMAINTAINER=packages@tezos.foundation \
  sh pkgscripts/rpm/make_rpm.sh "node baker client"
```

## Architecture

### Build flow

1. `build_pkg.sh` sources `environment`, reads `platforms`, and maps `BRANCH` to a target root under the bucket (see *GCS layout*).
2. For each target OS it runs `gcloud compute instances create` (x86 or arm64 machine/zone depending on the name), resolving the image with `helpers/parse_images.pl`.
3. It `scp`s `helpers/_buildscript.sh` (as `buildscript.sh`) and the `pkgscripts/` tree to each VM, then launches `buildscript.sh` in the background over SSH, passing `--targetdir`, `--branch`, `--evm-branch`, `--srn-branch`, `--pkgname`, `--revision`, and any of `--devmode`/`--override-version`/`--blst-portable`.
4. On the VM, `_buildscript.sh` installs system deps, OPAM and Rust, clones `https://gitlab.com/tezos/tezos.git`, checks out and builds the branch (`make build-deps && make`, or `make BLST_PORTABLE=yes` when `--blst-portable` is set), then runs the packaging script and writes status to `/tmp/status`.
5. If `EVMBRANCH`/`SRNBRANCH` differ from `BRANCH`, the VM does **additional** checkouts/builds of those branches to package `evm-node` / `smart-rollup-node` separately. The SRN version can be derived from a branch named `octez-smart-rollup-node-v<version>`.
6. Finished packages are `gcloud storage cp`-ed to `${targetdir}` in the bucket.
7. The orchestrator polls `/tmp/status` on each VM every `--sleep` seconds (default 180) until each reports `FINISHED` or `FAILED:*`. On `FINISHED` (and not `--devmode`) it deletes the VM.
8. If syncing is enabled, it runs `helpers/dwn_pkg.sh`, then `aptrepo.sh`/`mksite.sh` if `--buildapt`/`--buildsite` were passed (otherwise it prints a reminder to run them manually).

### Package definition pattern

Each package is declared by a set of files. The build scripts auto-discover packages by globbing `*-control.in` / `*-spec.in` when `--packages` is not given.

| File | Purpose |
|------|---------|
| `dpkg/<name>-control.in` | Debian control template — tokens: `@PKG@` (full name, e.g. `octez-node`), `@VERSION@`, `@ARCH@`, `@MAINT@`, `@DEPENDS@` (auto shlib deps), `@DPKG@` (name prefix, e.g. `octez`) |
| `rpm/<name>-spec.in` | RPM spec template — same tokens plus `@REVISION@` and `@FAKESRC@` |
| `pkg-common/<name>-binaries` | Newline-separated list of binary paths (relative to the Octez tree) installed to `/usr/bin/` |
| `pkg-common/<name>.service` | systemd unit — copied to `<systemd_dir>/octez-<name>.service` |
| `pkg-common/<name>.default` | environment file for the service, copied to the defaults dir as `octez-<name>` |
| `pkg-common/<name>.conf` | optional example config file |
| `pkg-common/<name>.vshell` | shell script that prints the package version (used when it differs from the Octez version — currently `evm-node`) |
| `pkg-common/<name>.version` | static version string file (currently `zcash-params` → `1.0.0`) |
| `dpkg/<name>.postinst` etc. | dpkg maintainer scripts (`postinst`/`preinst`/`postrm`/`prerm`) |

To add a package: create `dpkg/<name>-control.in` (and/or `rpm/<name>-spec.in`) plus `pkg-common/<name>-binaries`, and add it to `REGULARPKG` in `helpers/_buildscript.sh` if it should build by default.

### VM detection (Debian vs RPM)

`_buildscript.sh` detects the OS at runtime: if `apt` is in `PATH` → Debian path (`DEBIAN=1`, `make_dpkg.sh`, `.deb`); otherwise → RPM path (`make_rpm.sh`, `.rpm`). Note the defaults dir differs: dpkg installs to `/etc/default/`, rpm to `/etc/defaults/`; systemd units go to `/lib/systemd/system` (dpkg) vs `/usr/lib/systemd/system` (rpm). The dpkg script is the actively maintained, flag-driven path.

### GCS buckets and layout

Three buckets are involved:

- **`${BUCKET}`** (e.g. `gs://pkgbeta-tzinit-org`) — raw uploaded packages. VMs upload to a root chosen by branch:
  - release / `latest-release` → `${BUCKET}/incoming/` (or `${BUCKET}/incoming/BLSTPORTABLE/` with `--blst-portable`)
  - `octez-v*rc*` / `octez-v*beta*` → `${BUCKET}/incoming/RC/`
  - any other branch (dev) → `${BUCKET}/incoming/DEVEL/`
  - with `--devmode`, `incoming` is replaced by `testing` in all of the above
  - the final path is `<root>/<os>/`, e.g. `incoming/DEVEL/debian-13/*.deb`
- **`gs://apt-tzinit-org`** — the reprepro-generated APT repository (`aptrepo.sh`). Suite codenames are mapped in `aptrepo.sh` (`debian-13`→`trixie`, `debian-12`→`bookworm`, `ubuntu-2404`→`noble`, …).
- **`gs://packages-tzinit-org`** — the static download website with signed packages and HTML indices (`mksite.sh`).

Local working dirs `./incoming`, `./repos`, and `./website` are git-ignored. `helpers/mks3idx` generates the minimal HTML directory listings. `web/index.html` is the site landing page; `apt/` holds the reprepro `distributions`/`options` config and the public signing keys (`apt/keys/*.asc`). See `doc/APTREPO.md` for the full APT repo design.

### Version numbering (`getOctezVersion` in `pkg-common/utils.sh`)

- If `pkg-common/<name>.version` exists → use it verbatim (e.g. `zcash-params` → `1.0.0`).
- Else if `pkg-common/<name>.vshell` exists → run it (e.g. `evm-node` runs `octez-evm-node --version`).
- Else run `dune exec octez-version` in the Octez tree; a `*dev` version becomes `99<short-sha>` (so it sorts after real releases), otherwise the version is tilde/whitespace-cleaned for dpkg/RPM.
- `--override-version` bypasses all of the above. For `master`, `_buildscript.sh` sets the override to a `YYYYMMDDHHMM` timestamp.
- `--revision` (`OCTEZ_PKGREV`, default `1`) is the package revision appended after the version.

### Important env vars / options

| Variable / flag | Default | Meaning |
|-----------------|---------|---------|
| `--blst-portable` | off | Build with `BLST_PORTABLE=yes` (portable but slower binaries); off by default |
| `--pkgname` / `OCTEZ_PKGNAME` | `octez` | Prefix for all package names (`@DPKG@`) |
| `OCTEZ_PKGMAINTAINER` | `packages@tezos.foundation` | Maintainer field; set/exported by `_buildscript.sh` |
| `--revision` / `OCTEZ_PKGREV` | `1` | Package revision number |
| `--evm-branch` / `EVMBRANCH` | `$BRANCH` | Branch for the EVM node (built separately if it differs) |
| `--srn-branch` / `SRNBRANCH` | `$BRANCH` | Branch for the smart-rollup node (built separately if it differs) |
| `--devmode` / `DEVELOPER` | off (`0`) | Route uploads to `testing/` and skip VM deletion |
| `RUSTVERSION` | `1.88.0` | Rust toolchain pinned on the VM |
