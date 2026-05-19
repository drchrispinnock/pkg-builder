#!/bin/bash
#
TARGET=""
OCTEZ_PKGREV=1
VERSION="" # if set, override dune output
OCTEZ_PKGMAINTAINER="dpkg@chrispinnock.com" # XXX

IGNOREOPAMDEPS=0
DEVELOPER=0

STAGING=$HOME/staging
mkdir -p $STAGING

status () {
	echo "$1" > /tmp/status
	echo "============= $1"
}

softfail () {
	echo "FAILED (SOFT): $1" > /tmp/status
}

fail () {
    echo "FAILED: $1" > /tmp/status
	exit 1
}

. pkgscripts/pkg-common/utils.sh

[ -z "$1" ] && fail "GCS TARGET NOT SET"
TARGET="$1"

[ ! -z "$2" ] && OCTEZ_PKGNAME="$2"
[ ! -z "$3" ] && OCTEZ_PKGREV="$3"
[ ! -z "$4" ] && DEVELOPER="$4"

[ "$DEVELOPER" = "1" ] && TARGET="$TARGET/_sysctldev"

export OCTEZ_PKGNAME OCTEZ_PKGREV
export OPAMYES="true"

[ -z "$BRANCH" ] && BRANCH=master

echo "PKGNAME: ${OCTEZ_PKGNAME}"
echo "BRANCH: $BRANCH"

case $BRANCH in
	octez-v*)
		;;
	latest-release)
		;;
	*)
	TARGET=${TARGET}/dev
	;;
esac

# If there is apt it's a Debian style system
# We assume everything else uses RPM and YUM
#
DEBIAN=0
TOOL="$HOME/pkgscripts/rpm/make_rpm.sh"
EXT=".rpm"
which apt >/dev/null 2>&1
if [ "$?" = "0" ]; then
	DEBIAN=1
	TOOL="$HOME/pkgscripts/dpkg/make_dpkg.sh"
	EXT=".deb"
fi

initialPrep;

# Regular
REGULARPKG="client node baker dal-node teztale-archiver"
[ "$EVMBRANCH" = "$BRANCH" ] && REGULARPKG="$REGULARPKG evm-node"
[ "$SRNBRANCH" = "$BRANCH" ] && REGULARPKG="$REGULARPKG smart-rollup"

build $BRANCH
status "PACKAGES"
$TOOL "${REGULARPKG}"
[ "$?" != "0" ] && fail "PACKAGES"
mv octez*$EXT $STAGING

if [ "$EVMBRANCH" != "$BRANCH" ]; then
    build $EVMBRANCH
    status "EVM PACKAGES"
    $TOOL "evm-node"
    [ "$?" != "0" ] && softfail "EVM PACKAGES"
    mv octez-evm-node*$EXT $STAGING
fi

if [ "$SRNBRANCH" != "$BRANCH" ]; then
    build $SRNBRANCH
    status "SRN PACKAGES"
    $TOOL "smart-rollup"
    [ "$?" != "0" ] && softfail "SRN PACKAGES"
    mv octez-smart-rollup*$EXT $STAGING
fi

# Copy the packages to the storage bucket
#

status "COPY TO CLOUD"
gcloud storage cp $STAGING/octez-*${EXT} ${TARGET}
[ "$?" != "0" ] && fail "COPY TO CLOUD"

# Sending this will tell the master process to take down this VM
#
status "FINISHED"
