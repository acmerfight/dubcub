#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(cat .swiftlint-version)
destination="$PWD/.build/tools/swiftlint/$version"
checksum=c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT

# Install the official universal macOS binary; never download during a build.
curl --fail --location --retry 3 \
    "https://github.com/realm/SwiftLint/releases/download/$version/portable_swiftlint.zip" \
    --output "$temporary/swiftlint.zip"
printf '%s  %s\n' "$checksum" "$temporary/swiftlint.zip" | shasum -a 256 --check
unzip -q "$temporary/swiftlint.zip" -d "$temporary/unpacked"
test "$("$temporary/unpacked/swiftlint" version)" = "$version"
mkdir -p "$destination"
cp "$temporary/unpacked/swiftlint" "$temporary/unpacked/LICENSE" "$destination/"
printf 'SwiftLint %s 已安装。\n' "$version"
