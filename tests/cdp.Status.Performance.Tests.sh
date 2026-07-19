#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-status-performance.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

repo="$test_root/repo"
mkdir -p "$repo"
git init -q "$repo"
git -C "$repo" config user.name cdp-test
git -C "$repo" config user.email cdp@example.invalid
printf 'initial\n' > "$repo/file.txt"
git -C "$repo" add file.txt
git -C "$repo" commit -q -m initial

config="$test_root/projects.json"
printf '[{"name":"Repo","rootPath":"%s","enabled":true}]\n' "$repo" > "$config"
real_git="$(command -v git)"
mkdir -p "$test_root/bin"
printf '%s\n' '#!/usr/bin/env bash' \
    "printf '%s\\n' \"\$*\" >> \"$test_root/git-calls.log\"" \
    "exec \"$real_git\" \"\$@\"" > "$test_root/bin/git"
chmod +x "$test_root/bin/git"

PATH="$test_root/bin:$PATH" CDP_STATUS_CACHE_TTL=0 bash -c '
    source "$1/src/cdp.sh"
    cdp-status --jobs 2 "$2" >/dev/null 2>&1
' _ "$repo_root" "$config"

git_calls="$(wc -l < "$test_root/git-calls.log" | tr -d ' ')"
[[ "$git_calls" -eq 2 ]] || { echo "expected 2 git calls, got $git_calls" >&2; exit 1; }
if grep -Eq 'rev-parse|rev-list|branch --show-current' "$test_root/git-calls.log"; then
    echo 'status collector still uses legacy git probes' >&2
    exit 1
fi

PATH="$test_root/bin:$PATH" CDP_STATUS_CACHE_TTL=30 bash -c '
    source "$1/src/cdp.sh"
    cdp-status "$2" >/dev/null 2>&1
    cdp-status "$2" >/dev/null 2>&1
    cdp-status --refresh "$2" >/dev/null 2>&1
' _ "$repo_root" "$config"
cached_calls="$(wc -l < "$test_root/git-calls.log" | tr -d ' ')"
[[ "$cached_calls" -eq 6 ]] || { echo "cache/refresh expected 6 total calls, got $cached_calls" >&2; exit 1; }

cache_replacement=$(bash -c '
    source "$1/src/cdp.sh"
    now=$(date +%s)
    CDP_STATUS_CACHE_KEYS=(first expired last)
    CDP_STATUS_CACHE_TIMES=("$now" "$((now - 10))" "$now")
    CDP_STATUS_CACHE_VALUES=(one stale three)
    cdp_status_cache_get expired 1 false >/dev/null 2>&1 || true
    cdp_status_cache_set expired fresh 1
    cdp_status_cache_get expired 1 false
' _ "$repo_root")
[[ "$cache_replacement" == fresh ]] || { echo 'expired cache entry was not replaced in place' >&2; exit 1; }

if command -v zsh >/dev/null 2>&1; then
    zsh_setting=$(CDP_STATUS_CONCURRENCY=3 zsh -f -c '
        set -eu
        source "$1/src/cdp.sh"
        cdp_status_setting CDP_STATUS_CONCURRENCY 4 1 16
    ' _ "$repo_root")
    [[ "$zsh_setting" == 3 ]] || { echo "zsh status setting expected 3, got $zsh_setting" >&2; exit 1; }
fi

printf '%s\n' '#!/usr/bin/env bash' \
    'case "$*" in *status*) sleep 2 ;; esac' \
    "exec \"$real_git\" \"\$@\"" > "$test_root/bin/git-timeout"
chmod +x "$test_root/bin/git-timeout"
timeout_output=$(CDP_STATUS_GIT_COMMAND="$test_root/bin/git-timeout" CDP_STATUS_TIMEOUT_SECONDS=1 \
    bash -c 'source "$1/src/cdp.sh"; cdp-status "$2" 2>&1' _ "$repo_root" "$config")
[[ "$timeout_output" == *"status timed out"* ]] || { echo 'status timeout was not rendered' >&2; exit 1; }

mkdir -p "$test_root/fallback-bin"
ln -s "$(command -v bash)" "$test_root/fallback-bin/bash"
ln -s "$(command -v sleep)" "$test_root/fallback-bin/sleep"
fallback_exit=$(PATH="$test_root/fallback-bin" CDP_STATUS_GIT_COMMAND="$test_root/bin/git-timeout" \
    bash -c 'source "$1/src/cdp.sh"; cdp_status_git_command 1 status >/dev/null 2>&1 || printf "%s" "$?"' \
    _ "$repo_root")
[[ "$fallback_exit" == 124 ]] || { echo "portable timeout expected 124, got $fallback_exit" >&2; exit 1; }

echo "cdp status performance tests: ok"
