#!/usr/bin/env bash

set -euo pipefail

repo_root="${CDP_TEST_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
version="$(sed 's/\r$//' "$repo_root/cdp.psd1" | sed -n "s/^ModuleVersion = '\([^']*\)'$/\1/p" | head -n 1)"
package_root="cdp-$version"
output_path="${1:-}"
cleanup_output=false

if [[ -z "$output_path" ]]; then
    output_path="$(mktemp "${TMPDIR:-/tmp}/cdp-package-gate.XXXXXX.tar.gz")"
    cleanup_output=true
fi
cleanup() {
    if $cleanup_output; then
        rm -f "$output_path"
    fi
}
trap cleanup EXIT

calculate_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

bash "$repo_root/scripts/New-ScoopPackage.sh" "$version" "$output_path" >/dev/null
archive_entries="$(tar -tzf "$output_path")"

for required in cdp.psd1 Install.ps1 scripts/Cdp.Installation.ps1 src/cdp.psm1 src/cdp.sh; do
    grep -Fx "$package_root/$required" <<< "$archive_entries" >/dev/null || {
        echo "package missing required entry: $package_root/$required" >&2
        exit 1
    }
done
while IFS= read -r source_file; do
    relative_path="${source_file#$repo_root/}"
    grep -Fx "$package_root/$relative_path" <<< "$archive_entries" >/dev/null || {
        echo "package missing source entry: $package_root/$relative_path" >&2
        exit 1
    }
done < <(find "$repo_root/src/PowerShell" "$repo_root/src/Shell" -type f | sort)

if grep -Eq "^$package_root/(\.git|scoop|tests|README)" <<< "$archive_entries"; then
    echo 'package contains a forbidden repository-only entry' >&2
    exit 1
fi

manifest_hash="$(jq -r '.hash' "$repo_root/scoop/cdp.json")"
expected_hash="${CDP_PACKAGE_EXPECTED_HASH:-$manifest_hash}"
actual_hash="$(calculate_sha256 "$output_path")"
[[ "$expected_hash" =~ ^[0-9a-f]{64}$ ]] || { echo 'invalid expected Scoop package hash' >&2; exit 1; }
[[ "$actual_hash" == "$expected_hash" ]] || {
    echo "Scoop package hash mismatch: expected $expected_hash, got $actual_hash" >&2
    exit 1
}

echo "Scoop package is complete and deterministic for v$version ($actual_hash)."
