#!/bin/bash


mapreposbycodename=0
aptrepos="./repos"
incoming="./incoming"
root="release"
maproot=""
grepos="gs://apt-tzinit-org"
tidy=0

targets="debian-13"
[ -f "platforms" ] && targets=`cat platforms`

declare -A CODENAMES
CODENAMES["debian-13"]="trixie"
CODENAMES["debian-12"]="bookworm"
CODENAMES["ubuntu-2404"]="noble"
CODENAMES["ubuntu-2604"]="resolute"

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
        --map-repos-by-codename)
            mapreposbycodename="1" ;;
        --no-map-repos-by-codename)
            mapreposbycodename="0" ;;
        --tidy)
            tidy=1 ;;
        --no-tidy)
            tidy=0 ;;
        --root)
            root="$2"; shift ;;
        -*) echo "WARN: unknown option $1" >&2; ;;
    esac
    shift
done

# Multiple repos handling for DEVEL, RC, etc
#
subdir="$aptrepos"
case $root in
    release)
        subdir="$aptrepos"
        maproot=""
        ;;
    dev|devel|DEVEL)
        subdir="$aptrepos/DEVEL"
        maproot="DEVEL"
        ;;
    blstportable|BLSTPORTABLE)
        subdir="$aptrepos/BLSTPORTABLE"
        maproot="BLSTPORTABLE"
        ;;
    rc|RC)
        subdir="$aptrepos/RC"
        maproot="RC"
        ;;
    *)
        echo "Root must be release, dev or rc" && exit 2
        ;;
esac

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

    if [ "$mapreposbycodename" = "0" ]; then
        mkdir -p $subdir/$os/conf
            if [ ! -f apt/$os/distributions ]; then
                echo "No config for $os"
                continue
            fi

        cp apt/$os/distributions $subdir/$os/conf
        cp apt/$os/options $subdir/$os/conf
    fi

    for targ in $targets; do


        baseos=$(echo $targ | awk -F'-' '{print $1 "-" $2}')
        codename=${CODENAMES[${baseos}]}
        _code=""
        if [ "$mapreposbycodename" = "1" ]; then
            _code="$codename"
            mkdir -p $subdir/$os/$_code/conf
            if [ ! -f apt/$os/$_code/distributions ]; then
                echo "No config for $os/$_code"
                continue
            fi

            cp apt/$os/distributions $subdir/$os/$_code/conf
            cp apt/$os/options $subdir/$os/$_code/conf
        fi

        resolve=$(echo $targ | awk -F'-' '{print $1}')

        if [ "$resolve" = "$os" ]; then
            echo "===> $targ ($root - target $subdir/$os/$_code)"
            reprepro -b $subdir/$os/$_code includedeb $codename $incoming/$maproot/$targ/*.deb
            reprepro -b $subdir/$os/$_code export $codename
        fi

    done

    echo "Syncing $aptrespos to $grepos"
    gcloud storage rsync -r $gcliops $aptrepos/ $grepos

done
