#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-quality-gates.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

bash "$repo_root/scripts/Test-ScoopPackage.sh" "$test_root/cdp-valid.tar.gz" >/dev/null

invalid_hash='0000000000000000000000000000000000000000000000000000000000000000'
if CDP_PACKAGE_EXPECTED_HASH="$invalid_hash" \
    bash "$repo_root/scripts/Test-ScoopPackage.sh" "$test_root/cdp-invalid.tar.gz" >/dev/null 2>&1; then
    echo 'package gate accepted a deliberately incorrect hash' >&2
    exit 1
fi

echo 'cdp quality gate shell tests: ok'
