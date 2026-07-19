#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_tmp_base="$(CDPATH= cd -- "${TMPDIR:-/tmp}" && pwd -P)"
test_root="$(mktemp -d "$test_tmp_base/cdp-status-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

source "$repo_root/src/cdp.sh"

init_repo() {
    local path="$1"
    mkdir -p "$path"
    git -C "$path" init --quiet -b main
    git -C "$path" config user.email tests@example.invalid
    git -C "$path" config user.name "cdp tests"
}

assert_contains() {
    local value="$1"
    local expected="$2"
    case "$value" in
        *"$expected"*) ;;
        *)
            echo "Expected output containing '$expected', got: $value" >&2
            return 1
            ;;
    esac
}

source_repo="$test_root/worktree-source"
linked_worktree="$test_root/linked-worktree"
init_repo "$source_repo"
printf 'initial\n' > "$source_repo/tracked.txt"
git -C "$source_repo" add tracked.txt
git -C "$source_repo" commit --quiet -m initial
git -C "$source_repo" worktree add --quiet -b linked "$linked_worktree"

worktree_config="$test_root/worktree-projects.json"
printf '[{"name":"LinkedWorktree","rootPath":"%s","enabled":true}]\n' "$linked_worktree" > "$worktree_config"
worktree_output=$(cdp-status "$worktree_config" 2>&1)
assert_contains "$worktree_output" "LinkedWorktree"
assert_contains "$worktree_output" "clean"
if [[ "$worktree_output" == *"not a git repo"* ]]; then
    echo "Linked worktree was reported as non-Git." >&2
    exit 1
fi

printf 'changed\n' > "$linked_worktree/tracked.txt"
printf 'new\n' > "$linked_worktree/untracked.txt"
mixed_output=$(cdp-status "$worktree_config" 2>&1)
assert_contains "$mixed_output" "1 dirty + 1 untracked"

dirty_filter_config="$test_root/dirty-filter-projects.json"
printf '[
    {"name":"DirtyProject","rootPath":"%s","enabled":true},
    {"name":"CleanProject","rootPath":"%s","enabled":true}
]\n' "$linked_worktree" "$source_repo" > "$dirty_filter_config"
dirty_filter_output=$(cdp-status --dirty "$dirty_filter_config" 2>&1)
assert_contains "$dirty_filter_output" "(1 projects (dirty only))"

remote_path="$test_root/remote.git"
seed_path="$test_root/seed"
follower_path="$test_root/follower"
init_repo "$seed_path"
printf 'initial\n' > "$seed_path/tracked.txt"
git -C "$seed_path" add tracked.txt
git -C "$seed_path" commit --quiet -m initial
git init --bare --quiet "$remote_path"
git -C "$remote_path" symbolic-ref HEAD refs/heads/main
git -C "$seed_path" remote add origin "$remote_path"
git -C "$seed_path" push --quiet -u origin main
git clone --quiet "$remote_path" "$follower_path"
printf 'second\n' >> "$seed_path/tracked.txt"
git -C "$seed_path" add tracked.txt
git -C "$seed_path" commit --quiet -m second
git -C "$seed_path" push --quiet
git -C "$follower_path" fetch --quiet

behind_config="$test_root/behind-projects.json"
printf '[{"name":"BehindOnly","rootPath":"%s","enabled":true}]\n' "$follower_path" > "$behind_config"
behind_output=$(cdp-status "$behind_config" 2>&1)
assert_contains "$behind_output" "v1"
assert_contains "$behind_output" "1 repos need attention"
if [[ "$behind_output" == *"All projects clean"* ]]; then
    echo "Behind-only repository was summarized as clean." >&2
    exit 1
fi

existing_path="$test_root/existing"
mkdir -p "$existing_path"
fix_config="$test_root/fix-projects.json"
printf '[
    {"name":"Existing","rootPath":"%s","enabled":true},
    {"name":"EnabledMissing","rootPath":"%s","enabled":true},
    {"name":"DisabledMissing","rootPath":"%s","enabled":false}
]\n' \
    "$existing_path" \
    "$test_root/shared-missing" \
    "$test_root/shared-missing" > "$fix_config"

cdp-status --fix --dry-run "$fix_config" >/dev/null
jq -e 'map(.name) == ["Existing", "EnabledMissing", "DisabledMissing"]' "$fix_config" >/dev/null
if cdp-status --fix "$fix_config" >/dev/null 2>&1; then
    echo "status --fix should require --yes" >&2
    exit 1
fi
jq -e 'map(.name) == ["Existing", "EnabledMissing", "DisabledMissing"]' "$fix_config" >/dev/null
cdp-status --fix --yes "$fix_config" >/dev/null
jq -e 'map(.name) == ["Existing", "DisabledMissing"]' "$fix_config" >/dev/null

converted=$(convert_windows_to_wsl 'C:\Work\api')
[[ "$converted" == '/mnt/c/Work/api' ]]

windows_config="$test_root/windows-projects.json"
windows_workspaces="$test_root/workspaces.json"
printf '[{"name":"WindowsMapped","rootPath":"X:/FixtureRepo","enabled":true}]\n' > "$windows_config"
printf '[{"name":"mapped","projects":["WindowsMapped"]}]\n' > "$windows_workspaces"
convert_windows_to_wsl() {
    if [[ "$1" == 'X:/FixtureRepo' ]]; then
        printf '%s\n' "$linked_worktree"
    else
        printf '%s\n' "$1"
    fi
}

windows_status=$(cdp-status "$windows_config" 2>&1)
assert_contains "$windows_status" "WindowsMapped"
assert_contains "$windows_status" "1 dirty + 1 untracked"
if [[ "$windows_status" == *"path missing"* || "$windows_status" == *"not a git repo"* ]]; then
    echo "Windows project path was not resolved before status inspection." >&2
    exit 1
fi

fake_bin="$test_root/fake-bin"
tmux_log="$test_root/tmux.log"
mkdir -p "$fake_bin"
printf '%s\n' \
    '#!/bin/sh' \
    'printf "<%s>" "$@" >> "$CDP_TEST_TMUX_LOG"' \
    'printf "\n" >> "$CDP_TEST_TMUX_LOG"' > "$fake_bin/tmux"
chmod +x "$fake_bin/tmux"
workspace_output=$(
    export CDP_TEST_TMUX_LOG="$tmux_log"
    export PATH="$fake_bin:$PATH"
    cdp-workspace mapped --config "$windows_config" 2>&1
)
assert_contains "$workspace_output" "Opened window: WindowsMapped"
tmux_calls="$(cat "$tmux_log")"
assert_contains "$tmux_calls" "<-c><$linked_worktree>"

echo "cdp status shell tests: ok"
