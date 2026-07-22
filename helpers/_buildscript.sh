#!/bin/bash
#

TARGET=""
REVISION=1
OCTEZ_PKGMAINTAINER="packages@tezos.foundation"
IGNOREOPAMDEPS=0
DEVELOPER=0
PKGNAME="octez"
OVERRIDEVERS=""
BLSTP="0"

ME=$HOME/pkg-builder/pkgscripts

BRANCH=""
EVMBRANCH=""
SRNBRANCH=""

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
        --blst-portable)
            BLSTP=1
            ;;
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
[ -z "$EVMBRANCH" ] && EVMBRANCH=$BRANCH
[ -z "$SRNBRANCH" ] && SRNBRANCH=$BRANCH

echo "PKGNAME: ${PKGNAME}"
echo "BRANCH: $BRANCH"




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
REGULARPKG="zcash-params client signer node baker dal-node teztale-archiver"
[ "$EVMBRANCH" = "$BRANCH" ] && REGULARPKG="$REGULARPKG evm-node"
[ "$SRNBRANCH" = "$BRANCH" ] && REGULARPKG="$REGULARPKG smart-rollup-node"

if [ "$BRANCH" = "master" ]; then
    today="$(date +%Y%m%d%H%M)"
    [ -z "$OVERRIDEVERS" ] && OVERRIDEVERS=$today
fi

EXTRACLIOPTS=""
[ "$DEVELOPER" = "1" ] && EXTRACLIOPTS="$EXTRACLIOPTS --devmode"
[ -n "$OVERRIDEVERS" ] && EXTRACLIOPTS="$EXTRACLIOPTS --override-version $OVERRIDEVERS"

CLIOPTS="--revision $REVISION --pkgname $PKGNAME $EXTRACLIOPTS"

build $BRANCH $BLSTP
status "PACKAGES"
$TOOL --packages "${REGULARPKG}" $CLIOPTS
[ "$?" != "0" ] && fail "PACKAGES"
mv octez*$EXT $STAGING

if [ "$EVMBRANCH" != "$BRANCH" ]; then
    build $EVMBRANCH $BLSTP
    status "EVM PACKAGES"
    $TOOL --packages "evm-node" $CLIOPTS
    [ "$?" != "0" ] && softfail "EVM PACKAGES"
    mv octez-evm-node*$EXT $STAGING
fi

if [ "$SRNBRANCH" != "$BRANCH" ]; then
    build $SRNBRANCH $BLSTP
    status "SRN PACKAGES"
    echo $SRNBRANCH | grep ^octez-smart-rollup-node-v >/dev/null
    if [ $? = "0" ]; then
        _vers_sr=$(echo $SRNBRANCH | sed -e 's/^octez-smart-rollup-node-v//g')
        CLIOPTS="$CLIOPTS --override-version $_vers_sr"
    fi
    $TOOL --packages "smart-rollup-node"  $CLIOPTS
    [ "$?" != "0" ] && softfail "SRN PACKAGES"
    mv octez-smart-rollup*$EXT $STAGING
fi

# Copy the packages to the storage bucket
#

status "COPY TO CLOUD"
touch .init
gcloud storage cp .init ${TARGET}/.init
gcloud storage cp $STAGING/octez-*${EXT} ${TARGET}
[ "$?" != "0" ] && fail "COPY TO CLOUD"


if [ "$DEVELOPER" = "1" ]; then
    status "DEVELOPER MODE"
fi
# Sending this will tell the master process to take down this VM
#
status "FINISHED"
