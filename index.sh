#!/bin/sh

cd Sources/pkgbeta-tzinit-org

if [ ! -z "$1" ]; then

	echo "===> Building index for $1"

	for i in aws23 rpi ubt220 deb11 deb12 ubt20; do
		mkdir -p $i/$1
		(cd $i/$1 && mks3idx > index.html)
	done
fi

echo "===> Building index"
for i in aws23 rpi ubt220 deb11 deb12 ubt20; do
	(cd $i && mks3idx > index.html)
done
