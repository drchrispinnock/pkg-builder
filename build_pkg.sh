#!/bin/bash

# $0 [branch [target1 [target2 [ ... ]]]]

[ -z "$1" ] && echo "Usage: $0 branch [targets [revision]]" && exit 1

# Project - must be setup
#
[ -f environment ] && . environment

[ -z "${PROJECT}" ] && echo "PROJECT must be set" && exit 1
[ -z "${SERVICEACCT}" ] && echo "SERVICEACCT must be set" && exit 1
[ -z "${BUCKET}" ] && echo "BUCKET must be set" && exit 1

X86=${X86:-c3-standard-8}
X86ZONE=${X86ZONE:-europe-west1-b}
ARM64=${ARM64:-t2a-standard-8}
ARMZONE=${ARMZONE:-us-central1-a}
SIZE=${SIZE:-200}

FAIL=0

TARGETS="debian-12" 

[ -f "platforms" ] && TARGETS=$(cat platforms)

[ -z "$OVERRIDE" ] && echo "Override version: $OVERRIDE"

BRANCH="latest-release"
[ ! -z "$1" ] && BRANCH=$1
[ ! -z "$2" ] && TARGETS="$2"
[ ! -z "$3" ] && REVISION="$3"

FORCE=1
STATUSSLEEP=120 # 2 minutes

CLEANUPSH=cleanup.$$.sh
CONNECT=connect.$$.txt
rm -f ${CLEANUPSH}
LOCALLOG=log.$$.txt

seed=`date +%Y%m%d%H%M%S`

log() {
	date=`date +"%Y%m%d %H:%M:%S"`
	echo "$date: $1"
}

# Can be run from cron and will use git-monitor to see if 
# there are any changes on the branch
#
if [ "$FORCE" = "0" ]; then
	git-monitor check | grep ${BRANCH}
	if [ "$?" != "0" ]; then
		log "Nothing to do"
		exit 0
	fi
fi

echo "===> Building from branch: ${BRANCH}"
	
PKGNAME=octez-unoff

# Setup VMs and despatch
#
for OS in ${TARGETS}; do

	NAME=bd-${seed}-${OS}
	echo "===> ${NAME}"

	IMAGE=`./helpers/parse_images.pl ${OS}`
	TARGETDIR=${BUCKET}/${OS}
	
	# Bring up a VM
	#
	MACHINE=${X86}
	ZONE=${X86ZONE}
	echo ${OS} | grep 'arm64' >/dev/null 2>&1
	if [ "$?" = "0" ]; then
		MACHINE=${ARM64}
		ZONE=${ARMZONE}
	fi
	
	echo "=> Using image ${IMAGE}"
	gcloud -q compute instances create ${NAME} \
       	 --zone=${ZONE} \
	 --project=${PROJECT} \
        --machine-type=${MACHINE} \
        --create-disk=auto-delete=yes,boot=yes,device-name=${NAME},image=${IMAGE},mode=rw,size=${SIZE},type=projects/${PROJECT}/zones/${ZONE}/diskTypes/pd-balanced \
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
		
		echo "=> Waiting for VM"
		sleep 30
		echo "=> To connect use:"
		echo "gcloud compute ssh ${NAME} --zone=${ZONE} --project=${PROJECT}"
		echo "gcloud compute ssh ${NAME} --zone=${ZONE} --project=${PROJECT}" >> ${CONNECT}
		echo "=> Starting build"
		FAIL=3
		while [ $FAIL -gt 0 ]; do
			gcloud -q compute scp --recurse pkgscripts \
				${NAME}:pkgscripts \
				--zone=${ZONE} \
				--project=${PROJECT}
			gcloud -q compute scp helpers/_buildscript.sh ${NAME}:buildscript.sh --zone=${ZONE} \
				--project=${PROJECT} >> ${LOCALLOG} 2>&1
			[ "$?" = "0" ] && break
			FAIL=$((FAIL-1))
			sleep 5
			
		done

		if [ "$FAIL" = "0" ]; then
			echo buildscript initiation failure
		else
			VMLIST="${VMLIST} ${NAME}"
			gcloud -q compute ssh ${NAME} --zone=${ZONE} \
				--project=${PROJECT} \
				--command="nohup sh ./buildscript.sh ${TARGETDIR} ${BRANCH} ${PKGNAME} ${REVISION} > buildlog.log 2>&1 &" \
				>> ${LOCALLOG} 2>&1
			echo "gcloud -q compute instances delete ${NAME} \
		        --zone=${ZONE} --delete-disks=all --project=${PROJECT}" >> ${CLEANUPSH}
			chmod +x ${CLEANUPSH}
		fi
	fi

done

echo "rm -f ${CLEANUPSH} ${CONNECT} ${LOCALLOG}" >> ${CLEANUPSH}

while [ "`echo ${VMLIST} | tr -d ' '`" != "" ]; do

	echo "====> Status at `date`"

	NEWVMLIST=""

	statusfile="status.$$"	
	for NAME in ${VMLIST}; do
	
		ZONE=${X86ZONE}
		echo ${NAME} | grep 'arm64' >/dev/null 2>&1
	
		if [ "$?" = "0" ]; then
			ZONE=${ARMZONE}
		fi
		
		printf "${NAME}\t"
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
			gcloud -q compute instances delete ${NAME} \
			        --zone=${ZONE} --delete-disks=all \
				--project=${PROJECT} >> ${LOCALLOG} 2>&1
			echo "FINISHED"
		else if [[ "$state" =~ "FAILED:".* ]]; then
			echo "$state"
			FAIL=1
			FAILVMLIST="${FAILVMLIST} ${NAME}"
		else
			echo "$state"
			NEWVMLIST="${NEWVMLIST} ${NAME}"
		fi; fi

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

sh helpers/sync_pkg.sh down
sh helpers/index.sh
sh helpers/sync_pkg.sh up

