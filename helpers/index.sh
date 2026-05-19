#!/bin/sh

# New
TARGETS="$TARGETS debian-12 debian-12-arm64 ubuntu-2204-lts rocky-linux-9 macos"
[ -f "platforms" ] && TARGETS=$(cat platforms)
TARGETS="$TARGETS macos"

cd Sources/pkgbeta-tzinit-org
cp ../../web/index.html .


echo "===> Building index"
for i in ${TARGETS}; do
	echo "==> $i"
	mkdir -p $i/dev
	mkdir -p testing/$i/dev
	(cd $i && mks3idx > index.html)
	(cd $i/dev && mks3idx > index.html)
done

