#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh

case "${1:-iphone}" in
    iphone|ipad) family="${1:-iphone}" ;;
    *) printf '用法：bash scripts/test-simulator.sh [iphone|ipad]\n' >&2; exit 2 ;;
esac

# Select an installed device instead of depending on one runner image's model name.
device_id=$(xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json, sys
family = "iPhone" if sys.argv[1] == "iphone" else "iPad"
candidates = [(runtime, device) for runtime, devices in json.load(sys.stdin)["devices"].items()
              if ".iOS-" in runtime for device in devices
              if family in device["name"] and device.get("isAvailable")]
if not candidates:
    sys.exit("未找到可用的 " + family + " 模拟器，请安装 iOS 模拟器运行时。")
candidates.sort(key=lambda item: tuple(map(int, item[0].split(".iOS-")[1].split("-"))), reverse=True)
print(candidates[0][1]["udid"])
' "$family")

xcodegen generate
mkdir -p build/TestResults
result_path="$PWD/build/TestResults/$family-$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild -project DubCub.xcodeproj -scheme DubCub \
    -configuration Debug -destination "platform=iOS Simulator,id=$device_id" \
    -derivedDataPath build/DerivedData -resultBundlePath "$result_path" \
    -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test

# A successful build or an empty test plan must not count as passing tests.
xcrun xcresulttool get test-results summary --path "$result_path" | \
    /usr/bin/python3 -c '
import json, sys
result = json.load(sys.stdin)
if result["passedTests"] < 1 or result["failedTests"] or result["skippedTests"]:
    sys.exit("测试必须实际执行且全部通过，不接受空跑或跳过。")
print("通过测试数：", result["passedTests"])
'
