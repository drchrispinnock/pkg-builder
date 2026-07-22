#!/bin/sh

# RPM package build for Octez
#
# (c) Chris Pinnock 2022, 2023, 2026, Supplied under a MIT license.
# (c) Nomadic Labs 2023-2025
# see ../pkg-common/utils.sh for more detail

#set -eu

# Defaults
#
packages=""
myroot=../pkg-builder/pkgscripts

# Setup
#



dieonwarn=${dieonwarn:-1}
override_pkg_vers=""
pkg_rev="1"
pkg_name="octez"
pkg_realname="octez"
systemd_dir="/usr/lib/systemd/system"
defaults_dir="/etc/default"
force=0
devmode=0

eval `opam env`
[ "$?" != "0" ] && echo "Cannot eval opam environment" >&2 && exit 1

while [ $# -gt 0 ]; do
    case $1 in
        --devmode)
            devmode=1 ;;
        --force)
            force=1; ;;
        --pkgname)
            pkg_name="$2"; shift; ;;
        --package|--packages)
            packages="$2"; shift; ;;
        --dieonwarn)
            dieonwarn="1"; ;;
        --no-dieonwarn)
            dieonwarn="0"; ;;
        --override-version)
            override_pkg_vers="$2"; shift; ;;
        --revision)
            pkg_rev="$2"; shift; ;;
        --myroot)
            myroot="$2"; shift; ;;
        -*) echo "Unknown option $1" && exit 1 ;;
        *) echo "What is this? $1" && exit 1 ;;
    esac
    shift
done

myhome=$myroot/rpm
common=$myroot/pkg-common

export TIMESTAMP="${TIMESTAMP-$(date +'%Y%m%d%H%M')}"

#shellcheck disable=SC1091
. ${common}/utils.sh

if [ -z "$packages" ]; then
    for specfile in "$myhome"/*spec.in; do
        pg=$(basename "$specfile" | sed -e 's/-spec.in$//g')
        packages="$packages $pg"
    done
fi

warnings


### RPM specifc

# Checking prerequisites
#
if ! which rpmbuild > /dev/null 2>&1; then
  echo "Needs to run on a system with rpmbuild in path" >&2
  echo "yum install rpmdevtools"
  exit 2
fi

rpmbuild_root=$HOME/rpmbuild # Seems to be standard
for d in BUILD BUILDROOT RPMS SOURCES SPECS SRPMS; do
  mkdir -p "$rpmbuild_root/$d"
done
spec_dir="${rpmbuild_root}/SPECS"
rpm_dir="${rpmbuild_root}/RPMS"
src_dir="${rpmbuild_root}/SOURCES"
#staging_dir="${rpmbuild_root}/BUILDROOT"
staging_dir="_rpmbuild"

# Get the local architecture
#
rpm_arch=$(uname -m)

# For each spec file in the directory, build a package
#


for pg in $packages; do
    specfile="$myhome/${pg}-spec.in"
    # Derivative variables
    #
    pkg_vers="$override_pkg_vers"
    [ -z "$override_pkg_vers" ] && pkg_vers=$(getOctezVersion $common $pg)
    echo "===> Building package $pg v$pkg_vers rev $pkg_rev"
    rpm_name=${pkg_name}-${pg}
    init_name=${pkg_realname}-${pg}
    rpm_vers=$(echo "${pkg_vers}" | tr -d '~' | tr '-' '_')
    rpm_fullname="${rpm_name}-${rpm_vers}-${pkg_rev}.${rpm_arch}.rpm"

    binaries=$(fixBinaryList "${common}/${pg}-binaries")

    if [ -f "$rpm_fullname" ]; then
        echo "built already - skipping"
        continue
    fi

    tar_name=${rpm_name}-${rpm_vers}
    # Populate the staging directory with control scripts
    # binaries and configuration as appropriate
    #
    build_dir="${staging_dir}/${tar_name}"

    rm -rf "${staging_dir}"
    mkdir -p "${build_dir}"

    if [ -n "$binaries" ]; then
        echo "=> Populating directory with binaries"
        mkdir -p "${build_dir}/usr/bin"
        for bin in ${binaries}; do
        if [ -f "${bin}" ]; then
            echo "${bin}"
            install -s -t "${build_dir}/usr/bin" "${bin}"
        else
            echo "WARN: ${bin} not found"
            [ "$dieonwarn" = "1" ] && exit 1
        fi
        done
    fi

    # Systemctl conversation
  #
  if [ -f "${common}/${pg}.service" ]; then
      mkdir -p ${build_dir}/${systemd_dir}
      cp ${common}/${pg}.service ${build_dir}/${systemd_dir}/octez-${pg}.service
      #
      if [ -f "${common}/${pg}.default" ]; then
          mkdir -p ${build_dir}/${defaults_dir}
          cp ${common}/${pg}.default ${build_dir}/${defaults_dir}/octez-${pg}
      fi
  fi

  if [ "$pg" = "baker" ]; then
    cp ${common}/vdf.service ${build_dir}/${systemd_dir}/octez-vdf.service
  fi

  # Zcash parameters need slightly different handling
  #
  if [ "$pg" = "zcash-params" ]; then
      zcashParams "${build_dir}/usr/share/zcash-params"
  fi

  # XXX
    if [ "$pg" = "dal-node" ]; then
      # call the install script to make available the
      # zcash parameters on the build host
      scripts/install_dal_trusted_setup.sh
      zcashParams "${staging_dir}/usr/share/dal-trusted-setup" \
        _opam/share/dal-trusted-setup
    fi

  # Edit the spec file to contain real values
  #
  spec_file="${pg}.spec"
  sed -e "s/@ARCH@/${rpm_arch}/g" -e "s/@VERSION@/$rpm_vers/g" \
    -e "s/@REVISION@/${pkg_rev}/g" \
    -e "s/@MAINT@/${OCTEZ_PKGMAINTAINER}/g" \
    -e "s/@PKG@/${rpm_name}/g" \
    -e "s/@DPKG@/${pkg_name}/g" \
    -e "s/@FAKESRC@/${tar_name}.tar.gz/g" < "$specfile" \
    > "${spec_dir}/${spec_file}"

  # Stage the package
  #
  echo "=> Staging ${pg}"
  (cd ${staging_dir} && tar zcf "${src_dir}/${tar_name}.tar.gz" "${tar_name}")

  # Build the package
  #
  # Using %global debug_package %{nil} in an RPM spec file disables the
  # generation of debuginfo packages. This directive tells the RPM build process
  # not to create a debuginfo package for the RPM being built.
  echo "=> Constructing RPM package ${rpm_fullname}"
  _flags="--quiet"
  rpmbuild -bb -D 'debug_package %{nil}' ${_flags} "${spec_dir}/${spec_file}"
  if [ -f "${rpm_dir}/${rpm_arch}/${rpm_fullname}" ]; then
    mv "${rpm_dir}/${rpm_arch}/${rpm_fullname}" .
  fi
done

echo "Cleanup staging directories"
rm -Rf "${staging_dir}"
