#!/bin/bash
# Build the Arch package from this git checkout (no GitHub download needed).
# It packs the current commit with "git archive" under the file name the PKGBUILD
# would download, so makepkg uses it as is.
#
#   packaging/build-local-pkg.sh            build only
#   packaging/build-local-pkg.sh --install  build, then "sudo pacman -U" it
set -euo pipefail
top=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$top/packaging/arch"
. <(grep -E '^(pkgname|_pkgbase|pkgver|pkgrel)=' PKGBUILD)
if [ -n "$(git status --porcelain -- "$top")" ]; then
  echo "note: uncommitted changes are NOT included (git archive packs HEAD)" >&2
fi
git -C "$top" archive --format=tar.gz --prefix="${_pkgbase}-${pkgver}/" -o "$PWD/${_pkgbase}-${pkgver}.tar.gz" HEAD
# --nodeps: the kernel module is only compiled on install (by DKMS), so dkms itself
# does not have to be installed just to make the package
makepkg -f --noconfirm --nodeps
pkg="${pkgname}-${pkgver}-${pkgrel}-x86_64.pkg.tar.zst"
ls -l "$pkg"
if [ "${1:-}" = "--install" ]; then
  sudo pacman -U --noconfirm "$pkg"
fi
