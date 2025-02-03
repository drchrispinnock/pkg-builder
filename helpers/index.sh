#!/bin/sh

cd Sources/pkgbeta-tzinit-org
cp ../../web/index.html .

# New
TARGETS="$TARGETS debian-12 debian-12-arm64 ubuntu-2204-lts rocky-linux-9"

if [ ! -z "$1" ]; then

	echo "===> Building index for $1"

	for i in ${TARGETS}; do
		mkdir -p $i/$1
		mkdir -p $i/$1/dev
		(cd $i/$1 && mks3idx > index.html)
		(cd $i/$1/dev && mks3idx > index.html)
	done
fi

echo "===> Building index"
for i in ${TARGETS}; do
	(cd $i && mks3idx > index.html)
	(cd $i/dev && mks3idx > index.html)
done

