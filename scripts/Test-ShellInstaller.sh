#!/usr/bin/env bash

set -euo pipefail

repo_root="${CDP_TEST_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
installer="$repo_root/install-wsl.sh"
shell_script="$repo_root/src/cdp.sh"
scoop_manifest="$repo_root/scoop/cdp.json"

read_assignment() {
    local name="$1"
    sed -n "s/^${name}=\"\(.*\)\"$/\1/p" "$installer" | head -n 1
}

version=$(read_assignment CDP_INSTALL_VERSION)
expected_ref="v$version"
# The sed expression intentionally matches a literal shell parameter expansion.
# shellcheck disable=SC2016
configured_ref=$(sed -n 's/^CDP_INSTALL_REF="${CDP_INSTALL_REF:-\(.*\)}"$/\1/p' "$installer")
expected_script_hash=$(read_assignment CDP_SCRIPT_SHA256)
if command -v sha256sum >/dev/null 2>&1; then
    actual_script_hash=$(sha256sum "$shell_script" | awk '{print $1}')
else
    actual_script_hash=$(shasum -a 256 "$shell_script" | awk '{print $1}')
fi
scoop_hash=$(jq -r '.hash' "$scoop_manifest")

[[ -n "$version" ]] || { echo "installer version missing" >&2; exit 1; }
[[ "$configured_ref" == "$expected_ref" ]] || { echo "installer ref mismatch" >&2; exit 1; }
[[ "$expected_script_hash" == "$actual_script_hash" ]] || { echo "cdp.sh SHA-256 mismatch" >&2; exit 1; }
[[ "$scoop_hash" != "skip" && "$scoop_hash" =~ ^[0-9a-fA-F]{64}$ ]] || {
    echo "Scoop archive SHA-256 missing" >&2
    exit 1
}

echo "Shell installer metadata is consistent for $expected_ref."
