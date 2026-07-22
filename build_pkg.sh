#!/bin/bash

# Check for Google Cloud tools
#
which gcloud >/dev/null 2>&1
if [ "$?" != "0" ]; then
    echo "Please install gcloud and initiate a login session" >&2
    exit 1
fi

# Defaults
#
DEVELOPER=0
OVERRIDEVERS=""

# Sync packages
#
SYNCPKG=1
PKGNAME=octez
BUILDAPT=0
BUILDSITE=0
BLSTP=0

# Default targets
#
TARGETS="debian-13"
[ -f "platforms" ] && TARGETS=$(cat platforms)

# Default branch in latest-release
#
BRANCH="latest-release"
ROOT="release"
TROOT=""

# Status sleep - poll every n minutes
#
STATUSSLEEP=180 # 3 minutes

# Pull in environment
#
[ -f "environment" ] && . ./environment

# The package revision
#
REVISION=1

usagestring="Usage: build_pkg.sh [--branch GitBranch]                                                            [--srn-branch Branch for Smart Rollup Node]                                     [--evm-branch Branch for EVM Node]                                              [--targets \"debian-13 ...\"]                                                     [--revision package revision]                                                   [--project GCP project]                                                         [--service-account GCP service account]                                         [--bucket GCP storage bucket]                                                   [--(no)-sync] whether to sync the packages to the bucket                        [--sleep seconds] interval between polls                                        [--devmode] push a developer variable through the process"

Usage() {
    _exit="$1"
    echo "$usagestring" >&2
    exit $_exit
}

while [ $# -gt 0 ]; do
    case $1 in
        --targets|--target|-T)
            TARGETS="$2"; shift; ;;
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
        --project|-P)
            PROJECT="$2"; shift; ;;
        --pkgname)
            PKGNAME="$2"; shift; ;;
        --service-account|-S)
            SERVICEACCT="$2"; shift; ;;
        --bucket|-b)
            BUCKET="$2"; shift; ;;
        --sleep)
            STATUSSLEEP="$2"; shift; ;;
        --sync|--sync-packages)
            SYNCPKG=1; ;;
        --no-sync|--no-sync-packages)
            SYNCPKG=0; ;;
        --buildapt)
            BUILDAPT=1; ;;
        --buildsite)
            BUILDSITE=1; ;;
        --blst-portable)
            BLSTP=1 ;;
        --help|-h) Usage 0; ;;
        -*) Usage 1; ;;
    esac
    shift
done

case $BRANCH in
    octez-v*rc*|octez-v*beta*)
        echo "Release candidate"
        TROOT=${BUCKET}/incoming/RC
        [ "$DEVELOPER" = "1" ] && TROOT=${BUCKET}/testing/RC
        ROOT="rc"
        ;;
    latest-release|octez-v*)
        echo "Release"
        TROOT=${BUCKET}/incoming
        [ "$DEVELOPER" = "1" ] && TROOT=${BUCKET}/testing
        if [ "$BLSTP" = 1 ]; then
            TROOT=${BUCKET}/incoming/BLSTPORTABLE
            ROOT="BLSTPORTABLE"
        fi
        # Nous the EVM and SRN branch for releases
        #
        if [ -z "$EVMBRANCH" ] && [ -z "$SRNBRANCH" ] && [ -f latest-releases.env ]; then
            . ./latest-releases.env
        fi
        ;;
    *)
        echo "Development"
        TROOT=${BUCKET}/incoming/DEVEL
        [ "$DEVELOPER" = "1" ] && TROOT=${BUCKET}/testing/DEVEL
        ROOT="dev"
        ;;
esac

# If no specific branchs, use the current one for EVM and SRN
#
[ -z "$EVMBRANCH" ] && EVMBRANCH=${BRANCH}
[ -z "$SRNBRANCH" ] && SRNBRANCH=${BRANCH}

# Project - must be setup
#
[ -z "${PROJECT}" ] && echo "GCP PROJECT must be set" && exit 1
[ -z "${SERVICEACCT}" ] && echo "GCP SERVICEACCT must be set" && exit 1
[ -z "${BUCKET}" ] && echo "GCP BUCKET must be set" && exit 1

X86=${X86:-c4-standard-8}
X86ZONE=${X86ZONE:-europe-west6-a}
ARM64=${ARM64:-c4a-standard-8}
ARMZONE=${ARMZONE:-europe-west6-b}
SIZE=${SIZE:-200}

FAIL=0

TAG=$$
CLEANUPSH=cleanup.$TAG.sh
CONNECT=connect.$TAG.txt
LOCALLOG=log.$TAG.txt
rm -f ${CLEANUPSH}

echo "Package build"
printf "TARGETS:  ";
for t in ${TARGETS}; do printf "$t "; done; echo ""
echo "BRANCH:   ${BRANCH}"
echo "EVM:      ${EVMBRANCH}"
echo "SRN:      ${SRNBRANCH}"
echo "Revision: ${REVISION}"
echo "Clean-up: ${CLEANUPSH}"
echo "Connect:  ${CONNECT}"
echo "Log:      ${LOCALLOG}"
echo "Root:     ${TROOT}"
echo "CTRL+C to break. Sleeping 5 seconds..."
sleep 5

seed=`date +%Y%m%d%H%M%S`

log() {
	date=`date +"%Y%m%d %H:%M:%S"`
	echo "$date: $1"
}

echo "===> Building from branch: ${BRANCH}"

VMLIST=""
declare -A OSFORNAME
declare -A ZONEFORNAME

# Setup VMs and despatch
#
for OS in ${TARGETS}; do

	NAME=bd-${seed}-${OS}
	echo "==> ${NAME}"

	IMAGE=`./helpers/parse_images.pl ${OS}`

	MACHINE=${X86}
	ZONE=${X86ZONE}
	disktype="pd-balanced"
	echo ${OS} | grep 'arm64' >/dev/null 2>&1
	if [ "$?" = "0" ]; then
		MACHINE=${ARM64}
		ZONE=${ARMZONE}
		disktype="hyperdisk-balanced"
	fi
	OSFORNAME[${NAME}]=${OS}
	ZONEFORNAME[${NAME}]=${ZONE}

	echo "=> Using image ${IMAGE}"
	gcloud -q compute instances create ${NAME} \
        --zone=${ZONE} \
        --project=${PROJECT} \
        --machine-type=${MACHINE} \
        --create-disk=auto-delete=yes,boot=yes,device-name=${NAME},image=${IMAGE},mode=rw,size=${SIZE},type=projects/${PROJECT}/zones/${ZONE}/diskTypes/${disktype} \
        --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
        --maintenance-policy=MIGRATE \
        --provisioning-model=STANDARD \
        --scopes=https://www.googleapis.com/auth/cloud-platform \
        --no-shielded-secure-boot \
        --shielded-vtpm \
        --shielded-integrity-monitoring \
        --reservation-affinity=any \
        --labels=goog-ec-src=vm_add-gcloud \
        --service-account=${SERVICEACCT} >> ${LOCALLOG} 2>&1

	if [ "$?" != "0" ]; then
		echo ${OS} initiation failure
	else


		echo "=> To connect use:"
		echo "gcloud compute ssh ${NAME} --zone=${ZONE} --project=${PROJECT}"
		echo "gcloud compute ssh ${NAME} --zone=${ZONE} --project=${PROJECT}" >> ${CONNECT}
		VMLIST="${VMLIST} ${NAME}"

	fi
done

echo "=> Waiting for dust to settle"
sleep 45

echo "===> Starting build"
NEWVMLIST=""

for NAME in ${VMLIST}; do

	VMFAIL=3

	OS=${OSFORNAME[${NAME}]}
	ZONE=${ZONEFORNAME[${NAME}]}

	echo "==> $NAME ($ZONE)"

	while [ $VMFAIL -gt 0 ]; do
	    gcloud -q compute scp helpers/_buildscript.sh ${NAME}:buildscript.sh --zone=${ZONE} \
		    --project=${PROJECT} >> ${LOCALLOG} 2>&1

		[ "$?" = "0" ] && break
		VMFAIL=$((VMFAIL-1))
		echo "Cannot connect - waiting"
		sleep 30

	done

	if [ "$VMFAIL" = "0" ]; then
		echo Cannot start build on $NAME
		FAIL=1
	else


        TARGETDIR=${TROOT}/${OS}
	    NEWVMLIST="${NEWVMLIST} ${NAME}"
		gcloud -q compute ssh $NAME \
			--command "mkdir -p pkg-builder" \
			--zone=${ZONE} \
			--project=${PROJECT}

		gcloud -q compute scp --recurse pkgscripts \
			${NAME}:pkg-builder/pkgscripts \
			--zone=${ZONE} \
			--project=${PROJECT} >> ${LOCALLOG} 2>&1

        EXTRACLIOPTS=""
        [ "$DEVELOPER" = "1" ] && EXTRACLIOPTS="$EXTRACLIOPTS --devmode"
        [ -n "$OVERRIDEVERS" ] && EXTRACLIOPTS="$EXTRACLIOPTS --override-version $OVERRIDEVERS"
        [ "$BLSTP" = "1" ] && EXTRACLIOPTS="$EXTRACLIOPTS --blst-portable"
		gcloud -q compute ssh ${NAME} --zone=${ZONE} \
			--project=${PROJECT} \
			--command="./buildscript.sh --targetdir ${TARGETDIR} \
			        --branch ${BRANCH} \
					--evm-branch ${EVMBRANCH} --srn-branch ${SRNBRANCH} \
					--pkgname ${PKGNAME} --revision ${REVISION} \
					    ${EXTRACLIOPTS}> buildlog.log 2>&1 &" \
			>> ${LOCALLOG} 2>&1
		echo "gcloud -q compute instances delete ${NAME} \
	        --zone=${ZONE} --delete-disks=all --project=${PROJECT}" >> ${CLEANUPSH}
		chmod +x ${CLEANUPSH}
	fi
done

echo "rm -f ${CLEANUPSH} ${CONNECT} ${LOCALLOG}" >> ${CLEANUPSH}
VMLIST=${NEWVMLIST}

while [ "`echo ${VMLIST} | tr -d ' '`" != "" ]; do
    NEWVMLIST=""
	echo "====> Status at `date`"

	statusfile="status.$$"

	for NAME in ${VMLIST}; do

	    ZONE=${ZONEFORNAME[${NAME}]}
		printf "${NAME} ($ZONE)\t"
		# Poll for success
		rm -f $statusfile
		state="NONE"
		gcloud -q compute scp ${NAME}:/tmp/status ${statusfile} --zone=${ZONE} --project=${PROJECT} >> ${LOCALLOG} 2>&1
		if [ -f "$statusfile" ]; then
			state=`cat $statusfile`
		fi
		rm -f $statusfile

		# Statuses
		#

		if [ "$state" = "FINISHED" ]; then
		    if [ "$DEVELOPER" = "0" ]; then
				gcloud -q compute instances delete ${NAME} \
		            --zone=${ZONE} --delete-disks=all \
					--project=${PROJECT} >> ${LOCALLOG} 2>&1
			fi
			echo "FINISHED"

		else
		    if [[ "$state" =~ "FAILED:".* ]]; then
				echo "$state"
				FAIL=1
				FAILVMLIST="${FAILVMLIST} ${NAME}"
		    else
				echo "$state"
				NEWVMLIST="${NEWVMLIST} ${NAME}"
		    fi
		fi
	done

	if [ "${NEWVMLIST}" != "" ]; then
		sleep ${STATUSSLEEP}
	fi
	VMLIST="${NEWVMLIST}"
done


[ "$FAIL" = "1" ] && echo "Failed - please clean up by hand!" && echo "$FAILVMLIST" && exit 1
rm -f ${CLEANUPSH}
rm -f ${LOCALLOG}
rm -f ${CONNECT}

if [ "$SYNCPKG" = "1" ]; then
    bash helpers/dwn_pkg.sh
    if [ "$BUILDAPT" = "1" ]; then
        bash helpers/aptrepo.sh --root $ROOT
    else
        echo "Run bash helpers/aptrepo.sh --root $ROOT at your convenience"
    fi
    if [ "$BUILDSITE" = "1" ]; then
        bash helpers/mksite.sh
    else
        echo "Run bash helpers/mksite.sh at your convenience"
    fi
fi
