#!/bin/sh

# Project - must be setup
#

PROJECT=tf-pkg-build

SERVICEACCT="782994889379-compute@developer.gserviceaccount.com"
TARGETS="debian-11 debian-12 debian-12-arm64"
TARGETS="${TARGETS} ubuntu-2004-lts ubuntu-2204-lts" # ubuntu-2204-lts-arm64
#TARGETS="${TARGETS} ubuntu-2210-amd64 ubuntu-2304-amd64"
#TARGETS="${TARGETS} fedora-cloud-37 fedora-cloud-38"

BRANCH="latest-release"
[ ! -z "$1" ] && BRANCH=$1
shift
[ ! -z "$1" ] && TARGETS=$@

FORCE=1
BUCKET="gs://pkgbeta-tzinit-org/incoming"

STATUSSLEEP=120 # 2 minutes

CLEANUPSH=cleanup.$$.sh
rm -f ${CLEANUPSH}
LOCALLOG=log.txt

X86=c3-standard-8
X86ZONE=europe-west1-b
ARM64=t2a-standard-4
ARMZONE=us-central1-a

SIZE=150

seed=`date +%Y%m%d%H%M%S`

log() {
	date=`date +"%Y%m%d %H:%M:%S"`
	echo "$date: $1"
}

if [ "$FORCE" = "0" ]; then
	git-monitor check | grep ${BRANCH}
	if [ "$?" != "0" ]; then
		log "Nothing to do"
		exit 0
	fi
fi

echo "Building from branch: ${BRANCH}"

# Debian to begin
#
for OS in ${TARGETS}; do

	PKGNAME=octez

	# Remap to our ideal of the universe
	SHORT=""
	case ${OS} in
       	 	debian-11)
                SHORT="deb11"
                ;;
	        debian-12)
                SHORT="deb12"
                ;;
        	ubuntu-2004-lts)
                SHORT="ubt20"
                ;;
	        ubuntu-2204-lts)
                SHORT="ubt220"
                ;;
	esac

	if [ -z "$SHORT" ]; then
		SHORT="$OS"
	else
		PKGNAME=octez-${SHORT}-unoff
	fi


	NAME=bd-${seed}-${OS}-${BRANCH}
	echo "===> ${NAME}"

	IMAGE=`./parse_images.pl ${OS}`
	TARGETDIR=${BUCKET}/${SHORT}
	
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
		echo "=> Starting build"
		FAIL=3
		while [ $FAIL -gt 0 ]; do
			gcloud -q compute scp _buildscript.sh ${NAME}:buildscript.sh --zone=${ZONE} \
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
				--command="nohup sh ./buildscript.sh ${TARGETDIR} ${BRANCH} ${PKGNAME} > buildlog.log 2>&1 &" \
				>> ${LOCALLOG} 2>&1
			echo "gcloud -q compute instances delete ${NAME} \
		        --zone=${ZONE} --delete-disks=all --project=${PROJECT}" >> ${CLEANUPSH}
		fi
	fi

done

echo "rm -f ${CLEANUPSH}" >> ${CLEANUPSH}

while [ "`echo ${VMLIST} | tr -d ' '`" != "" ]; do

	echo "====> Status at `date`"

	NEWVMLIST=""
	
	for NAME in ${VMLIST}; do
	
		ZONE=${X86ZONE}
		echo ${NAME} | grep 'arm64' >/dev/null 2>&1
	
		if [ "$?" = "0" ]; then
			ZONE=${ARMZONE}
		fi
		
		printf "${NAME}\t"
		# Poll for success
		rm -f status
		state="NONE"
		gcloud -q compute scp ${NAME}:/tmp/status . --zone=${ZONE} --project=${PROJECT} >> ${LOCALLOG} 2>&1
		if [ -f "status" ]; then
			state=`cat status`
		fi

		# Statuses
		#

		if [ "$state" = "FINISHED" ]; then
			gcloud -q compute instances delete ${NAME} \
			        --zone=${ZONE} --delete-disks=all \
				--project=${PROJECT} >> ${LOCALLOG} 2>&1
			echo "FINISHED"
		else
			echo "$state"
			NEWVMLIST="${NEWVMLIST} ${NAME}"
		fi

	done

	if [ "${NEWVMLIST}" != "" ]; then
		sleep ${STATUSSLEEP}
	fi
	VMLIST="${NEWVMLIST}"
done
rm -f ${CLEANUPSH}


