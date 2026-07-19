#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fragment_root="$repo_root/src/Shell"
artifact="$repo_root/src/cdp.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-shell-modular.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

bash "$repo_root/scripts/Build-ShellScript.sh" --check >/dev/null

fragment_count=0
for fragment in "$fragment_root"/*.sh; do
    fragment_count=$((fragment_count + 1))
    lines="$(wc -l < "$fragment" | tr -d ' ')"
    if [[ "$lines" -gt 600 ]]; then
        echo "shell fragment exceeds 600 lines: $fragment ($lines)" >&2
        exit 1
    fi
    if grep -Eq '^[[:space:]]*(source|\.)[[:space:]].*Shell/' "$fragment"; then
        echo "shell fragment sources a peer: $fragment" >&2
        exit 1
    fi
    bash -n "$fragment"
    if command -v zsh >/dev/null 2>&1; then
        zsh -n "$fragment"
    fi
done
[[ "$fragment_count" -eq 14 ]]

[[ "$(head -n 1 "$artifact")" == '#!/usr/bin/env bash' ]]
bash -n "$artifact"
if command -v zsh >/dev/null 2>&1; then
    zsh -n "$artifact"
fi

grep -hE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*\(\)[[:space:]]*\{' \
    "$fragment_root"/*.sh | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_-]*)\(\).*/\1/' | sort > "$test_root/fragment-functions"
grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*\(\)[[:space:]]*\{' \
    "$artifact" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_-]*)\(\).*/\1/' | sort > "$test_root/artifact-functions"
cmp "$test_root/fragment-functions" "$test_root/artifact-functions"

mkdir -p "$test_root/home"
mkdir -p "$test_root/bin"
for dependency in fzf jq; do
    printf '#!/bin/sh\nexit 0\n' > "$test_root/bin/$dependency"
    chmod +x "$test_root/bin/$dependency"
done
PATH="$test_root/bin:$PATH" HOME="$test_root/home" SHELL=/bin/bash \
    bash "$repo_root/install-wsl.sh" --auto > "$test_root/install.log"
installed="$test_root/home/.local/bin/cdp.sh"
cmp "$artifact" "$installed"
HOME="$test_root/home" SHELL=/bin/bash bash -c 'source "$1"; type cdp >/dev/null; type cdp-status >/dev/null' _ "$installed"

echo "cdp shell modularization tests: ok"
