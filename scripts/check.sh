#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/check-architecture.sh --self-test
bash scripts/check-architecture.sh
swiftformat DubCub scripts/architecture --lint
