#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Pin official release artifacts and verify them before execution on local Macs and CI.
actionlint_version=1.7.12
shellcheck_version=0.11.0
case "$(uname -s)-$(uname -m)" in
    Darwin-x86_64)
        platform=darwin; actionlint_arch=amd64; shellcheck_arch=x86_64
        actionlint_hash=5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644
        shellcheck_hash=c2c15e08df0e8fbc374c335b230a7ee958c313fa5714817a59aa59f1aa594f51
        ;;
    Darwin-arm64)
        platform=darwin; actionlint_arch=arm64; shellcheck_arch=aarch64
        actionlint_hash=aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f
        shellcheck_hash=339b930feb1ea764467013cc1f72d09cd6b869ebf1013296ba9055ab2ffbd26f
        ;;
    Linux-x86_64)
        platform=linux; actionlint_arch=amd64; shellcheck_arch=x86_64
        actionlint_hash=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
        shellcheck_hash=b7af85e41cc99489dcc21d66c6d5f3685138f06d34651e6d34b42ec6d54fe6f6
        ;;
    Linux-aarch64)
        platform=linux; actionlint_arch=arm64; shellcheck_arch=aarch64
        actionlint_hash=325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6
        shellcheck_hash=68a8133197a50beb8803f8d42f9908d1af1c5540d4bb05fdfca8c1fa47decefc
        ;;
    *) printf 'Unsupported workflow lint platform.\n' >&2; exit 1 ;;
esac

temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
fetch_verified() {
    local url=$1 checksum=$2 archive=$3
    curl --fail --location --retry 3 "$url" --output "$archive"
    printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 --check
    tar -xzf "$archive" -C "$temporary"
}
fetch_verified \
    "https://github.com/rhysd/actionlint/releases/download/v${actionlint_version}/actionlint_${actionlint_version}_${platform}_${actionlint_arch}.tar.gz" \
    "$actionlint_hash" "$temporary/actionlint.tar.gz"
fetch_verified \
    "https://github.com/koalaman/shellcheck/releases/download/v${shellcheck_version}/shellcheck-v${shellcheck_version}.${platform}.${shellcheck_arch}.tar.gz" \
    "$shellcheck_hash" "$temporary/shellcheck.tar.gz"

# Explicit paths prevent silently falling back to missing or different helper versions.
shellcheck_binary="$temporary/shellcheck-v${shellcheck_version}/shellcheck"
"$shellcheck_binary" --version
"$temporary/actionlint" -version
"$temporary/actionlint" -shellcheck="$shellcheck_binary" "$@"
