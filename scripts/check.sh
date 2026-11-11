#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/lint.sh
bash scripts/check-architecture.sh --self-test
bash scripts/check-architecture.sh
swiftformat . --lint
