#!/usr/bin/env bash

set -euo pipefail

script_path="$0"
if [[ -n "${BASH_SOURCE:-}" ]]; then script_path="${BASH_SOURCE[0]}"; fi
repo_root="$(cd "$(dirname "$script_path")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-status-json-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/clean" "$test_root/dirty" "$test_root/plain"
for repository in clean dirty; do
    git -C "$test_root/$repository" init -q
    git -C "$test_root/$repository" config user.email tests@example.invalid
    git -C "$test_root/$repository" config user.name 'cdp tests'
    printf 'initial\n' > "$test_root/$repository/tracked.txt"
    git -C "$test_root/$repository" add tracked.txt
    git -C "$test_root/$repository" commit -qm initial
done
printf 'changed\n' >> "$test_root/dirty/tracked.txt"
printf 'new\n' > "$test_root/dirty/untracked.txt"

cat > "$test_root/projects.json" <<JSON
[
  {"name":"Clean","rootPath":"$test_root/clean","enabled":true},
  {"name":"Dirty","rootPath":"$test_root/dirty","enabled":true},
  {"name":"Plain","rootPath":"$test_root/plain","enabled":true},
  {"name":"Missing","rootPath":"$test_root/missing","enabled":true}
]
JSON
printf '[{"name":"Clean","rootPath":"%s","enabled":true}]\n' \
    "$test_root/clean" > "$test_root/clean-projects.json"
printf '[]\n' > "$test_root/empty-projects.json"

run_status_json() {
    local shell_name="$1" output_path="$2" error_path="$3" code_path="$4"
    set +e
    "$shell_name" -c 'source "$1/src/cdp.sh"; cdp-status --json "$2"' \
        _ "$repo_root" "$test_root/projects.json" > "$output_path" 2> "$error_path"
    printf '%s' "$?" > "$code_path"
    set -e
}

run_status_json bash "$test_root/bash.json" "$test_root/bash.err" "$test_root/bash.code"
run_status_json zsh "$test_root/zsh.json" "$test_root/zsh.err" "$test_root/zsh.code"

[[ "$(cat "$test_root/bash.code")" == 1 ]] || { echo 'bash JSON attention exit code must be 1' >&2; exit 1; }
[[ "$(cat "$test_root/zsh.code")" == 1 ]] || { echo 'zsh JSON attention exit code must be 1' >&2; exit 1; }
[[ ! -s "$test_root/bash.err" && ! -s "$test_root/zsh.err" ]] || { echo 'successful JSON scan wrote diagnostics to stderr' >&2; exit 1; }

jq -e '
  .schemaVersion == 1 and
  .summary == {total:4,shown:4,attention:2,partialFailures:0,exitCode:1} and
  (.projects | map(.status)) == ["clean","changed","not_git","path_missing"] and
  .projects[1].attentionReasons == ["dirty","untracked"] and
  .projects[1].git.dirtyCount == 1 and .projects[1].git.untrackedCount == 1 and
  .projects[3].attentionReasons == ["path_missing"] and
  (.projects | all(.rawPath == .resolvedPath))
' "$test_root/bash.json" >/dev/null
jq -S -c '{schemaVersion,projects:[.projects[]|{
      name,status,needsAttention,attentionReasons,errorCode:(.error.code // null),
      isRepository:.git.isRepository,dirtyCount:.git.dirtyCount,
      untrackedCount:.git.untrackedCount,aheadCount:.git.aheadCount,behindCount:.git.behindCount
    }]}' "$test_root/bash.json" > "$test_root/bash.contract.json"
jq -S -c . "$repo_root/tests/fixtures/status-json-contract-v1.json" > "$test_root/expected.contract.json"
cmp "$test_root/expected.contract.json" "$test_root/bash.contract.json"

jq 'del(.generatedAt,.durationMs) | .projects[].git.lastCommitRelative = null' \
    "$test_root/bash.json" > "$test_root/bash.normalized.json"
jq 'del(.generatedAt,.durationMs) | .projects[].git.lastCommitRelative = null' \
    "$test_root/zsh.json" > "$test_root/zsh.normalized.json"
cmp "$test_root/bash.normalized.json" "$test_root/zsh.normalized.json"

set +e
bash -c 'source "$1/src/cdp.sh"; cdp-status --json "$2"' \
    _ "$repo_root" "$test_root/clean-projects.json" > "$test_root/clean.json" 2> "$test_root/clean.err"
clean_code=$?
set -e
[[ $clean_code -eq 0 && ! -s "$test_root/clean.err" ]] || { echo 'clean JSON exit code must be 0' >&2; exit 1; }
jq -e '.summary.exitCode == 0 and .summary.attention == 0' "$test_root/clean.json" >/dev/null

bash -c 'source "$1/src/cdp.sh"; cdp-status --json "$2"' \
    _ "$repo_root" "$test_root/empty-projects.json" > "$test_root/empty.json" 2> "$test_root/empty.err"
[[ ! -s "$test_root/empty.err" ]] || { echo 'empty JSON scan wrote diagnostics' >&2; exit 1; }
jq -e '.summary.total == 0 and .summary.exitCode == 0 and .projects == []' "$test_root/empty.json" >/dev/null

set +e
bash -c 'source "$1/src/cdp.sh"; cdp-status --json --dirty "$2"' \
    _ "$repo_root" "$test_root/projects.json" > "$test_root/dirty.json" 2> "$test_root/dirty.err"
dirty_code=$?
set -e
[[ $dirty_code -eq 1 ]] || { echo 'dirty JSON exit code must be 1' >&2; exit 1; }
jq -e '.summary.total == 4 and .summary.shown == 2 and (.projects | map(.name)) == ["Dirty","Missing"]' \
    "$test_root/dirty.json" >/dev/null

set +e
bash -c 'source "$1/src/cdp.sh"; cdp-status --json "$2"' \
    _ "$repo_root" "$test_root/missing-config.json" > "$test_root/fatal.out" 2> "$test_root/fatal.err"
fatal_code=$?
set -e
[[ $fatal_code -eq 3 && ! -s "$test_root/fatal.out" ]] || { echo 'fatal JSON boundary must use code 3 and empty stdout' >&2; exit 1; }
grep -F 'Configuration file not found' "$test_root/fatal.err" >/dev/null

plain_output=$(bash -c 'source "$1/src/cdp.sh"; cdp-status --no-color "$2"' \
    _ "$repo_root" "$test_root/projects.json" 2>&1)
if printf '%s' "$plain_output" | grep -q $'\033'; then
    echo 'no-color output contains ANSI escapes' >&2
    exit 1
fi

run_partial_fixture() {
    local shell_name="$1"
    set +e
    "$shell_name" -c '
      source "$1/src/cdp.sh"
      total=2
      names=(Broken Slow); raw_paths=(/broken /slow); paths=(/broken /slow)
      record_kinds=(failed timed-out); branches=(- -); last_commits=("" "")
      dirty_counts=(0 0); untracked_counts=(0 0); ahead_counts=(0 0)
      behind_counts=(0 0); needs_attention=(true true)
      dirty_only=false; tag_filter=""; refresh=false
      cdp_status_render_json 1
    ' _ "$repo_root" > "$test_root/$shell_name-partial.json"
    local code=$?
    set -e
    [[ $code -eq 2 ]] || { echo "$shell_name partial failure exit code must be 2" >&2; exit 1; }
    jq -e '.summary.partialFailures == 2 and .summary.exitCode == 2 and
      .projects[0].error.code == "scan_failed" and .projects[1].error.code == "scan_timeout"' \
        "$test_root/$shell_name-partial.json" >/dev/null
}

run_partial_fixture bash
run_partial_fixture zsh

echo "cdp status JSON shell tests: ok"
