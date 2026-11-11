#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh
python3 scripts/tools.py run swiftlint lint --config .swiftlint.yml --strict --no-cache
