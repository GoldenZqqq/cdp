#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-installer-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/scripts" "$test_root/src" "$test_root/scoop"
cp "$repo_root/install-wsl.sh" "$test_root/"
cp "$repo_root/src/cdp.sh" "$test_root/src/"
cp "$repo_root/scoop/cdp.json" "$test_root/scoop/"

CDP_TEST_REPO_ROOT="$test_root" bash "$repo_root/scripts/Test-ShellInstaller.sh" >/dev/null

sed 's/^CDP_SCRIPT_SHA256="[0-9a-f]*"$/CDP_SCRIPT_SHA256="0000000000000000000000000000000000000000000000000000000000000000"/' \
    "$test_root/install-wsl.sh" > "$test_root/install-wsl.sh.next"
mv "$test_root/install-wsl.sh.next" "$test_root/install-wsl.sh"
if CDP_TEST_REPO_ROOT="$test_root" bash "$repo_root/scripts/Test-ShellInstaller.sh" >/dev/null 2>&1; then
    echo "installer validator accepted a cdp.sh digest drift" >&2
    exit 1
fi

cp "$repo_root/install-wsl.sh" "$test_root/install-wsl.sh"
jq '.hash = "skip"' "$test_root/scoop/cdp.json" > "$test_root/scoop/cdp.json.next"
mv "$test_root/scoop/cdp.json.next" "$test_root/scoop/cdp.json"
if CDP_TEST_REPO_ROOT="$test_root" bash "$repo_root/scripts/Test-ShellInstaller.sh" >/dev/null 2>&1; then
    echo "installer validator accepted Scoop hash skipping" >&2
    exit 1
fi

echo "cdp shell installer tests: ok"
