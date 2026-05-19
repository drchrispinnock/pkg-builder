#!/bin/sh

# Common packaging routines for Octez
#

# A better way to do this would be to build the package from source
# but given the various hurdles of Rust and OPAM during the build
# we construct packages afterwards. Which is not best practice :-)
#
# A better strategy would be to extract the version number, build a
# master spec file, build Octez and then make the packages from the
# master spec file.
#
# Place files in the dpkg directory to declare a package. e.g.
#
# baker-control.in      - a template for the Debian control file
#
# Place files in the rpm directory to declare packages similarly:
#
# baker-spec.in         - a template for the RPM SPEC file
# cf. https://rpm-packaging-guide.github.io/#binary-rpms
#
# These files are shared with the Debian package build in pkg-common
#
# baker.conf            - an example configuration file /optional)
# baker-binaries.in        - the list of binaries to include
# baker.initd.in           - System V init script (optional)
#
# You can set OCTEZ_PKGMAINTAINER and OCTEZ_PKGNAME in the environment
# to change from the defaults.
#

# Variables
#
# Package maintainer
OCTEZ_PKGMAINTAINER=${OCTEZ_PKGMAINTAINER:-chris@chrispinnock.com}
#
# Package name used in dpkg or rpm name
OCTEZ_PKGNAME=${OCTEZ_PKGNAME:-octez}
#
# Real name used in scripts (usually octez)
OCTEZ_REALNAME=${OCTEZ_REALNAME:-octez}
#
# Revision
OCTEZ_PKGREV=${OCTEZ_PKGREV:-1}

export OCTEZ_PKGMAINTAINER
export OCTEZ_PKGNAME
export OCTEZ_REALNAME
export OCTEZ_PKGREV

RUSTVERSION=${RUSTVERSION:-1.88.0}

# Issue Warnings
#

warnings() {
  # Generic warning about BLST_PORTABLE=yes
  #
  BLST_PORTABLE=${BLST_PORTABLE:-notused}
  if [ "$BLST_PORTABLE" != "yes" ]; then
    echo "WARNING: BLST_PORTABLE is not set to yes in your environment"
    echo "If the binaries were not made with BLST_PORTABLE=yes then they"
    echo "might not run on some platforms."
  fi
}

# Get Octez version from the build
#

getOctezVersion() {

  BR=$(git branch)
  COMMIT_SHORT_SHA=$(git rev-parse --short HEAD)

  if ! _vers=$(dune exec octez-version 2>/dev/null); then
    echo "Cannot get version. Try eval \`opam env\`?" >&2
    exit 1
  fi
  _vers_fix=$(echo "$_vers" | sed -e 's/Octez //' -e 's/(.*$//' -e 's/(build.*$//'  -e 's/\~//' -e 's/^\+//' -e 's/^[[:blank:]]//' -e 's/[[:blank:]]$//')
  case "$_vers" in
  	*dev)
	    # Versions must start with numbers on dpkg
	    RET="99$COMMIT_SHORT_SHA"
	    ;;
	*)
	    RET=$_vers_fix
	    ;;
  esac

  echo "$RET"

}

# Build init.d scripts
#

initdScripts() {
  _initin=$1     # Init script
  _inittarget=$2 # The target (e.g. octez-node)
  _stagedir=$3   # The staging area
  _initd="${_stagedir}/etc/init.d"

  if [ -f "${_initin}" ]; then
    mkdir -p "${_initd}"
    cp "${_initin}" "${_initd}/${_inittarget}"
    chmod +x "${_initd}/${_inittarget}"
  fi

}

initialPrep() {
    PATH=/usr/local/bin:$PATH
    export PATH

    if [ "$DEBIAN" = "1" ]; then
    	status "OS UPDATE (APT)"
    	sudo apt-get update
    	sudo apt-get upgrade -y

    	status "OCTEZ DEPENDENCIES"
    	sudo apt-get install -y rsync git m4 build-essential patch unzip wget jq bc
    	sudo apt-get install -y bubblewrap
    	sudo apt-get install -y autoconf cmake libev-dev libffi-dev libgmp-dev libhidapi-dev pkg-config zlib1g-dev libprotobuf-dev protobuf-compiler
    	sudo apt-get install -y sqlite3 libpq-dev libsqlite3-dev

    else

    	status "OS UPDATE (YUM)"
    	sudo dnf install -y 'dnf-command(config-manager)'
    	sudo dnf config-manager --set-enabled devel
    	sudo dnf config-manager --set-enabled crb


	    status "OCTEZ DEPENDENCIES"
		sudo dnf update -y
     	for pkg in libev-devel gmp-devel hidapi-devel libffi-devel zlib-devel \
            libpq-devel m4 perl git pkg-config rpmdevtools python3-devel \
            python3-setuptools wget rsync which cargo autoconf \
            systemd systemd-rpm-macros cmake openssl-devel python3-wheel \
            gcc-c++ bubblewrap protobuf-compiler protobuf-devel \
            python3-tox-current-env mock sqlite3 sqlite sqlite-devel jq ; do
                sudo dnf install -y $pkg
        done

	    IGNOREOPAMDEPS=0
    fi

    status "OPAM"
    curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh > install.sh.in
    sed -e 's/read -r BINDIR/BINDIR=""/g' -e 's/read_tty BINDIR/BINDIR=""/g' < install.sh.in > install.sh
    bash install.sh

    # Rust
    #
    status "RUST"
    wget https://sh.rustup.rs/rustup-init.sh
    chmod +x rustup-init.sh
    ./rustup-init.sh --profile minimal --default-toolchain $RUSTVERSION -y
    . $HOME/.cargo/env


    status "SOURCE CHECKOUT"
    git clone https://gitlab.com/tezos/tezos.git tezos
    cd tezos

    export OCTEZ_PKGMAINTAINER
}

# Fix up the binary lists
#
fixBinaryList() {
  _binlist=$1
  _binaries=""

  if [ -f "${_binlist}" ]; then
    _binaries=$(cat "${_binlist}" 2> /dev/null)
  fi
  echo "$_binaries"
}

# Deal with Zcash parameters
#
zcashParams() {
  _pkgzcash=$1
  _zcashtgt=$2
  # Where the zcash files are
  _zcashdir=${3:-"_opam/share/zcash-params"}

  if [ -f "${_pkgzcash}" ]; then
    zcashstuff=$(cat "${_pkgzcash}" 2> /dev/null)
    echo "=> Zcash"
    mkdir -p "${_zcashtgt}"
    for shr in ${zcashstuff}; do
      cp "${_zcashdir}/${shr}" \
        "${_zcashtgt}"
    done
  fi
}

build() {

    _br=${1}
    git checkout $_br
    git pull
    rm -rf _build _opam ~/.opam

    # Rev up OPAM
    #
    status "OPAM INIT ($_br)"
    opam init --bare --yes
    opam option depext-run-installs=false

    if [ "$IGNOREOPAMDEPS" = "1" ]; then
    	#opam option depext-run-installs=true
    	opam option depext=false
    fi

    # Make all the build dependencies
    #
    status "BUILD DEPS ($_br)"
    make build-deps
    [ "$?" != "0" ] && fail "BUILD DEPS"

    eval `opam env`

    # Make
    #
    status "MAKE ($_br)"
    export BLST_PORTABLE=yes
    make BLST_PORTABLE=yes
    [ "$?" != "0" ] && fail "MAKE"
    eval `opam env`
}
