#!/bin/bash
set -u
source "$(dirname "$0")/xcode-env.sh"
issues=0
printf '系统：%s / %s\n' "$(sw_vers -productVersion)" "$(uname -m)"
for tool in git swift xcodegen swiftformat; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf '已安装：%s\n' "$tool"
    else
        printf '缺少：%s\n' "$tool"
        issues=$((issues + 1))
    fi
done
if xcodebuild -version; then
    xcodebuild -showsdks
    if ! xcrun simctl list runtimes --json | /usr/bin/python3 -c 'import json,sys; items=json.load(sys.stdin)["runtimes"]; ready=[r for r in items if r.get("isAvailable") and r.get("identifier", "").startswith("com.apple.CoreSimulator.SimRuntime.iOS-")]; print("可用 iOS 模拟器运行时：", ", ".join(r["name"] for r in ready) or "无"); sys.exit(0 if ready else 1)'; then
        printf '请在 Xcode Settings → Components 中安装一个 iOS 模拟器运行时。\n'
        issues=$((issues + 1))
    fi
    if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
        printf '缺少 iOS SDK，请在 Xcode Settings → Components 中安装。\n'
        issues=$((issues + 1))
    fi
else
    printf '尚未启用完整 Xcode。安装并首次启动后执行：sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer\n'
    issues=$((issues + 1))
fi
printf '\n尚未就绪的项目数：%s\n' "$issues"
exit "$issues"
