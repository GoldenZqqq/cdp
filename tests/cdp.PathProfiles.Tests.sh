#!/usr/bin/env bash

set -euo pipefail

script_path="$0"
if [[ -n "${BASH_SOURCE:-}" ]]; then script_path="${BASH_SOURCE[0]}"; fi
repo_root="$(cd "$(dirname "$script_path")/.." && pwd)"
fixture="$repo_root/tests/fixtures/path-profiles.json"

source "$repo_root/src/cdp.sh"

mapped="$(jq -c '.[0]' "$fixture")"
legacy="$(jq -c '.[1]' "$fixture")"
invalid="$(jq -c '.[2]' "$fixture")"

assert_resolution() {
    local project_json="$1"
    local profile="$2"
    local expected="$3"
    cdp_resolve_project_json "$project_json" "$profile"
    [[ "$CDP_PROJECT_RESOLVED_PATH" == "$expected" ]] || {
        echo "$profile resolution mismatch: $CDP_PROJECT_RESOLVED_PATH" >&2
        exit 1
    }
}

assert_resolution "$mapped" windows 'C:/Work/api'
assert_resolution "$mapped" wsl '/home/dev/api'
assert_resolution "$mapped" linux '/srv/dev/api'
assert_resolution "$mapped" macos '/Users/dev/api'
assert_resolution "$legacy" linux 'D:/Code/legacy'
assert_resolution "$legacy" wsl '/mnt/d/Code/legacy'

set +e
cdp_resolve_project_json "$invalid" linux >/dev/null 2>&1
invalid_code=$?
set -e
[[ $invalid_code -eq 2 ]]
[[ "$CDP_PROJECT_PATH_ERROR_CODE" == path_profile_invalid ]]
[[ -z "$CDP_PROJECT_RESOLVED_PATH" ]]

original_profile="${CDP_PATH_PROFILE:-}"
CDP_PATH_PROFILE=MaCoS
[[ "$(cdp_current_path_profile)" == macos ]]
CDP_PATH_PROFILE=solaris
if cdp_current_path_profile >/dev/null 2>&1; then
    echo 'invalid CDP_PATH_PROFILE was accepted' >&2
    exit 1
fi
CDP_PATH_PROFILE="$original_profile"

new_project="$(CDP_PATH_PROFILE=linux cdp_new_project_json api /work/api)"
jq -e '.rootPath == "/work/api" and .paths.linux == "/work/api"' <<< "$new_project" >/dev/null

test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-path-profile-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/resolved" "$test_root/added"

cat > "$test_root/resolved.json" <<JSON
[{"name":"Resolved","rootPath":"C:/Unavailable/resolved","enabled":true,"paths":{"linux":"$test_root/resolved"}}]
JSON
set +e
CDP_PATH_PROFILE=linux cdp-status --json "$test_root/resolved.json" > "$test_root/status.json"
status_code=$?
set -e
[[ $status_code -eq 0 ]]
jq -e --arg resolved "$test_root/resolved" '
  .projects[0].rawPath == "C:/Unavailable/resolved" and
  .projects[0].resolvedPath == $resolved and .projects[0].status == "not_git"
' "$test_root/status.json" >/dev/null

printf '[]\n' > "$test_root/add.json"
CDP_PATH_PROFILE=linux cdp-add Added "$test_root/added" "$test_root/add.json" >/dev/null
jq -e --arg project_path "$test_root/added" '
  .[0].rootPath == $project_path and .[0].paths.linux == $project_path
' "$test_root/add.json" >/dev/null

cat > "$test_root/no-duplicate.json" <<JSON
[{"name":"Existing","rootPath":"C:/Work/existing","enabled":true,"paths":{"linux":"$test_root/added"}}]
JSON
CDP_PATH_PROFILE=linux cdp-add Duplicate "$test_root/added" "$test_root/no-duplicate.json" >/dev/null
jq -e 'length == 1 and .[0].name == "Existing"' "$test_root/no-duplicate.json" >/dev/null

cat > "$test_root/explicit-missing.json" <<JSON
[{"name":"Shared","rootPath":"C:/Work/shared","enabled":true,"paths":{"linux":"$test_root/missing"},"futureField":"keep-me"}]
JSON
CDP_PATH_PROFILE=linux cdp-tag Shared profile-test "$test_root/explicit-missing.json" >/dev/null
CDP_PATH_PROFILE=linux cdp-clean --yes "$test_root/explicit-missing.json" >/dev/null
CDP_PATH_PROFILE=linux cdp-status --fix --yes "$test_root/explicit-missing.json" >/dev/null
jq -e '. | length == 1 and .[0].enabled == true and .[0].futureField == "keep-me" and (.[0].tags | index("profile-test") != null)' \
  "$test_root/explicit-missing.json" >/dev/null

cat > "$test_root/shared-raw.json" <<JSON
[
  {"name":"LegacyMissing","rootPath":"C:/Shared/raw","enabled":true},
  {"name":"ExplicitExisting","rootPath":"C:/Shared/raw","enabled":true,"paths":{"linux":"$test_root/resolved"}}
]
JSON
CDP_PATH_PROFILE=linux cdp-status --fix --yes "$test_root/shared-raw.json" >/dev/null
jq -e 'map(.name) == ["ExplicitExisting"]' "$test_root/shared-raw.json" >/dev/null

cat > "$test_root/invalid-profile.json" <<JSON
[{"name":"Invalid","rootPath":"C:/Work/invalid","enabled":true,"paths":{"linux":""}}]
JSON
set +e
CDP_PATH_PROFILE=linux cdp-status --json "$test_root/invalid-profile.json" > "$test_root/invalid-profile-status.json"
invalid_profile_status=$?
set -e
[[ $invalid_profile_status -eq 1 ]]
jq -e '.projects[0].status == "path_profile_invalid" and
  .projects[0].attentionReasons == ["path_profile_invalid"] and
  .projects[0].rawPath == "C:/Work/invalid" and .projects[0].resolvedPath == ""' \
  "$test_root/invalid-profile-status.json" >/dev/null
CDP_PATH_PROFILE=linux cdp-status --fix --yes "$test_root/invalid-profile.json" >/dev/null
jq -e 'length == 1' "$test_root/invalid-profile.json" >/dev/null

set +e
CDP_PATH_PROFILE=solaris cdp-status --json "$test_root/resolved.json" \
  > "$test_root/invalid.out" 2> "$test_root/invalid.err"
invalid_status_code=$?
set -e
[[ $invalid_status_code -eq 3 && ! -s "$test_root/invalid.out" ]]
grep -F 'Invalid CDP_PATH_PROFILE' "$test_root/invalid.err" >/dev/null

echo 'cdp path profile shell tests: ok'
