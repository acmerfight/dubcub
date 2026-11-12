#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh

case "${1:-iphone}" in
    iphone|ipad) family="${1:-iphone}" ;;
    *) printf 'Usage: bash scripts/prepare-test-simulator.sh [iphone|ipad]\n' >&2; exit 2 ;;
esac

device_id=$(xcrun simctl list --json | /usr/bin/python3 -c '
import json, sys
family = "iPhone" if sys.argv[1] == "iphone" else "iPad"
inventory = json.load(sys.stdin)
runtimes = {runtime["identifier"]: runtime for runtime in inventory["runtimes"]
            if runtime.get("isAvailable")
            and runtime["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")}
candidates = [(runtimes[runtime], device) for runtime, devices in inventory["devices"].items()
              if runtime in runtimes for device in devices
              if device["deviceTypeIdentifier"].startswith("com.apple.CoreSimulator.SimDeviceType." + family)
              and device.get("isAvailable")]
if not candidates:
    sys.exit("No available " + family + " simulator found; install an iOS simulator runtime.")
candidates.sort(key=lambda item: (tuple(map(int, item[0]["version"].split("."))),
                                  item[1]["state"] == "Booted"), reverse=True)
runtime, device = candidates[0]
print("Test device: ", device["name"], "Runtime: ", runtime["version"], runtime["identifier"], file=sys.stderr)
print(device["udid"], device["state"])
' "$family")
read -r device_id device_state <<< "$device_id"
if [ "$device_state" != Booted ]; then
    xcrun simctl boot "$device_id" >&2
fi
printf '%s\n' "$device_id"
