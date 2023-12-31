#!/bin/sh

cd Sources/pkgbeta-tzinit-org
cp ../../index.html .

# Legacy
#TARGETS="ubt220 deb11 deb12 ubt20"
# New
TARGETS="$TARGETS debian-11 debian-12 debian-12-arm64 ubuntu-2004-lts ubuntu-2204-lts rpi amazon-2023"

if [ ! -z "$1" ]; then

	echo "===> Building index for $1"

	for i in ${TARGETS}; do
		mkdir -p $i/$1
		(cd $i/$1 && mks3idx > index.html)
	done
fi

echo "===> Building index"
for i in ${TARGETS}; do
	(cd $i && mks3idx > index.html)
done

