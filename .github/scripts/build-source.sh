#!/usr/bin/env bash
# build-source.sh <tag> <build-rev> <suite> <arch> [lintian true|false]
#
# Compile quickshell from the Forgejo source tag inside debian:<suite> and
# wrap the install tree with dpkg-deb. This is the source-build pilot: unlike
# every other repo in the org, there is no upstream binary to repack.
#
# Runs in the matrix cell's native architecture (amd64 on ubuntu-latest,
# arm64 on ubuntu-24.04-arm); no emulation/cross-packaging.
set -euo pipefail

TAG="$1"; BREV="${2:-1}"; SUITE="$3"; ARCH="$4"; LINTIAN="${5:-true}"
VER="${TAG#v}"
DEB="quickshell_${VER}-${BREV}+${SUITE}_${ARCH}.deb"

docker run --rm -e LINTIAN="$LINTIAN" -v "$PWD:/out" -w /build "debian:$SUITE" bash -c '
set -euo pipefail
TAG="$1"; VER="$2"; BREV="$3"; SUITE="$4"; ARCH="$5"; DEB="$6"; LINTIAN="$7"
apt-get update -qq
# Dependency set derived from upstream BUILD.md + each find_package/pkg_check_modules
# in the tree (CLI11, XCB, VulkanHeaders, wayland-client, gbm/egl, glib,
# polkit-agent-1, polkit-gobject-1, libpipewire-0.3, pam, jemalloc). Crash
# handler is disabled, so cpptrace is not needed.
apt-get install -y -qq \
  build-essential cmake ninja-build pkg-config curl ca-certificates dpkg-dev lintian \
  qt6-base-dev qt6-base-private-dev qt6-declarative-dev \
  qt6-declarative-private-dev qt6-shadertools-dev qt6-svg-dev \
  qt6-wayland-dev qt6-wayland-private-dev \
  libdrm-dev libgbm-dev libegl-dev libglib2.0-dev \
  libcli11-dev libvulkan-dev libxcb1-dev \
  libwayland-dev libwayland-bin wayland-protocols \
  libpipewire-0.3-dev libpam0g-dev libpolkit-agent-1-dev libpolkit-gobject-1-dev \
  libjemalloc-dev spirv-tools >/dev/null
# wayland-protocols 1.44 (trixie) predates staging/ext-background-effect-v1,
# which the quickshell background_effect module requires unconditionally. The
# package is Architecture: all — pure protocol XML, consumed at build time —
# so overlaying forky copy is safe and side-effect-free for the produced
# binary. forky/sid already ship it.
if [ "$SUITE" = "trixie" ]; then
  echo "deb http://deb.debian.org/debian forky main" > /etc/apt/sources.list.d/forky-wp.list
  apt-get update -qq
  apt-get install -y -qq -t forky wayland-protocols >/dev/null
fi
curl -fsSL "https://git.outfoxxed.me/quickshell/quickshell/archive/${TAG}.tar.gz" -o src.tar.gz
mkdir -p src build stage/DEBIAN debian
tar xzf src.tar.gz -C src --strip-components=1
# Debian layout: prefix /usr, and QML modules under the multiarch Qt QML dir
# (INSTALL_QMLDIR is empty by default, and quickshell then SILENTLY installs no
# QML modules at all — see cmake/install-qml-module.cmake).
MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
QMLDIR="/usr/lib/${MULTIARCH}/qt6/qml"
cmake -S src -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCRASH_HANDLER=OFF \
  -DCMAKE_INSTALL_PREFIX=/usr -DINSTALL_QMLDIR="${QMLDIR}"
cmake --build build
DESTDIR=/build/stage cmake --install build
# debian/{changelog,control} give dpkg-shlibdeps the context it needs to emit
# a Depends line (shlibs:Depends) from the shipped ELF files.
cat > debian/changelog <<EOF
quickshell (${VER}-${BREV}+${SUITE}) unstable; urgency=medium

  * Source-build pilot (Forgejo tag ${TAG}); see BUILD-SOURCE.md.

 -- latest-debs <latest-debs@users.noreply.github.com>  $(date -R)
EOF
cat > debian/control <<EOF
Source: quickshell
Section: x11
Priority: optional
Maintainer: latest-debs <latest-debs@users.noreply.github.com>
Standards-Version: 4.7.0

Package: quickshell
Architecture: any
Depends: \${shlibs:Depends}
Description: Flexible QtQuick based desktop shell toolkit.
 Source-built pilot (Forgejo tag ${TAG}); see BUILD-SOURCE.md.
EOF
# Runtime Depends from every ELF we ship (the main binary + the QML plugin
# .so files), so the package pulls its Qt/pipewire/polkit libs.
mapfile -t elfs < <(find stage/usr -type f \( -name quickshell -o -name '*.so' \))
depends="$(dpkg-shlibdeps -O "${elfs[@]}" 2>/dev/null | sed -n "s/^shlibs:Depends=//p" || true)"
[ -n "$depends" ] || depends="libc6"
cat > stage/DEBIAN/control <<EOF
Package: quickshell
Version: ${VER}-${BREV}+${SUITE}
Section: x11
Priority: optional
Architecture: ${ARCH}
Depends: ${depends}
Maintainer: latest-debs <latest-debs@users.noreply.github.com>
Description: Flexible QtQuick based desktop shell toolkit.
 Source-built pilot (Forgejo tag ${TAG}); see BUILD-SOURCE.md.
EOF
dpkg-deb -b stage "/out/${DEB}"
if [ "$LINTIAN" = "true" ]; then
  lintian --no-tag-display-limit "/out/${DEB}" || \
    echo "::warning::lintian reported findings for ${DEB} (non-fatal in the source-build pilot)"
fi
' _ "$TAG" "$VER" "$BREV" "$SUITE" "$ARCH" "$DEB" "$LINTIAN"

echo "built $DEB"
