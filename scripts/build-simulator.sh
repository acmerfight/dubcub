#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh
if ! xcrun --sdk iphonesimulator --show-sdk-path >/dev/null 2>&1; then
    printf 'Install full Xcode and iOS platform components before running this script.\n' >&2
    exit 1
fi
python3 scripts/tools.py run xcodegen generate
xcodebuild -project SwiftSeed.xcodeproj -scheme SwiftSeed \
    -configuration Debug -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
