# Setting Up an APT Repository for Debian-Style Packages

The cleanest path is `reprepro` for a single-origin repo. It handles the pool
layout, generates the `Packages`/`Release` indices, and signs everything for
you. Here's the full shape of it.

## Repository side

Install the tooling and create a GPG signing key dedicated to the repo (keep it
off the public-facing box if you can):

```bash
apt install reprepro
gpg --quick-generate-key "My Org Apt Repo <apt@example.com>" ed25519 sign never
gpg --list-secret-keys --keyid-format=long   # grab the fingerprint
```

Lay out the base directory. reprepro only needs `conf/distributions` to start:

```
/srv/apt/
  conf/
    distributions
    options        # optional
```

`conf/distributions` defines each suite you publish. One stanza per codename,
blank-line separated:

```
Origin: My Org
Label: My Org
Codename: bookworm
Suite: stable
Architectures: amd64 arm64 source
Components: main
Description: My Org package repository
SignWith: <FINGERPRINT>
```

`conf/options` is handy to avoid repeating flags:

```
verbose
basedir /srv/apt
ask-passphrase
```

Then add packages — reprepro builds `pool/` and `dists/`, regenerates the
indices, and signs the `Release` (producing both inline `InRelease` and detached
`Release.gpg`):

```bash
reprepro -b /srv/apt includedeb bookworm mypackage_1.0_amd64.deb
reprepro -b /srv/apt list bookworm          # verify
```

A few reprepro quirks worth knowing: it enforces one version of a package per
suite per component (no accidental duplicates), it won't let you re-add the same
filename with different contents, and `includedeb` reads the `.deb`'s own control
fields to place it — so the architecture in your `distributions` stanza must
include whatever the package declares.

## Serving it

The output under `/srv/apt` is just static files — point any web server at it.
The only rule apt cares about is that `dists/` and `pool/` sit at the URL root
you advertise:

```nginx
server {
    server_name apt.example.com;
    root /srv/apt;
    autoindex off;
    location / { try_files $uri $uri/ =404; }
}
```

An S3/GCS bucket behind a CDN works equally well since nothing is dynamic.
Export the public key for clients:

```bash
gpg --armor --export <FINGERPRINT> > /srv/apt/myorg.asc
```

## Client side

Skip `apt-key` entirely — it's gone in current Debian. Drop the key in
`/etc/apt/keyrings/` and reference it explicitly with `signed-by`. Modern apt
reads armoured `.asc` directly, so no dearmoring needed:

```bash
curl -fsSL https://apt.example.com/myorg.asc \
  | sudo tee /etc/apt/keyrings/myorg.asc > /dev/null
```

Then the deb822 `.sources` format, which is the preferred style now and far more
readable than the one-liner:

```
# /etc/apt/sources.list.d/myorg.sources
Types: deb
URIs: https://apt.example.com
Suites: bookworm
Components: main
Signed-By: /etc/apt/keyrings/myorg.asc
```

The equivalent legacy one-liner, if you need it:

```
deb [signed-by=/etc/apt/keyrings/myorg.asc] https://apt.example.com bookworm main
```

## Alternatives

If you'll be mirroring upstream repos, doing snapshot/rollback workflows, or
publishing the same packages to multiple suites, `aptly` is the better tool —
its repo/snapshot/publish model is more flexible than reprepro's, at the cost of
more moving parts. And if you want to understand what's underneath either tool,
the raw approach is `dpkg-scanpackages` (or `apt-ftparchive packages`) to
generate `Packages`, `apt-ftparchive release` for the `Release` file, then a
manual `gpg --clearsign` into `InRelease` — but there's rarely a reason to
hand-roll it in production.

## Operational note

The `Release` file carries an expiry, and reprepro/aptly set a validity window.
If you publish infrequently, clients will start failing with "Release file
expired" — either re-run the export on a schedule or set a longer `ValidUntil`
window so it doesn't bite you.
