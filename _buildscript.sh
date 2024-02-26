#!/bin/bash
#
TARGET=""
BRANCH=latest-release
OCTEZ_PKGREV=1
VERSION="" # if set, override dune output
OCTEZ_PKGMAINTAINER="dpkg@chrispinnock.com" # XXX

IGNOREOPAMDEPS=0


status () {
	echo "$1" > /tmp/status
}

fail () {
	echo "FAILED: $1" > /tmp/status
	exit 1
}

[ -z "$1" ] && fail "GCS TARGET NOT SET"
TARGET="$1"

[ ! -z "$2" ] && BRANCH="$2"
[ ! -z "$3" ] && OCTEZ_PKGNAME="$3"
[ ! -z "$4" ] && OCTEZ_PKGREV="$4"
[ ! -z "$5" ] && VERSION="$5"

export OCTEZ_PKGNAME OCTEZ_PKGREV
export OPAMYES="true"

echo "PKGNAME: ${OCTEZ_PKGNAME}"

# If there is apt it's a Debian style system
# We assume everything else uses RPM and YUM
#
DEBIAN=0
which apt >/dev/null 2>&1
if [ "$?" = "0" ]; then
	DEBIAN=1
fi

# Update the OS and get the dependencies
# 
# XXX it would be nice here to detect genuine Debian and remove man-db
# which speeds things up (and is not possible on Ubuntu)
#

PATH=/usr/local/bin:$PATH
export PATH

if [ "$DEBIAN" = "1" ]; then
	status "OS UPDATE (APT)"
	sudo apt-get update
	sudo apt-get upgrade -y

	status "OCTEZ DEPENDENCIES"
	sudo apt-get install -y rsync git m4 build-essential patch unzip wget opam jq bc
	sudo apt-get install -y autoconf cmake libev-dev libffi-dev libgmp-dev libhidapi-dev pkg-config zlib1g-dev libprotobuf-dev protobuf-compiler
	sudo apt-get install -y sqlite3


else
	status "OS UPDATE (YUM)"
	sudo dnf install -y 'dnf-command(config-manager)'
	sudo dnf config-manager --set-enabled devel
	sudo dnf config-manager --set-enabled crb

	# XXX may not be neededd
	status "OCTEZ DEPENDENCIES"
	sudo dnf update -y
 	for pkg in libev-devel gmp-devel hidapi-devel libffi-devel zlib-devel \
          libpq-devel m4 perl git pkg-config rpmdevtools python3-devel \
          python3-setuptools wget rsync which cargo autoconf \
          systemd systemd-rpm-macros cmake python3-wheel \
          gcc-c++ bubblewrap protobuf-compiler protobuf-devel \
        python3-tox-current-env mock sqlite sqlite-devel ; do
                sudo dnf install -y $pkg
        done
	  
	# Ocaml - needed for Redhet
	curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh > install.sh.in
	sed -e 's/read BINDIR/BINDIR=""/g' < install.sh.in > install.sh
	bash install.sh

	IGNOREOPAMDEPS=0
fi

# Rust
#
status "RUST"
wget https://sh.rustup.rs/rustup-init.sh
chmod +x rustup-init.sh
./rustup-init.sh --profile minimal --default-toolchain 1.64.0 -y
. $HOME/.cargo/env

# Get the sources
#
status "SOURCE CHECKOUT"
git clone https://gitlab.com/tezos/tezos.git tezos
cd tezos
git checkout ${BRANCH}

if [ ! -d scripts/dpkg ]; then
	# Hackery for branches without the scripts!
	#
	git checkout chrispinnock@pkg18w
	cp -pR scripts/dpkg $HOME
	cp -pR scripts/rpm $HOME
	cp -pR scripts/pkg-common $HOME
	git checkout ${BRANCH}
	git pull
	cd scripts
	ln -s $HOME/dpkg .
	ln -s $HOME/rpm .
	ln -s $HOME/pkg-common .
	cd ..
fi

# Rev up OPAM
#
status "OPAM INIT"
opam init --bare --yes

if [ "$IGNOREOPAMDEPS" = "1" ]; then
	#opam option depext-run-installs=true
	opam option depext=false
fi

# Make all the build dependencies
#
status "BUILD DEPS"
make build-deps
[ "$?" != "0" ] && fail "BUILD DEPS"

eval `opam env`

# Make
#
status "MAKE"
export BLST_PORTABLE=yes
make BLST_PORTABLE=yes
[ "$?" != "0" ] && fail "MAKE"

export OCTEZ_PKGMAINTAINER
eval `opam env`

# Use the correct target to build the packages
#
EXT=""
if [ "$DEBIAN" = "1" ]; then
	status "DPKG PACKAGES"
	make dpkg
	[ "$?" != "0" ] && fail "DPKG PACKAGES"
	EXT=".deb"
else
	status "RPM PACKAGES"
	make rpm
	[ "$?" != "0" ] && fail "RPM PACKAGES"
	EXT=".rpm"
fi

# Copy the packages to the storage bucket
#
status "COPY TO CLOUD"
gcloud storage cp octez-*${EXT} ${TARGET}
[ "$?" != "0" ] && fail "COPY TO CLOUD"

# Sending this will tell the master process to take down this VM
#
status "FINISHED"

