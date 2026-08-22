#!/usr/bin/env bash
#
# Baut die Linux-Pakete in einem ubuntu:22.04-Container — derselbe Ablauf wie
# im Job `build-linux` in .github/workflows/release.yml, nur ohne die
# Push-Warten-Schleife. Braucht Podman oder Docker.
#
#   packaging/linux/build_in_container.sh
#
# Ergebnis: dist/archery-helper_<version>_amd64.deb
#           dist/Archery_Helper-<version>-x86_64.AppImage
#
# Warum ein Container und nicht der Rechner hier: ein auf NixOS gebautes Binary
# hat ELF-Interpreter und Bibliothekspfade fest in /nix/store stehen und läuft
# auf keinem anderen Linux. Portable Artefakte müssen auf einem Ubuntu
# entstehen.
#
# Das Quellverzeichnis wird nur lesend eingehängt und im Container kopiert:
# so kann der Build weder das build/-Verzeichnis dieses Rechners überschreiben
# noch root-eigene Dateien im Repo hinterlassen. Nur dist/ wird beschrieben.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.38.3}"
IMAGE="${IMAGE:-docker.io/library/ubuntu:22.04}"
# Der heruntergeladene SDK überlebt zwischen Läufen, sonst kostet jeder Versuch
# ein knappes Gigabyte.
CACHE_DIR="${CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/archery-helper-container-build}"

if command -v podman >/dev/null 2>&1; then
  ENGINE=podman
elif command -v docker >/dev/null 2>&1; then
  ENGINE=docker
else
  echo "Weder podman noch docker gefunden." >&2
  exit 1
fi

mkdir -p "$CACHE_DIR" "$REPO_ROOT/dist"

# :z setzt das SELinux-Label um; auf Systemen ohne SELinux ist es wirkungslos.
MOUNT_OPTS=""
[[ $ENGINE == podman ]] && MOUNT_OPTS=",z"

echo "Engine: $ENGINE — Flutter $FLUTTER_VERSION — Cache: $CACHE_DIR"

"$ENGINE" run --rm -i \
  -v "$REPO_ROOT:/src:ro$MOUNT_OPTS" \
  -v "$REPO_ROOT/dist:/out:rw$MOUNT_OPTS" \
  -v "$CACHE_DIR:/cache:rw$MOUNT_OPTS" \
  -e "FLUTTER_VERSION=$FLUTTER_VERSION" \
  -e "HOST_UID=$(id -u)" \
  -e "HOST_GID=$(id -g)" \
  "$IMAGE" bash -s <<'CONTAINER'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# git, curl, unzip und xz-utils bringt das nackte Ubuntu-Image nicht mit — auf
# dem GitHub-Runner sind sie vorinstalliert, hier nicht.
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  ca-certificates curl git unzip xz-utils file \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev

SDK="/cache/flutter-$FLUTTER_VERSION"
if [[ ! -x "$SDK/bin/flutter" ]]; then
  echo "== Flutter $FLUTTER_VERSION herunterladen"
  TARBALL="/cache/flutter_linux_$FLUTTER_VERSION-stable.tar.xz"
  curl -fL --retry 3 -o "$TARBALL" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  rm -rf "$SDK"
  mkdir -p "$SDK"
  tar -xJf "$TARBALL" -C "$SDK" --strip-components=1
  rm -f "$TARBALL"
fi
export PATH="$SDK/bin:$PATH"
# Der SDK liegt außerhalb des Container-Nutzers; ohne das hält git ihn für
# fremdes Eigentum und flutter kommt nicht an seine Version.
git config --global --add safe.directory '*'

# Das Repo wird kopiert statt beschrieben: /src ist read-only eingehängt.
cp -a /src /work
rm -rf /work/build /work/dist
cd /work

echo "== flutter pub get"
flutter pub get
echo "== flutter analyze"
flutter analyze
echo "== flutter test"
flutter test
echo "== flutter build linux --release"
flutter build linux --release

echo "== Pakete schnüren"
OUTPUT_DIR=/out packaging/linux/make_deb.sh
OUTPUT_DIR=/out packaging/linux/make_appimage.sh

# Bei rootless Podman erledigt das der User-Namespace schon; unter Docker
# gehörten die Dateien sonst root.
chown -R "$HOST_UID:$HOST_GID" /out 2>/dev/null || true
CONTAINER

echo
echo "Fertig:"
ls -lh "$REPO_ROOT/dist"
