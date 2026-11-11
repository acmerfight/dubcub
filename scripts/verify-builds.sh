#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh
xcodebuild -version
xcrun swift --version
xcrun --sdk iphoneos --show-sdk-version
python3 scripts/tools.py run xcodegen generate

# Compile app and UI test targets without booting a simulator.
xcodebuild -project DubCub.xcodeproj -scheme DubCub \
    -configuration Debug -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build-for-testing

# Device SDK and optimized Release code have different compilation paths.
xcodebuild -project DubCub.xcodeproj -scheme DubCub \
    -configuration Release -destination 'generic/platform=iOS' \
    -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
