#!/bin/bash
# Compiles Sources/Core together with Tests/ into a test executable and runs it.
# No permissions are needed: the tests feed synthetic CGEvents to the inverter.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="build/tests"
mkdir -p "$OUT"

# Compile a snapshot: cloud-synced folders (OneDrive, iCloud) can touch files
# mid-build, which makes swiftc abort with "modified during the build".
SNAP=$(mktemp -d)
trap 'rm -rf "$SNAP"' EXIT
mkdir -p "$SNAP/Core" "$SNAP/Tests"
cp Sources/Core/*.swift "$SNAP/Core/"
cp Tests/*.swift "$SNAP/Tests/"

swiftc -swift-version 5 \
    -target "$(uname -m)-apple-macos13.0" \
    "$SNAP"/Core/*.swift "$SNAP"/Tests/*.swift \
    -o "$OUT/ScrollFlipTests"

"$OUT/ScrollFlipTests"
