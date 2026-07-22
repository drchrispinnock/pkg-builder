#!/bin/sh
#

# Downloads
#
root="incoming"
prod21="gs://pkgbeta-tzinit-org/incoming/"

# --delete-unmatched-destination-objects

[ ! -f build_pkg.sh ] && echo "Run me a top level" && exit 2

mkdir -p $root

echo "===> Syncing from $prod21"
(cd $root && \
	gcloud storage rsync --delete-unmatched-destination-objects -r . $prod21 )
