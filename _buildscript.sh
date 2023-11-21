#!/bin/bash
#
TARGET=""
BRANCH=latest-release
REVISION=2
VERSION="" # if set, override dune output
OCTEZ_PKGMAINTAINER="dpkg@chrispinnock.com" # XXX

status () {
	echo "$1" > /tmp/status
}

fail () {
	echo "$1" > /tmp/status
	exit 1
}

[ -z "$1" ] && fail "GCS TARGET NOT SET"
TARGET="$1"

[ ! -z "$2" ] && BRANCH="$2"
[ ! -z "$3" ] && OCTEZ_PKGNAME="$3"
[ ! -z "$4" ] && REVISION="$4"
[ ! -z "$5" ] && VERSION="$5"

export OCTEZ_PKGNAME

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

if [ "$DEBIAN" = "1" ]; then
	status "DEBIAN OS UPDATE"
	sudo apt-get update
	sudo apt-get upgrade -y

	status "OCTEZ DEPENDENCIES"
	sudo apt-get install -y rsync git m4 build-essential patch unzip wget opam jq bc
	sudo apt-get install -y autoconf cmake libev-dev libffi-dev libgmp-dev libhidapi-dev pkg-config zlib1g-dev


else
	status "REDHAT OS UPDATE"
	sudo yum install -y rsync git m4 patch unzip wget jq bc
	sudo yum install -y make gcc gcc-c++ bubblewrap bzip2 libffi libffi-devel
	sudo yum install -y autoconf libev zlib zlib-devel cmake gmp gmp-devel 
	sudo yum install -y libev-devel hidapi hidapi-devel opam

	# HID Api
	#wget https://github.com/libusb/hidapi/archive/refs/tags/hidapi-0.13.1.tar.gz

	# Ocaml
	#sudo bash -c "sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)"

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
	git checkout master
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
#opam option depext-run-installs=false

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
	./scripts/dpkg/make_dpkg.sh
# XXX	make dpkg
# XXX	[ "$?" != "0" ] && fail "DPKG PACKAGES"
	EXT=".deb"
else
	status "RPM PACKAGES"
	./scripts/dpkg/make_rpm.sh
# XXX	make rpm
# XXX	[ "$?" != "0" ] && fail "RPM PACKAGES"
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

