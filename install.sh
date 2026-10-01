#!/bin/sh
# Installs Nuée from its latest release, the way this distribution expects:
#   Debian, Ubuntu and their family: the .deb, through apt
#   Fedora, RHEL and their family: the .rpm, through dnf
#   openSUSE: the .rpm, through zypper
#   Arch and its family: nuee-bin from the AUR, through yay or paru, otherwise makepkg
#   anything else: the AppImage, in ~/.local/bin
# Usage: curl -fsSL https://aco-hub.github.io/nuee-releases/install.sh | sh
set -eu

# Nuée's builds, published apart from its code, under names that stay the same from one release to
# the next.
releases="https://aco-hub.github.io/nuee-releases"

fail() {
  echo "nuee install: $1" >&2
  exit 1
}

case "$(uname -m)" in
  x86_64 | amd64) deb_architecture="amd64"; rpm_architecture="x86_64"; appimage_architecture="amd64" ;;
  aarch64 | arm64) deb_architecture="arm64"; rpm_architecture="aarch64"; appimage_architecture="aarch64" ;;
  *) fail "this processor ($(uname -m)) is not supported: Nuée is built for x86-64 and arm64" ;;
esac

download() {
  downloaded="$(mktemp -d)/$1"
  echo "downloading $1" >&2
  curl -fL --progress-bar -o "$downloaded" "$releases/$1" || fail "the latest release has no $1"
  echo "$downloaded"
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

distribution_family=""
if [ -r /etc/os-release ]; then
  . /etc/os-release
  distribution_family="${ID:-} ${ID_LIKE:-}"
fi

install_appimage() {
  appimage="$(download "Nuee-$appimage_architecture.AppImage")"
  mkdir -p "$HOME/.local/bin"
  mv "$appimage" "$HOME/.local/bin/Nuee.AppImage"
  chmod +x "$HOME/.local/bin/Nuee.AppImage"
  "$HOME/.local/bin/Nuee.AppImage" >/dev/null 2>&1 &
  echo "Nuée is in ~/.local/bin/Nuee.AppImage and opens now; it sets itself up to start with your session."
  exit 0
}

case " $distribution_family " in
  *" debian "* | *" ubuntu "*)
    package="$(download "Nuee-$deb_architecture.deb")"
    as_root apt-get install -y "$package"
    ;;
  *" fedora "* | *" rhel "* | *" centos "*)
    package="$(download "Nuee-$rpm_architecture.rpm")"
    as_root dnf install -y "$package"
    ;;
  *" suse "* | *" opensuse "*)
    package="$(download "Nuee-$rpm_architecture.rpm")"
    as_root zypper --non-interactive install --allow-unsigned-rpm "$package"
    ;;
  *" arch "*)
    # The AUR package once published, otherwise the AppImage.
    if command -v yay >/dev/null 2>&1 && yay -S --noconfirm nuee-bin; then
      :
    elif command -v paru >/dev/null 2>&1 && paru -S --noconfirm nuee-bin; then
      :
    else
      install_appimage
    fi
    ;;
  *)
    install_appimage
    ;;
esac

echo "Nuée is installed: open \"Nuée\" from your applications menu."
