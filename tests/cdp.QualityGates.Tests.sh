#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-quality-gates.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

bash "$repo_root/scripts/Test-ScoopPackage.sh" "$test_root/cdp-valid.tar.gz" >/dev/null

crlf_repo="$test_root/crlf-repo"
mkdir -p "$crlf_repo/scripts" "$crlf_repo/scoop"
cp -R "$repo_root/src" "$crlf_repo/"
cp "$repo_root/Install.ps1" "$crlf_repo/"
cp "$repo_root/scripts/Cdp.Installation.ps1" \
    "$repo_root/scripts/New-ScoopPackage.sh" \
    "$repo_root/scripts/Test-ScoopPackage.sh" \
    "$crlf_repo/scripts/"
cp "$repo_root/scoop/cdp.json" "$crlf_repo/scoop/"
sed 's/\r$//' "$repo_root/cdp.psd1" | sed 's/$/\r/' > "$crlf_repo/cdp.psd1"
CDP_TEST_REPO_ROOT="$crlf_repo" \
    bash "$crlf_repo/scripts/Test-ScoopPackage.sh" "$test_root/cdp-crlf.tar.gz" >/dev/null

invalid_hash='0000000000000000000000000000000000000000000000000000000000000000'
if CDP_PACKAGE_EXPECTED_HASH="$invalid_hash" \
    bash "$repo_root/scripts/Test-ScoopPackage.sh" "$test_root/cdp-invalid.tar.gz" >/dev/null 2>&1; then
    echo 'package gate accepted a deliberately incorrect hash' >&2
    exit 1
fi

echo 'cdp quality gate shell tests: ok'
