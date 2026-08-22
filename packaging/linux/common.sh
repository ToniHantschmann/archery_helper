# Gemeinsame Werte der beiden Linux-Paketskripte. Wird per `source` eingebunden,
# ist selbst nicht ausführbar.

set -euo pipefail

PACKAGING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$PACKAGING_DIR/../.." && pwd)"

APP_ID="io.github.tonihantschmann.bogenampel"
# Der Binärname aus linux/CMakeLists.txt — daran hängen die Pfade im Bundle.
BINARY_NAME="archery_helper"
# Der Paketname; Debian-Konvention ist Bindestrich statt Unterstrich.
PACKAGE_NAME="archery-helper"
DISPLAY_NAME="Archery Helper"
MAINTAINER="Toni Hantschmann <antonhantschmann@yahoo.de>"
HOMEPAGE="https://github.com/ToniHantschmann/archery_helper"

DESKTOP_FILE="$PACKAGING_DIR/$APP_ID.desktop"
ICON_FILE="$PACKAGING_DIR/icon.png"

BUNDLE_DIR="${BUNDLE_DIR:-$REPO_ROOT/build/linux/x64/release/bundle}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/dist}"

# pubspec trägt "1.0.0+1": vor dem Plus die Version, dahinter der Build-Zähler,
# den nur Windows braucht. Für Linux-Pakete zählt nur der vordere Teil.
read_version() {
  local line
  line="$(grep -m1 '^version:' "$REPO_ROOT/pubspec.yaml")"
  line="${line#version:}"
  line="${line// /}"
  echo "${line%%+*}"
}

VERSION="${VERSION:-$(read_version)}"

require_bundle() {
  if [[ ! -x "$BUNDLE_DIR/$BINARY_NAME" ]]; then
    echo "Kein Release-Bundle unter $BUNDLE_DIR." >&2
    echo "Erst 'flutter build linux --release' laufen lassen." >&2
    exit 1
  fi
}
