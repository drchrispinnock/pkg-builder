#!/bin/bash
#

TARGET=""
OCTEZ_PKGREV=1
OCTEZ_PKGMAINTAINER="dpkg@chrispinnock.com" # XXX
IGNOREOPAMDEPS=0
DEVELOPER=0
PKGNAME="octez"
OVERRIDEVERS=""

ME=$HOME/pkg-builder/pkgscripts

while [ $# -gt 0 ]; do
    case $1 in
        --branch|-B)
            BRANCH="$2"; shift; ;;
        --devmode|-D)
            DEVELOPER=1 ;;
        --srn-branch)
            SRNBRANCH="$2"; shift; ;;
        --evm-branch)
            EVMBRANCH="$2"; shift; ;;
        --override-version|-O) OVERRIDEVERS="$2"; shift; ;;
        --revision|-R)
            REVISION="$2"; shift; ;;
        --pkgname)
            PKGNAME="$2"; shift; ;;
        --targetdir)
            TARGET="$2"; shift; ;;
        -*) echo "WARN: unknown option" >&2; ;;
    esac
    shift
done


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

. $ME/pkg-common/utils.sh

export OPAMYES="true"

[ -z "$BRANCH" ] && BRANCH=master

echo "PKGNAME: ${PKGNAME}"
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

EXTRACLIOPTS=""
[ "$DEVELOPER" = "1" ] && EXTRACLIOPTS="$EXTRACLIOPTS --devmode"
[ -n "$OVERRIDEVERS" ] && EXTRACLIOPTS="$EXTRACLIOPTS --override-version $OVERRIDEVERS"


# If there is apt it's a Debian style system
# We assume everything else uses RPM and YUM
#
DEBIAN=0
TOOL="$ME/rpm/make_rpm.sh"
EXT=".rpm"
which apt >/dev/null 2>&1
if [ "$?" = "0" ]; then
	DEBIAN=1
	TOOL="$ME/dpkg/make_dpkg.sh"
	EXT=".deb"
fi

initialPrep;

# Regular
REGULARPKG="client node baker dal-node teztale-archiver"
[ "$EVMBRANCH" = "$BRANCH" ] && REGULARPKG="$REGULARPKG evm-node"
[ "$SRNBRANCH" = "$BRANCH" ] && REGULARPKG="$REGULARPKG smart-rollup"

CLIOPTS="--revision $OCTEZ_PKGREV --pkgname $PKGNAME $EXTRACLIOPTS"

build $BRANCH
status "PACKAGES"
$TOOL --packages "${REGULARPKG}" $CLIOPTS
[ "$?" != "0" ] && fail "PACKAGES"
mv octez*$EXT $STAGING

if [ "$EVMBRANCH" != "$BRANCH" ]; then
    build $EVMBRANCH
    status "EVM PACKAGES"
    $TOOL --packages "evm-node" $CLIOPTS
    [ "$?" != "0" ] && softfail "EVM PACKAGES"
    mv octez-evm-node*$EXT $STAGING
fi

if [ "$SRNBRANCH" != "$BRANCH" ]; then
    build $SRNBRANCH
    status "SRN PACKAGES"
    $TOOL --packages "smart-rollup" $CLIOPTS
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
