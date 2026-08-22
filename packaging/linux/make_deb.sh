#!/usr/bin/env bash
#
# Baut aus dem Flutter-Release-Bundle ein .deb für amd64.
#
#   flutter build linux --release
#   packaging/linux/make_deb.sh
#
# Ergebnis: dist/archery-helper_<version>_amd64.deb
# Überschreibbar per BUNDLE_DIR, OUTPUT_DIR, VERSION.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_bundle

DEB_FILE="$OUTPUT_DIR/${PACKAGE_NAME}_${VERSION}_amd64.deb"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

INSTALL_DIR="/opt/$BINARY_NAME"

mkdir -p "$STAGE/DEBIAN" \
         "$STAGE$INSTALL_DIR" \
         "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications" \
         "$STAGE/usr/share/icons/hicolor/256x256/apps"

# Das Bundle wandert unverändert nach /opt: die Anwendung sucht data/ und lib/
# relativ zum Binary (CMAKE_INSTALL_RPATH ist $ORIGIN/lib), also darf niemand
# die drei Teile auseinanderziehen.
cp -r "$BUNDLE_DIR/." "$STAGE$INSTALL_DIR/"
ln -s "$INSTALL_DIR/$BINARY_NAME" "$STAGE/usr/bin/$BINARY_NAME"

cp "$DESKTOP_FILE" "$STAGE/usr/share/applications/"
cp "$ICON_FILE" "$STAGE/usr/share/icons/hicolor/256x256/apps/$APP_ID.png"

# Depends: das ist der Teil, der auf dem Zielrechner über Start oder Fehlschlag
# entscheidet. Die drei GStreamer-Einträge braucht audioplayers; ohne
# plugins-good (wavparse und die Audio-Ausgabe) bleiben die Signaltöne stumm,
# und zwar lautlos — die App startet trotzdem.
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libglib2.0-0, libstdc++6, libgstreamer1.0-0, libgstreamer-plugins-base1.0-0, gstreamer1.0-plugins-good
Maintainer: $MAINTAINER
Homepage: $HOMEPAGE
Installed-Size: $(du -ks "$STAGE$INSTALL_DIR" | cut -f1)
Description: $DISPLAY_NAME - Schießzeit-Ampel für den Bogensport
 Tastaturbedienter Kiosk-Bildschirm für den Schießstand: Schießzeit-Ampel
 für das Training, WA-Qualifikationsrunde für den Wettkampf, von Hand
 geschaltete Ampel und ein Ruhebild mit großer Uhr.
EOF

find "$STAGE" -type d -exec chmod 755 {} +
find "$STAGE" -type f -exec chmod 644 {} +
chmod 755 "$STAGE$INSTALL_DIR/$BINARY_NAME"

mkdir -p "$OUTPUT_DIR"
# --root-owner-group, weil das Paket sonst die UID des Bauenden einträgt.
dpkg-deb --build --root-owner-group "$STAGE" "$DEB_FILE"

echo "→ $DEB_FILE"
