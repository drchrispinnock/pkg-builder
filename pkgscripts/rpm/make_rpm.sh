#!/bin/sh

# RPM package build for Octez
#
# (c) Chris Pinnock 2023, Supplied under a MIT license.
# see ../pkg-common/utils.sh for more detail

set -eu

# Setup
#
myhome=$HOME/pkgscripts/rpm
common=$HOME/pkgscripts/pkg-common
dieonwarn=${dieonwarn:-0}

#shellcheck disable=SC1091
. ${common}/utils.sh
protocols=${protocols:?protocols not specified}

warnings
pkg_vers=$(getOctezVersion)

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
staging_dir="_rpmbuild"

# Get the local architecture
#
rpm_arch=$(uname -m)

# For each spec file in the directory, build a package
#
for specfile in "$myhome"/*spec.in; do
  pg=$(basename "$specfile" | sed -e 's/-spec.in$//g')
  echo "===> Building package $pg v$pkg_vers rev $OCTEZ_PKGREV"

  # Derivative variables
  #
  rpm_name=${OCTEZ_PKGNAME}-${pg}
  init_name=${OCTEZ_REALNAME}-${pg}
  rpm_vers=$(echo "${pkg_vers}" | tr -d '~' | tr '-' '_')
  rpm_fullname="${rpm_name}-${rpm_vers}-${OCTEZ_PKGREV}.${rpm_arch}.rpm"

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

  # init.d scripts
  #
  initdScripts "${common}/${pg}.initd.in" "${init_name}" "${build_dir}"
  if [ "$pg" = "baker" ]; then
    initdScripts "${common}/vdf.initd.in" octez-vdf \
      "${build_dir}"
  fi

  # Configuration files
  #
  if [ -f "${common}/${pg}.conf" ]; then
    echo "=> Config files"
    mkdir -p "${build_dir}/etc/octez"
    expand_PROTOCOL "${common}/${pg}.conf" > "${build_dir}/etc/octez/${pg}.conf"
  fi

  # Zcash parameters must ship with the node
  #
  zcashParams "${common}/${pg}-zcash" "${build_dir}/usr/share/zcash-params"

  # Edit the spec file to contain real values
  #
  spec_file="${pg}.spec"
  sed -e "s/@ARCH@/${rpm_arch}/g" -e "s/@VERSION@/$rpm_vers/g" \
    -e "s/@REVISION@/${OCTEZ_PKGREV}/g" \
    -e "s/@MAINT@/${OCTEZ_PKGMAINTAINER}/g" \
    -e "s/@PKG@/${rpm_name}/g" \
    -e "s/@DPKG@/${OCTEZ_PKGNAME}/g" \
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
