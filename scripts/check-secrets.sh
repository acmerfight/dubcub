#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# CI uses the official Linux x64 release with a reviewed, fixed digest.
version=8.30.1
checksum=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
curl --fail --location --retry 3 \
    "https://github.com/gitleaks/gitleaks/releases/download/v$version/gitleaks_${version}_linux_x64.tar.gz" \
    --output "$temporary/gitleaks.tar.gz"
printf '%s  %s\n' "$checksum" "$temporary/gitleaks.tar.gz" | sha256sum --check
tar -xzf "$temporary/gitleaks.tar.gz" -C "$temporary"
"$temporary/gitleaks" git --redact --no-banner --exit-code 1 .
