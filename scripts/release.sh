#!/bin/bash
# Build a drag-to-Applications DMG for PeakLayout.
#
#   scripts/release.sh             → dist/PeakLayout-<version>.dmg
#   scripts/release.sh --publish   → also creates GitHub release v<version> with the DMG
#
# Signing:
#   - If a "Developer ID Application" certificate is in the keychain, the app and DMG are signed with it.
#   - If NOTARY_PROFILE (default: PeakLayout-notary) exists, both are notarized and stapled,
#     so Gatekeeper opens the app without warnings. Create the profile once with:
#       xcrun notarytool store-credentials PeakLayout-notary --apple-id <apple-id> --team-id <team-id>
#   - Otherwise the app is ad-hoc signed and users confirm the first launch
#     in System Settings › Privacy & Security › Open Anyway.
set -euo pipefail

cd "$(dirname "$0")/.."
PUBLISH=false
[[ "${1:-}" == "--publish" ]] && PUBLISH=true
NOTARY_PROFILE="${NOTARY_PROFILE:-PeakLayout-notary}"

VERSION=$(xcodebuild -project PeakLayout.xcodeproj -scheme PeakLayout -configuration Release -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ MARKETING_VERSION/ {print $2; exit}')
APP_BUILD=build/Build/Products/Release/PeakLayout.app
DIST=dist
STAGE="$DIST/stage"
DMG="$DIST/PeakLayout-$VERSION.dmg"

echo "▸ Building PeakLayout $VERSION (Release, universal)"
rm -rf build "$DIST"
xcodebuild -project PeakLayout.xcodeproj -scheme PeakLayout -configuration Release \
  -derivedDataPath build ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO clean build | grep -E "error|BUILD" || true
[[ -d "$APP_BUILD" ]] || { echo "Build failed"; exit 1; }

mkdir -p "$STAGE"
cp -R "$APP_BUILD" "$STAGE/"
APP="$STAGE/PeakLayout.app"

DEV_ID=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')
NOTARIZE=false
if [[ -n "$DEV_ID" ]]; then
  echo "▸ Signing with $DEV_ID"
  codesign --force --options runtime --timestamp --entitlements PeakLayout.entitlements --sign "$DEV_ID" "$APP"
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    NOTARIZE=true
    echo "▸ Notarizing app"
    ditto -c -k --keepParent "$APP" "$DIST/notarize.zip"
    xcrun notarytool submit "$DIST/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    rm "$DIST/notarize.zip"
  else
    echo "▸ No notary profile '$NOTARY_PROFILE' — skipping notarization"
  fi
else
  # Development certificates carry a personal name and Gatekeeper rejects them on other Macs anyway,
  # so public builds without Developer ID get an anonymous ad-hoc signature.
  echo "▸ No Developer ID certificate — ad-hoc signing (first launch needs Open Anyway)"
  codesign --force --options runtime --entitlements PeakLayout.entitlements --sign - "$APP"
fi
codesign --verify --strict "$APP"

echo "▸ Creating DMG"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "PeakLayout" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"

if [[ -n "$DEV_ID" ]]; then
  codesign --force --timestamp --sign "$DEV_ID" "$DMG"
  if $NOTARIZE; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
fi

shasum -a 256 "$DMG" | tee "$DMG.sha256"

if $PUBLISH; then
  echo "▸ Publishing GitHub release v$VERSION"
  NOTES=$(mktemp)
  if $NOTARIZE; then
    GATEKEEPER_EN="Signed with Developer ID and notarized by Apple — opens without warnings."
    GATEKEEPER_TR="Developer ID ile imzalı ve Apple tarafından onaylı (notarized) — uyarısız açılır."
  else
    GATEKEEPER_EN="Not notarized yet: on first launch macOS blocks the app. Open **System Settings › Privacy & Security** and click **Open Anyway** (once)."
    GATEKEEPER_TR="Henüz Apple onaylı (notarized) değil: ilk açılışta macOS uygulamayı engeller. **Sistem Ayarları › Gizlilik ve Güvenlik**'te **Yine de Aç**'a bas (bir kez)."
  fi
  cat > "$NOTES" <<EOF
### Install
1. Download **PeakLayout-$VERSION.dmg**, open it and drag **PeakLayout** onto **Applications**.
2. Launch PeakLayout from Applications. $GATEKEEPER_EN
3. Allow the permission prompts (Finder, Desktop, Downloads). See [Permissions](https://github.com/peakode/PeakLayout#permissions).

### Kurulum
1. **PeakLayout-$VERSION.dmg** dosyasını indir, aç ve **PeakLayout**'u **Applications** klasörüne sürükle.
2. PeakLayout'u Uygulamalar'dan başlat. $GATEKEEPER_TR
3. İzin pencerelerini onayla (Finder, Masaüstü, Downloads). Bkz. [İzinler](https://github.com/peakode/PeakLayout/blob/main/README.tr.md#izinler).

Requires macOS 14 or later · macOS 14 veya üstü gerekir · Universal (Apple silicon + Intel)

SHA-256: \`$(cut -d' ' -f1 "$DMG.sha256")\`
EOF
  gh release create "v$VERSION" "$DMG" "$DMG.sha256" --title "PeakLayout $VERSION" --notes-file "$NOTES"
  rm "$NOTES"
fi

echo "✓ $DMG"
