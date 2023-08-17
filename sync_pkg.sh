#!/bin/sh
#

# Downloads
#
root="Sources"
site2="$root/pkgbeta-tzinit-org"
prod21="gs://pkgbeta-tzinit-org/"

SYNC=up
if [ "$1" = "down" ]; then
	SYNC=down
fi

if [ `hostname -s` != "sylow" ]; then
	echo "Only run on sylow!"
	exit 1
fi

if [ $SYNC = "up" ]; then
	echo "===> Syncing to $prod21"
	(cd $site2 && \
		gsutil -o "GSUtil:parallel_process_count=1"  -m rsync -d -r . $prod21)
else
	echo "===> Syncing from $prod21"
	(cd $site2 && \
		gsutil -o "GSUtil:parallel_process_count=1"  -m rsync -r $prod21 . )
fi

