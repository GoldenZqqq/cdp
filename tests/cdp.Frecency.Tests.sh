#!/usr/bin/env bash

set -euo pipefail

script_path="$0"
if [[ -n "${BASH_SOURCE:-}" ]]; then script_path="${BASH_SOURCE[0]}"; fi
repo_root="$(cd "$(dirname "$script_path")/.." && pwd)"
fixture="$repo_root/tests/fixtures/frecency-ranking.json"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-frecency-tests.XXXXXX")"
trap 'rm -rf -- "$test_root"' EXIT

config_path="$test_root/projects.json"
state_path="$test_root/state.json"
jq '.projects' "$fixture" > "$config_path"
jq '{recentProjects}' "$fixture" > "$state_path"
export CDP_STATE_PATH="$state_path"
source "$repo_root/src/cdp.sh"

if [[ -n "${BASH_VERSION:-}" ]]; then
    COMP_WORDS=(cdp recent r)
    COMP_CWORD=2
    _cdp_completions
    [[ " ${COMPREPLY[*]} " == *' reset '* ]]
    COMP_WORDS=(cdp recent reset --)
    COMP_CWORD=3
    _cdp_completions
    [[ " ${COMPREPLY[*]} " == *' --yes '* ]]
fi

assert_equal() {
    [[ "$1" == "$2" ]] || { printf 'Expected:\n%s\nActual:\n%s\n' "$1" "$2" >&2; exit 1; }
}

now_epoch=$(jq -r '.nowEpoch' "$fixture")
expected=$(jq -r '.expected[]' "$fixture")
disabled_expected=$(jq -r '.disabledExpected[]' "$fixture")
actual=$(sorted_enabled_project_names "$config_path" "$now_epoch")
assert_equal "$expected" "$actual"

CDP_FRECENCY=False
actual=$(sorted_enabled_project_names "$config_path" "$now_epoch")
assert_equal "$disabled_expected" "$actual"
unset CDP_FRECENCY

fuzzy_matches=$(find_project_matches "$config_path" unpinned "$now_epoch")
alias_matches=$(find_project_matches "$config_path" shared "$now_epoch")
tag_matches=$(find_project_matches "$config_path" @group "$now_epoch")
expected_matches=$(printf '%s\n' UnpinnedCurrent UnpinnedOld)
assert_equal "$expected_matches" "$fuzzy_matches"
assert_equal "$expected_matches" "$alias_matches"
assert_equal "$expected_matches" "$tag_matches"

printf '{invalid\n' > "$state_path"
actual=$(sorted_enabled_project_names "$config_path" "$now_epoch")
assert_equal "$disabled_expected" "$actual"

jq -n '{recentProjects:[range(0;12000) | {
    name:("History" + tostring), rootPath:("/fixture/history-" + tostring),
    lastVisitedAt:"2026-01-01T00:00:00Z", visitCount:1
}]}' > "$state_path"
sorted_enabled_project_names "$config_path" "$now_epoch" >/dev/null

jq -n '{futureField:"preserve-me",recentProjects:[{
    name:"Api",rootPath:"/api",lastVisitedAt:"2026-01-01T00:00:00Z",visitCount:1
}]}' > "$state_path"
before_hash=$(cdp_sha256_file "$state_path")
preview=$(cdp recent reset --dry-run)
[[ "$preview" == *'status=preview'* ]]
assert_equal "$before_hash" "$(cdp_sha256_file "$state_path")"

set +e
denied=$(cdp recent reset 2>&1)
denied_status=$?
set -e
[[ "$denied_status" -ne 0 ]]
[[ "$denied" == *'status=canceled'* ]]
assert_equal "$before_hash" "$(cdp_sha256_file "$state_path")"

result=$(cdp recent reset --yes)
[[ "$result" == *'status=succeeded'* ]]
jq -e '.futureField == "preserve-me" and .recentProjects == []' "$state_path" >/dev/null
after_hash=$(cdp_sha256_file "$state_path")
backup_count=$(find "$test_root" -maxdepth 1 -name 'state.json.cdp-backup.*' | wc -l | tr -d ' ')
noop=$(cdp recent reset)
[[ "$noop" == *'status=skipped'* ]]
assert_equal "$after_hash" "$(cdp_sha256_file "$state_path")"
assert_equal "$backup_count" "$(find "$test_root" -maxdepth 1 -name 'state.json.cdp-backup.*' | wc -l | tr -d ' ')"

printf '{invalid\n' > "$state_path"
invalid_hash=$(cdp_sha256_file "$state_path")
set +e
invalid=$(cdp recent reset --yes)
invalid_status=$?
set -e
[[ "$invalid_status" -ne 0 ]]
[[ "$invalid" == *'error=invalid-state'* ]]
assert_equal "$invalid_hash" "$(cdp_sha256_file "$state_path")"

printf '{"recentProjects":{"rootPath":"/api"}}\n' > "$state_path"
scalar_hash=$(cdp_sha256_file "$state_path")
set +e
scalar=$(cdp recent reset --yes)
scalar_status=$?
set -e
[[ "$scalar_status" -ne 0 ]]
[[ "$scalar" == *'error=invalid-state'* ]]
assert_equal "$scalar_hash" "$(cdp_sha256_file "$state_path")"

echo 'cdp frecency shell tests: ok'
