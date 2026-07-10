#!/bin/sh

# Debian/Ubuntu package build for Octez
#
# (c) Chris Pinnock 2022, 2023, 2026, Supplied under a MIT license.
# (c) Nomadic Labs 2023-2025
# see ../pkg-common/utils.sh for more detail

#set -eu XXX

# Defaults
#
packages=""
myroot=../pkg-builder/pkgscripts

dieonwarn=${dieonwarn:-1}
pkg_vers=""
pkg_rev="1"
pkg_name="octez"
pkg_realname="octez"
systemd_dir="/lib/systemd/system"
defaults_dir="/etc/default"

eval `opam env`
[ "$?" != "0" ] && echo "Cannot eval opam environment" >&2 && exit 1

while [ $# -gt 0 ]; do
    case $1 in
        --pkgname)
            pkg_name="$2"; shift; ;;
        --package|--packages)
            packages="$2"; shift; ;;
        --dieonwarn)
            dieonwarn="1"; ;;
        --no-dieonwarn)
            dieonwarn="0"; ;;
        --override-version)
            pkg_vers="$2"; shift; ;;
        --revision)
            pkg_rev="$2"; shift; ;;
        --myroot)
            myroot="$2"; shift; ;;
        -*) echo "Unknown option $1" && exit 1 ;;
    esac
    shift
done

myhome=${myroot}/dpkg
common=${myroot}/pkg-common

export TIMESTAMP="${TIMESTAMP-$(date +'%Y%m%d%H%M')}"

#shellcheck disable=SC1091
. ${common}/utils.sh

if [ -z "$packages" ]; then
    for control_file in "$myhome"/*control.in; do
        pg=$(basename "$control_file" | sed -e 's/-control.in$//g')
        packages="$packages $pg"
    done
fi

warnings
if [ -z "$pkg_vers" ]; then
    pkg_vers=$(getOctezVersion)
    [ "$?" != "0" ] && exit 1
fi
staging_root=_dpkgstage

# Checking prerequisites
#
if ! which dpkg-deb > /dev/null 2>&1; then
  echo "Needs to run on a system with dpkg-deb in path" >&2
  exit 2
fi

# Get the local architecture
#
eval "$(dpkg-architecture)"
dpkg_arch=$DEB_BUILD_ARCH

# For each control file in the directory, build a package
#
for pg in $packages; do
  control_file="$myhome/${pg}-control.in"
  _pkgv=${pkg_vers}

  # EVM node and others don't use the parent version number
  #
  if [ -f "${common}/${pg}.vmeth" ]; then
	_pkgv="$(sh ${common}/${pg}.vmeth)"
  fi

  echo "===> Building package $pg v$_pkgv rev $pkg_rev"

  # Derivative variables
  #
  dpkg_name=${pkg_name}-${pg}
  init_name=${pkg_realname}-${pg}
  dpkg_vers=$(echo "${_pkgv}" | tr '~' '-')
  dpkg_dir="${dpkg_name}_${dpkg_vers}-${pkg_rev}_${dpkg_arch}"
  dpkg_fullname="${dpkg_dir}.deb"

  binaries=$(fixBinaryList "${common}/${pg}-binaries")

  if [ -f "$dpkg_fullname" ]; then
    echo "built already - skipping"
    continue
  fi

  # Populate the staging directory with control scripts
  # binaries and configuration as appropriate
  #
  staging_dir="$staging_root/$dpkg_dir"


  rm -rf "${staging_dir}"
  mkdir -p "${staging_dir}/DEBIAN"

  if [ -n "$binaries" ]; then
    echo "=> Populating directory with binaries"
    mkdir -p "${staging_dir}/usr/bin"
    for bin in ${binaries}; do
      if [ -f "${bin}" ]; then
        echo "Installing ${bin}"
        install -s -t "${staging_dir}/usr/bin" "${bin}"
      else
        echo "WARN: ${bin} not found"
        [ "$dieonwarn" = "1" ] && exit 1
      fi
    done

    # Shared libraries
    #
    mkdir -p "${staging_dir}/debian"
    touch "${staging_dir}/debian/control"

    echo "=> Finding shared library dependencies"

    deps=$(cd "${staging_dir}" && dpkg-shlibdeps -O usr/bin/* | sed -e 's/^shlibs://g' -e 's/^Depends=//g')
    rm "${staging_dir}/debian/control"
    rmdir "${staging_dir}/debian"
  fi

  # Manual pages XXX

  # Edit the control file to contain real values
  #
  sed -e "s/@ARCH@/${dpkg_arch}/g" -e "s/@VERSION@/$_pkgv/g" \
    -e "s/@MAINT@/${OCTEZ_PKGMAINTAINER}/g" \
    -e "s/@PKG@/${dpkg_name}/g" \
    -e "s/@DPKG@/${pkg_name}/g" \
    -e "s/@DEPENDS@/${deps}/g" < "$control_file" \
    > "${staging_dir}/DEBIAN/control"

  # Install hook scripts (not used initially)
  #
  for src in postinst preinst postrm prerm; do
    if [ -f "${myhome}/${pg}.$src" ]; then
      cp "${myhome}/${pg}.$src" "${staging_dir}/DEBIAN/$src"
      chmod +x "${staging_dir}/DEBIAN/$src"
    fi
  done

    # Systemctl conversation
    #
    if [ -f "${common}/${pg}.service" ]; then
        mkdir -p ${staging_dir}/${systemd_dir}
        cp ${common}/${pg}.service ${staging_dir}/${systemd_dir}/octez-${pg}.service
        #
        if [ -f "${common}/${pg}.default" ]; then
            mkdir -p ${staging_dir}/${defaults_dir}
            cp ${common}/${pg}.default ${staging_dir}/${defaults_dir}/octez-${pg}
            echo "${defaults_dir}/octez-${pg}" >> "${staging_dir}/DEBIAN/conffiles"
        fi
    fi
    if [ "$pg" = "baker" ]; then
      cp ${common}/vdf.service ${staging_dir}/${systemd_dir}/octez-vdf.service
    fi

  # Zcash parameters need slightly different handling
  #
  if [ "$pg" = "zcash-params" ]; then
     zcashParams "${staging_dir}/usr/share/zcash-params"
  fi

# XXX
  if [ "$pg" = "dal-node" ]; then
    # call the install script to make available the
    # zcash parameters on the build host
    scripts/install_dal_trusted_setup.sh
    zcashParams "${staging_dir}/usr/share/dal-trusted-setup" \
      _opam/share/dal-trusted-setup
  fi

  # Build the package
  #
  echo "=> Constructing package ${dpkg_fullname}"
  dpkg-deb -v --build --root-owner-group "${staging_dir}"
  mv "${staging_root}/${dpkg_fullname}" .
done

echo "Cleanup staging directories"
rm -Rf "${staging_root}"
