#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh

# Use the parser bundled with the selected Xcode; no downloaded dependency.
swift_compiler=$(xcrun --find swiftc)
host_libraries="$(dirname "$swift_compiler")/../lib/swift/host"
if [ ! -d "$host_libraries/SwiftParser.swiftmodule" ]; then
    printf 'error: 当前 Xcode 缺少架构检查所需的 SwiftParser。\n' >&2
    exit 1
fi
# Build phases inherit the iOS SDK/architecture. The checker runs on the Mac.
if [ "$#" -eq 0 ]; then
    set -- SwiftSeed/Rendering
fi
xcrun --sdk macosx swift -swift-version 6 \
    -target "$(uname -m)-apple-macosx13.0" \
    -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -I "$host_libraries" -L "$host_libraries" \
    -Xlinker -rpath -Xlinker "$host_libraries" \
    scripts/architecture/check.swift "$@"
