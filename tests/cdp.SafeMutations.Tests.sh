#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-safe-mutations.XXXXXX")"
trap 'rm -rf -- "$test_root"' EXIT

export HOME="$test_root/home"
export CDP_STATE_PATH="$test_root/state.json"
export CDP_HOOK_TRUST_PATH="$test_root/hook-trust.json"
mkdir -p "$HOME" "$HOME/.cdp"
source "$repo_root/src/cdp.sh"

assert_contains() {
    case "$1" in *"$2"*) ;; *) echo "Expected '$2' in '$1'" >&2; exit 1 ;; esac
}
assert_equal() {
    [[ "$1" == "$2" ]] || { echo "Expected '$1', got '$2'" >&2; exit 1; }
}
assert_file_hash() {
    local path="$1" expected="$2" actual
    actual=$(cdp_sha256_file "$path")
    assert_equal "$expected" "$actual"
}

project_path="$test_root/project"
new_project_path="$test_root/new-project"
scan_root="$test_root/scan"
mkdir -p "$project_path" "$new_project_path" "$scan_root/alpha/.git" "$scan_root/beta/.git"
config_path="$test_root/projects.json"
printf '[{"name":"Project","rootPath":"%s","enabled":true,"pinned":false,"aliases":[],"tags":[]}]
' "$project_path" > "$config_path"
export CDP_CONFIG="$config_path"

before_hash=$(cdp_sha256_file "$config_path")
dry_add=$(cdp add NewProject "$new_project_path" "$config_path" --dry-run)
assert_contains "$dry_add" 'status=preview'
assert_file_hash "$config_path" "$before_hash"

dry_pin=$(cdp pin Project "$config_path" --dry-run)
assert_contains "$dry_pin" 'status=preview'
assert_file_hash "$config_path" "$before_hash"

dry_alias=$(cdp alias Project alias "$config_path" --dry-run)
assert_contains "$dry_alias" 'status=preview'
assert_file_hash "$config_path" "$before_hash"

printf '[{"name":"Project","rootPath":"%s","enabled":true}]
' "$project_path" > "$config_path"
clean_before=$(cdp_sha256_file "$config_path")
set +e
denied_clean=$(cdp clean "$config_path" 2>&1)
denied_clean_status=$?
set -e
[[ $denied_clean_status -ne 0 ]] || { echo 'clean without --yes should fail' >&2; exit 1; }
assert_contains "$denied_clean" 'Action requires explicit confirmation'
assert_file_hash "$config_path" "$clean_before"
clean_dry=$(cdp clean "$config_path" --dry-run)
assert_contains "$clean_dry" 'status=preview'
assert_file_hash "$config_path" "$clean_before"

scan_before=$(cdp_sha256_file "$config_path")
set +e
scan_denied=$(cdp scan "$scan_root" "$config_path" 2>&1)
scan_denied_status=$?
set -e
[[ $scan_denied_status -ne 0 ]] || { echo 'scan without --yes should fail' >&2; exit 1; }
assert_contains "$scan_denied" 'Action requires explicit confirmation'
assert_file_hash "$config_path" "$scan_before"
scan_dry=$(cdp scan "$scan_root" "$config_path" --dry-run)
assert_contains "$scan_dry" 'status=preview'
assert_file_hash "$config_path" "$scan_before"
cdp scan "$scan_root" "$config_path" --yes >/dev/null
assert_equal '3' "$(jq 'length' "$config_path")"

remove_before=$(cdp_sha256_file "$config_path")
remove_dry=$(cdp remove Project "$config_path" --dry-run)
assert_contains "$remove_dry" 'status=preview'
assert_file_hash "$config_path" "$remove_before"
set +e
remove_denied=$(cdp remove Project "$config_path" 2>&1)
remove_denied_status=$?
set -e
[[ $remove_denied_status -ne 0 ]] || { echo 'remove without --yes should fail' >&2; exit 1; }
assert_file_hash "$config_path" "$remove_before"
cdp remove Project "$config_path" --yes >/dev/null
assert_equal '2' "$(jq 'length' "$config_path")"

workspace_config="$test_root/workspace-projects.json"
workspace_file="$test_root/workspaces.json"
printf '[{"name":"Alpha","rootPath":"%s","enabled":true}]
' "$project_path" > "$workspace_config"
workspace_dry=$(cdp workspace --add team Alpha --config "$workspace_config" --dry-run)
assert_contains "$workspace_dry" 'status=preview'
[[ ! -f "$workspace_file" ]] || { echo 'workspace dry-run created a file' >&2; exit 1; }
cdp workspace --add team Alpha --config "$workspace_config" --yes >/dev/null

fake_bin="$test_root/fake-bin"
mkdir -p "$fake_bin"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$fake_bin/tmux"
chmod +x "$fake_bin/tmux"
launch_log="$test_root/launch.log"
set +e
no_approval=$(PATH="$fake_bin:$PATH" CDP_TEST_TMUX_LOG="$launch_log" cdp workspace team --config "$workspace_config" 2>&1)
no_approval_status=$?
set -e
[[ $no_approval_status -ne 0 ]] || { echo 'workspace launch without --yes should fail' >&2; exit 1; }
assert_contains "$no_approval" 'Action requires explicit confirmation'
[[ ! -f "$launch_log" ]] || { echo 'workspace launch wrote output without approval' >&2; exit 1; }
dry_launch=$(PATH="$fake_bin:$PATH" CDP_TEST_TMUX_LOG="$launch_log" cdp workspace team --config "$workspace_config" --dry-run)
assert_contains "$dry_launch" 'status=preview'

hook_config="$test_root/hook-projects.json"
printf '[{"name":"Hook","rootPath":"%s","enabled":true,"onEnter":{"bash":"printf hook"}}]
' "$project_path" > "$hook_config"
hook_dry=$(cdp hook trust Hook --config "$hook_config" --dry-run)
assert_contains "$hook_dry" 'status=preview'
[[ ! -f "$CDP_HOOK_TRUST_PATH" ]] || { echo 'hook trust dry-run wrote trust store' >&2; exit 1; }

config_choice_home="$test_root/config-home"
export HOME="$config_choice_home"
mkdir -p "$HOME/.cdp"
printf '[]\n' > "$HOME/.cdp/projects.json"
cdp-config 1 --dry-run >/dev/null
[[ ! -f "$HOME/.cdp/config" ]] || { echo 'config selection dry-run wrote choice' >&2; exit 1; }
cdp-config 1 --yes >/dev/null
[[ -f "$HOME/.cdp/config" ]] || { echo 'config selection did not persist choice' >&2; exit 1; }

echo 'cdp safe mutation shell tests: ok'
