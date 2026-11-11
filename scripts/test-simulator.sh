#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh

case "${1:-iphone}" in
    iphone|ipad) family="${1:-iphone}" ;;
    *) printf '用法：bash scripts/test-simulator.sh [iphone|ipad]\n' >&2; exit 2 ;;
esac

device_id=${TEST_SIMULATOR_ID:-$(bash scripts/prepare-test-simulator.sh "$family")}
mkdir -p build/TestResults
boot_log="$PWD/build/TestResults/$family-boot.log"
xcrun simctl bootstatus "$device_id" -b > "$boot_log" 2>&1 &
boot_pid=$!
trap 'kill "$boot_pid" 2>/dev/null || true' EXIT

python3 scripts/tools.py run xcodegen generate
result_path="$PWD/build/TestResults/$family-$(date +%Y%m%d-%H%M%S).xcresult"
build_arguments=(
    -project DubCub.xcodeproj -scheme DubCub -configuration Debug
    -destination "platform=iOS Simulator,id=$device_id"
    -derivedDataPath build/DerivedData -parallel-testing-enabled NO
    CODE_SIGNING_ALLOWED=NO
)
started=$SECONDS
xcodebuild "${build_arguments[@]}" build-for-testing
printf 'TIMING build_seconds=%s\n' "$((SECONDS - started))"
started=$SECONDS
wait "$boot_pid"
trap - EXIT
printf 'TIMING remaining_boot_seconds=%s\n' "$((SECONDS - started))"
started=$SECONDS
xcodebuild "${build_arguments[@]}" -resultBundlePath "$result_path" test-without-building
printf 'TIMING test_seconds=%s\n' "$((SECONDS - started))"

# A successful build or an empty test plan must not count as passing tests.
xcrun xcresulttool get test-results summary --path "$result_path" | \
    /usr/bin/python3 -c '
import json, sys
result = json.load(sys.stdin)
if result["passedTests"] < 1 or result["failedTests"] or result["skippedTests"]:
    sys.exit("测试必须实际执行且全部通过，不接受空跑或跳过。")
print("通过测试数：", result["passedTests"])
'
