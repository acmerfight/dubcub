#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh

case "${1:-iphone}" in
    iphone|ipad) family="${1:-iphone}" ;;
    *) printf '用法：bash scripts/prepare-test-simulator.sh [iphone|ipad]\n' >&2; exit 2 ;;
esac

device_id=$(xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json, sys
family = "iPhone" if sys.argv[1] == "iphone" else "iPad"
candidates = [(runtime, device) for runtime, devices in json.load(sys.stdin)["devices"].items()
              if ".iOS-" in runtime for device in devices
              if family in device["name"] and device.get("isAvailable")]
if not candidates:
    sys.exit("未找到可用的 " + family + " 模拟器，请安装 iOS 模拟器运行时。")
candidates.sort(key=lambda item: (tuple(map(int, item[0].split(".iOS-")[1].split("-"))),
                                  item[1]["state"] == "Booted"), reverse=True)
device = candidates[0][1]
print(device["udid"], device["state"])
' "$family")
read -r device_id device_state <<< "$device_id"
if [ "$device_state" != Booted ]; then
    xcrun simctl boot "$device_id" >&2
fi
printf '%s\n' "$device_id"
