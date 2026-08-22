#!/usr/bin/env bash
#
# Baut aus dem Flutter-Release-Bundle ein AppImage für x86_64.
#
#   flutter build linux --release
#   packaging/linux/make_appimage.sh
#
# Ergebnis: dist/Archery_Helper-<version>-x86_64.AppImage
# Überschreibbar per BUNDLE_DIR, OUTPUT_DIR, VERSION, APPIMAGETOOL_URL.
#
# Das AppImage bringt Flutters lib/ mit, holt GTK und GStreamer aber weiterhin
# vom Wirtssystem. Das ist bei GTK-Anwendungen üblich und praktisch überall
# erfüllt; die Signaltöne brauchen dort gstreamer1.0-plugins-good.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_bundle

APPIMAGE_FILE="$OUTPUT_DIR/${DISPLAY_NAME// /_}-${VERSION}-x86_64.AppImage"
APPIMAGETOOL_URL="${APPIMAGETOOL_URL:-https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage}"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APPDIR="$STAGE/AppDir"

mkdir -p "$APPDIR/usr/bin" \
         "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps"

cp -r "$BUNDLE_DIR/." "$APPDIR/usr/bin/"

cp "$DESKTOP_FILE" "$APPDIR/usr/share/applications/$APP_ID.desktop"
cp "$ICON_FILE" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$APP_ID.png"

# appimagetool erwartet .desktop und Icon zusätzlich im Wurzelverzeichnis des
# AppDir, das Icon außerdem als .DirIcon.
cp "$DESKTOP_FILE" "$APPDIR/$APP_ID.desktop"
cp "$ICON_FILE" "$APPDIR/$APP_ID.png"
cp "$ICON_FILE" "$APPDIR/.DirIcon"

# AppRun statt eines Symlinks: das Binary liegt mit data/ und lib/ zusammen in
# usr/bin und muss von dort aus gestartet werden.
cat > "$APPDIR/AppRun" <<EOF
#!/usr/bin/env bash
HERE="\$(dirname "\$(readlink -f "\${0}")")"
exec "\$HERE/usr/bin/$BINARY_NAME" "\$@"
EOF
chmod 755 "$APPDIR/AppRun"

APPIMAGETOOL="$STAGE/appimagetool"
curl -fsSL -o "$APPIMAGETOOL" "$APPIMAGETOOL_URL"
chmod 755 "$APPIMAGETOOL"

mkdir -p "$OUTPUT_DIR"
# --appimage-extract-and-run, weil auf CI-Runnern kein FUSE verfügbar ist und
# appimagetool sich sonst nicht einmal selbst einhängen kann.
ARCH=x86_64 "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR" "$APPIMAGE_FILE"

echo "→ $APPIMAGE_FILE"
