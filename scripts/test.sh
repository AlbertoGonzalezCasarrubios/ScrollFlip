#!/bin/bash
# Compiles Sources/Core together with Tests/ into a test executable and runs it.
# No permissions are needed: the tests feed synthetic CGEvents to the inverter.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="build/tests"
mkdir -p "$OUT"

swiftc -swift-version 5 \
    -target "$(uname -m)-apple-macos13.0" \
    Sources/Core/*.swift Tests/*.swift \
    -o "$OUT/ScrollFlipTests"

"$OUT/ScrollFlipTests"
