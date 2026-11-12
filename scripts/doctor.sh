#!/bin/bash
set -u
source "$(dirname "$0")/xcode-env.sh" || exit 1
issues=0
printf 'System: %s / %s\n' "$(sw_vers -productVersion)" "$(uname -m)"
for tool in git swift python3; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf 'Installed: %s\n' "$tool"
    else
        printf 'Missing: %s\n' "$tool"
        issues=$((issues + 1))
    fi
done
project_root=$(cd "$(dirname "$0")/.." && pwd)
if ! python3 "$project_root/scripts/tools.py" check; then
    issues=$((issues + 1))
fi
if xcodebuild -version; then
    xcodebuild -showsdks
    if ! xcrun simctl list runtimes --json | /usr/bin/python3 -c 'import json,sys; items=json.load(sys.stdin)["runtimes"]; ready=[r for r in items if r.get("isAvailable") and r.get("identifier", "").startswith("com.apple.CoreSimulator.SimRuntime.iOS-")]; print("Available iOS simulator runtimes: ", ", ".join(r["name"] for r in ready) or "none"); sys.exit(0 if ready else 1)'; then
        printf 'Install an iOS simulator runtime in Xcode Settings → Components.\n'
        issues=$((issues + 1))
    fi
    if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
        printf 'Missing iOS SDK; install it in Xcode Settings → Components.\n'
        issues=$((issues + 1))
    fi
else
    printf 'Full Xcode is not selected. Install and launch it once, then run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer\n'
    issues=$((issues + 1))
fi
printf '\nItems not ready: %s\n' "$issues"
exit "$issues"
