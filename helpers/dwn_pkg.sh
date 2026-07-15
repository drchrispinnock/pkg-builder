#!/bin/sh
#

# Downloads
#
root="incoming"
prod21="gs://pkgbeta-tzinit-org/incoming/"

# --delete-unmatched-destination-objects

mkdir -p $root

echo "===> Syncing from $prod21"
(cd $root && \
	gcloud storage rsync -r $prod21 . )
