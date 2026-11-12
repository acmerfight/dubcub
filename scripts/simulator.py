#!/usr/bin/env python3
"""Select the same compatible simulator for interactive runs and UI tests."""

import argparse
import json
import platform
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("family", choices=("iphone", "ipad"))
    parser.add_argument("--check", action="store_true", help="Only verify runtime and device support")
    args = parser.parse_args()
    family = "iPhone" if args.family == "iphone" else "iPad"
    inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "--json"]))
    candidates = []
    for runtime in inventory["runtimes"]:
        if (
            not runtime.get("isAvailable")
            or not runtime["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
            or platform.machine() not in runtime.get("supportedArchitectures", [])
        ):
            continue
        types = [
            item
            for item in runtime["supportedDeviceTypes"]
            if item["identifier"].startswith("com.apple.CoreSimulator.SimDeviceType." + family)
        ]
        if types:
            candidates.append((runtime, types))
    if not candidates:
        sys.exit(f"No compatible {family} runtime found; install one in Xcode Settings → Components.")
    runtime, types = max(candidates, key=lambda item: tuple(map(int, item[0]["version"].split("."))))
    print(f"{family}: iOS {runtime['version']}", file=sys.stderr)
    if args.check:
        return
    supported = {item["identifier"] for item in types}
    devices = [
        device
        for device in inventory["devices"].get(runtime["identifier"], [])
        if device.get("isAvailable") and device["deviceTypeIdentifier"] in supported
    ]
    if devices:
        device = sorted(devices, key=lambda item: (item["state"] != "Booted", item["name"]))[0]
        identifier = device["udid"]
        booted = device["state"] == "Booted"
    else:
        identifier = subprocess.check_output(
            [
                "xcrun",
                "simctl",
                "create",
                f"SwiftSeed {family}",
                types[-1]["identifier"],
                runtime["identifier"],
            ],
            text=True,
        ).strip()
        booted = False
    if not booted:
        subprocess.run(["xcrun", "simctl", "boot", identifier], check=True, stdout=sys.stderr)
    print(identifier)


if __name__ == "__main__":
    main()
