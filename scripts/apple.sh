#!/bin/bash
# Shared generation, build arguments, and simulator lifecycle for all Apple tasks.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh
operation=${1:?Missing Apple task}
family=${2:-iphone}
if [ "$#" -gt 2 ]; then printf 'Too many arguments.\n' >&2; exit 2; fi
build_arguments=(-project SwiftSeed.xcodeproj -scheme SwiftSeed -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO)
generate() { python3 scripts/tools.py run xcodegen generate; }
build() { xcodebuild "${build_arguments[@]}" "$@"; }
case "$operation" in
    generate) generate ;;
    doctor)
        xcodebuild -version
        xcrun swift --version
        xcrun --sdk iphoneos --show-sdk-version
        python3 scripts/tools.py check apple
        python3 scripts/simulator.py iphone --check
        python3 scripts/simulator.py ipad --check
        ;;
    build)
        generate
        build -configuration Debug -destination 'generic/platform=iOS Simulator' build-for-testing
        build -configuration Release -destination 'generic/platform=iOS' build
        ;;
    run|test)
        device_id=$(python3 scripts/simulator.py "$family")
        mkdir -p build/TestResults
        xcrun simctl bootstatus "$device_id" -b > "build/TestResults/$family-boot.log" 2>&1 &
        boot_pid=$!
        trap 'kill "$boot_pid" 2>/dev/null || true' EXIT
        generate
        build_arguments+=(-configuration Debug -destination "platform=iOS Simulator,id=$device_id" -parallel-testing-enabled NO)
        started=$SECONDS
        if [ "$operation" = test ]; then build build-for-testing; else build build; fi
        printf 'TIMING build_seconds=%s\n' "$((SECONDS - started))"
        started=$SECONDS
        wait "$boot_pid"
        trap - EXIT
        printf 'TIMING remaining_boot_seconds=%s\n' "$((SECONDS - started))"
        if [ "$operation" = run ]; then
            app_path=build/DerivedData/Build/Products/Debug-iphonesimulator/SwiftSeed.app
            xcrun simctl install "$device_id" "$app_path"
            bundle_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app_path/Info.plist")
            xcrun simctl launch --terminate-running-process "$device_id" "$bundle_id"
            printf 'App launched. Open Xcode → Open Developer Tool → Simulator to view it.\n'
        else
            result_path="$PWD/build/TestResults/$family-$(date +%Y%m%d-%H%M%S).xcresult"
            started=$SECONDS
            build -resultBundlePath "$result_path" test-without-building
            printf 'TIMING test_seconds=%s\n' "$((SECONDS - started))"
            xcrun xcresulttool get test-results summary --path "$result_path" | python3 -c '
import json, sys
result = json.load(sys.stdin)
if result["passedTests"] < 1 or result["failedTests"] or result["skippedTests"]:
    sys.exit("Tests must execute and all pass; empty or skipped tests are not accepted.")
print("Passed tests:", result["passedTests"])
'
        fi
        ;;
    *) printf 'Unknown Apple task: %s\n' "$operation" >&2; exit 2 ;;
esac
