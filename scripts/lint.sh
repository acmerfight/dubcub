#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh

version=$(cat .swiftlint-version)
binary="$PWD/.build/tools/swiftlint/$version/swiftlint"
if [ ! -x "$binary" ] || [ "$("$binary" version)" != "$version" ]; then
    printf 'error: 请先运行 bash scripts/install-swiftlint.sh，安装项目指定的 SwiftLint。\n' >&2
    exit 1
fi

"$binary" lint --config .swiftlint.yml --strict --no-cache
