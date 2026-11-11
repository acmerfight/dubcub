#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh

case "${1:-iphone}" in
    iphone) device_name='DubCub iPhone'; device_type='com.apple.CoreSimulator.SimDeviceType.iPhone-16' ;;
    ipad) device_name='DubCub iPad'; device_type='com.apple.CoreSimulator.SimDeviceType.iPad-A16' ;;
    *) printf '用法：bash scripts/run-simulator.sh [iphone|ipad]\n' >&2; exit 2 ;;
esac
runtime_id=$(xcrun simctl list runtimes --json | /usr/bin/python3 -c '
import json, platform, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"]
            if r.get("isAvailable") and r.get("platform") == "iOS"
            and platform.machine() in r.get("supportedArchitectures", [])
            and any(d["identifier"] == sys.argv[1] for d in r.get("supportedDeviceTypes", []))]
if not runtimes:
    sys.exit("未找到兼容的 iOS 模拟器运行环境，请先在 Xcode 中安装。")
print(max(runtimes, key=lambda r: tuple(map(int, r["version"].split("."))))["identifier"])
' "$device_type")
bash scripts/build-simulator.sh
device_id=$(xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"].get(sys.argv[1], [])
print(next((d["udid"] for d in devices if d["name"] == sys.argv[2]), ""))
' "$runtime_id" "$device_name")
if [ -z "$device_id" ]; then
    device_id=$(xcrun simctl create "$device_name" "$device_type" "$runtime_id")
fi
xcrun simctl bootstatus "$device_id" -b
app_path='build/DerivedData/Build/Products/Debug-iphonesimulator/DubCub.app'
xcrun simctl install "$device_id" "$app_path"
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app_path/Info.plist")
xcrun simctl launch --terminate-running-process "$device_id" "$bundle_id"
printf 'App 已在 %s 中启动。可从 Xcode → Open Developer Tool → Simulator 查看。\n' "$device_name"
