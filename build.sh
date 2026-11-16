#!/bin/bash
# Builds ScrollFlip.app without Xcode (Command Line Tools are enough).
#   ./build.sh           -> build/ScrollFlip.app
#   ./build.sh install   -> also copies it to /Applications and launches it
#
# Signing: uses the "ScrollFlip Local Signing" certificate if it exists
# (see scripts/create-signing-cert.sh), so the Accessibility permission
# survives rebuilds. Otherwise falls back to ad-hoc signing.
# Override with SIGN_ID="<identity name or SHA-1>".
set -euo pipefail
cd "$(dirname "$0")"

APP="build/ScrollFlip.app"
CERT_NAME="ScrollFlip Local Signing"

if [[ -z "${SIGN_ID:-}" ]]; then
    SIGN_ID=$(security find-identity -p codesigning 2>/dev/null \
        | grep "\"$CERT_NAME\"" | head -1 | awk '{print $2}' || true)
fi
if [[ -z "$SIGN_ID" ]]; then
    SIGN_ID="-"
    echo "⚠ No local certificate found: signing ad-hoc."
    echo "  The Accessibility permission will have to be granted again after each build."
    echo "  Run scripts/create-signing-cert.sh once to avoid this."
fi

rm -rf build
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 \
    -target arm64-apple-macos13.0 \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/ScrollFlip"

cp Resources/Info.plist "$APP/Contents/Info.plist"

# Cloud-synced folders (OneDrive, iCloud) add extended attributes that break codesign.
xattr -cr "$APP"

codesign --force --options runtime \
    --entitlements Resources/ScrollFlip.entitlements \
    --sign "$SIGN_ID" "$APP"

echo "✔ Built: $APP"

if [[ "${1:-}" == "install" ]]; then
    pkill -x ScrollFlip 2>/dev/null || true
    sleep 0.5
    rm -rf /Applications/ScrollFlip.app
    cp -R "$APP" /Applications/
    open /Applications/ScrollFlip.app
    echo "✔ Installed and launched: /Applications/ScrollFlip.app"
fi
