#!/bin/bash
# Prefer the installed Xcode without changing global shell settings.
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

# An explicit version permits a reviewed newer-SDK CI lane without silently
# accepting whatever Xcode happens to be selected on a developer's computer.
expected_xcode=${EXPECTED_XCODE_VERSION:-$(cat "$(dirname "${BASH_SOURCE[0]}")/../.xcode-version")}
actual_xcode=$(xcodebuild -version) || return 1
if [ "$(printf '%s\n' "$actual_xcode" | head -n 1)" != "Xcode $expected_xcode" ]; then
    printf 'error: Expected Xcode %s, found %s. Explicitly select a matching DEVELOPER_DIR.\n' \
        "$expected_xcode" "$actual_xcode" >&2
    return 1
fi
