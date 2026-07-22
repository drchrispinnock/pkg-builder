#!/bin/sh

# Make a manual download site
downloadsite=website

# New
TARGETS="debian-12 debian-12-arm64"
[ -f "platforms" ] && TARGETS=$(cat platforms)
TARGETS="$TARGETS macos"

mkdir -p $downloadsite/keys
cp web/index.html $downloadsite
cp apt/keys/*.asc $downloadsite/keys

bash ./helpers/mks3idx $downloadsite/keys > $downloadsite/keys/index.html

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
           filelist=$(ls incoming/$s/$target/*.{deb,rpm} 2>/dev/null)
           cp -pR $filelist $downloadsite/$t/$target
           for file in $filelist; do
               rm -f "$file".asc
               gpg --quiet -u packages@tezos.foundation --sign --detach --armor $file
           done
           bash ./helpers/mks3idx $downloadsite/$t/$target > $downloadsite/$t/$target/index.html
        fi
    done
    bash ./helpers/mks3idx $downloadsite/$t > $downloadsite/$t/index.html
done

gcloud storage rsync --delete-unmatched-destination-objects -r $downloadsite/ gs://packages-tzinit-org/
