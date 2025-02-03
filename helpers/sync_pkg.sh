#!/bin/sh
#

# Downloads
#
root="Sources"
site2="$root/pkgbeta-tzinit-org"
prod21="gs://pkgbeta-tzinit-org/"

mkdir -p $site2

SYNC=down
[ ! -z "$1" ] && SYNC="$1"

if [ "$SYNC" = "down" ]; then
	SYNC=down
else
	if [ ! -f $site2/index.html ]; then
		echo "Sync down first, otherwise you will lose the lot!"
		exit 2
	fi
fi

if [ $SYNC = "up" ]; then
	echo "===> Syncing to $prod21"
	(cd $site2 && \
		gsutil -o "GSUtil:parallel_process_count=1"  -m rsync -d -r . $prod21)
else
	echo "===> Syncing from $prod21"
	(cd $site2 && \
		gsutil -o "GSUtil:parallel_process_count=1"  -m rsync -d -r $prod21 . )
fi

