#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
shellcheck_path() {
    python3 -c 'import sys; sys.path.insert(0, "scripts"); import tools; print(tools.verify("shellcheck"))'
}
# pre-commit supplies staged paths and temporarily hides unstaged changes.
if [ "${1:-}" = hook ]; then
    operation=${2:?Missing hook check}
    shift 2
    set -- "${@/#/./}"
    case "$operation" in
        swiftlint) python3 scripts/tools.py run swiftlint lint --strict --no-cache --config .swiftlint.yml "$@" ;;
        swiftformat) python3 scripts/tools.py run swiftformat --lint --config .swiftformat "$@" ;;
        rendering) bash scripts/check-architecture.sh "$@" ;;
        ruff) python3 scripts/tools.py run ruff check -- "$@" ;;
        ruff-format) python3 scripts/tools.py run ruff format --check -- "$@" ;;
        shell) python3 scripts/tools.py run shellcheck --external-sources --source-path=SCRIPTDIR -- "$@" ;;
        workflows) python3 scripts/tools.py run actionlint -shellcheck="$(shellcheck_path)" "$@" ;;
        secrets) python3 scripts/tools.py run gitleaks git --pre-commit --staged --redact --no-banner --exit-code 1 . ;;
        *) printf 'Unknown hook check: %s\n' "$operation" >&2; exit 2 ;;
    esac
    exit
fi
if [ "$#" -gt 1 ]; then printf 'Too many check arguments.\n' >&2; exit 2; fi
scope=${1:-all}
portable() {
    shellcheck_binary=$(shellcheck_path)
    python3 scripts/tools.py run actionlint -shellcheck="$shellcheck_binary"
    # Include new shell files automatically; keep NUL delimiters for paths with spaces.
    git ls-files --cached --others --exclude-standard -z -- '*.sh' dev | \
        xargs -0 "$shellcheck_binary" --external-sources --source-path=SCRIPTDIR
    python3 scripts/tools.py run ruff check .
    python3 scripts/tools.py run ruff format --check .
    python3 -m unittest discover -s scripts/tests -p test_ui_health.py -v
}
swift() {
    source scripts/xcode-env.sh
    python3 scripts/tools.py run swiftlint lint --config .swiftlint.yml --strict --no-cache
    bash scripts/check-architecture.sh
}
apple() {
    swift
    bash scripts/check-architecture.sh --self-test
    python3 scripts/tools.py run swiftformat . --lint
    python3 scripts/check_project.py
    python3 -m unittest discover -s scripts/tests -p test_template.py -v
    python3 -m unittest discover -s scripts/tests -p test_hooks.py -v
}
case "$scope" in
    all) portable; apple; python3 scripts/tools.py run gitleaks git --redact --no-banner --exit-code 1 . ;;
    portable) portable ;;
    apple) apple ;;
    swift) swift ;;
    project) python3 scripts/check_project.py ;;
    secrets) python3 scripts/tools.py run gitleaks git --redact --no-banner --exit-code 1 . ;;
    *) printf 'Unknown check scope: %s\n' "$scope" >&2; exit 2 ;;
esac
