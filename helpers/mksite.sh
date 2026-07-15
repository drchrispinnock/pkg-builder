#!/bin/sh

# Make a manual download site
downloadsite=website

# New
TARGETS="debian-12 debian-12-arm64"
[ -f "platforms" ] && TARGETS=$(cat platforms)
TARGETS="$TARGETS macos"

mkdir -p $downloadsite
cp web/index.html $downloadsite
mkdir -p $downloadsite/release
mkdir -p $downloadsite/DEVEL
mkdir -p $downloadsite/RC

for t in release DEVEL RC; do
    s=$t
    [ "$s" = "release" ] && s=""
    echo "=> $t"
    for target in ${TARGETS}; do
        echo "==> $target"

        if [ -d incoming/$s/$target ]; then
           mkdir -p $downloadsite/$t/$target
           cp -pR incoming/$s/$target/*.deb $downloadsite/$t/$target
           for file in $downloadsite/$t/$target/*.deb; do
               gpg -u packages@tezos.foundation --sign --detach --armor $file
           done
           bash ./helpers/mks3idx $downloadsite/$t/$target > $downloadsite/$t/$target/index.html
        fi
    done
    bash ./helpers/mks3idx $downloadsite/$t > $downloadsite/$t/index.html
done

gcloud storage rsync -r $downloadsite/ gs://packages-tzinit-org/
