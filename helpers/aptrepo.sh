#!/bin/bash

aptrepos="./repos"
incoming="./incoming"
grepos="gs://apt-tzinit-org"
tidy=0

targets="debian-13"
[ -f "platforms" ] && targets=`cat platforms`

declare -A CODENAMES
CODENAMES["debian-13"]="trixie"
CODENAMES["debian-12"]="bookworm"

while [ $# -gt 0 ]; do
    case $1 in
        --aptrepos)
            aptrepos="$2"; shift; ;;
        --targets|--target|-T)
            targets="$2"; shift; ;;
        --incoming)
            incoming="$2"; shift ;;
        --gcloud)
            grepos="$2"; shift; ;;
        --tidy)
            tidy=1 ;;
        --no-tidy)
            tidy=0 ;;
        -*) echo "WARN: unknown option $1" >&2; ;;
    esac
    shift
done

gcliops=""
[ "$tidy" = "1" ] && gcliops="$gcliops --delete-unmatched-destination-objects"

which reprepro >/dev/null 2>&1
if [ "$?" != "0" ]; then
    echo "reprepro is not installed."
    exit 1
fi

mkdir -p $aptrepos/keys
cp apt/keys/*.asc $aptrepos/keys

for os in debian ubuntu; do
    echo "==> $os"
    mkdir -p $aptrepos/$os/conf
    if [ ! -f apt/$os/distributions ]; then
        echo "No config for $os"
        continue
    fi

    cp apt/$os/distributions $aptrepos/$os/conf
    cp apt/$os/options $aptrepos/$os/conf

    for targ in $targets; do

        baseos=$(echo $targ | awk -F'-' '{print $1 "-" $2}')
        codename=${CODENAMES[${baseos}]}
        resolve=$(echo $targ | awk -F'-' '{print $1}')

        if [ "$resolve" = "$os" ]; then
            echo "===> $targ"
            #ls -l $incoming/$targ
            reprepro -b $aptrepos/$os includedeb $codename $incoming/$targ/*.deb
        fi
        reprepro -b $aptrepos/$os export $codename

    done

    gcloud storage rsync -r $gcliops $aptrepos/ $grepos

done
