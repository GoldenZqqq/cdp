#!/usr/bin/env bash

set -eu
set -o pipefail

script_path="$0"
if [[ -n "${BASH_SOURCE:-}" ]]; then script_path="${BASH_SOURCE[0]}"; fi
repo_root="$(CDPATH= cd -- "$(dirname -- "$script_path")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-exec-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
export CDP_PATH_PROFILE=linux
mkdir -p "$HOME" "$test_root/api" "$test_root/web" "$test_root/disabled"
source "$repo_root/src/cdp.sh"

fail() {
    printf 'exec test failed: %s\n' "$*" >&2
    exit 1
}

assert_eq() {
    local actual="$1" expected="$2" label="$3"
    [[ "$actual" == "$expected" ]] || fail "$label (expected '$expected', got '$actual')"
}

config_path="$test_root/projects.json"
jq -n --arg api "$test_root/api" --arg web "$test_root/web" --arg disabled "$test_root/disabled" '[
  {name:"api",rootPath:$api,enabled:true,tags:["Work"]},
  {name:"web",rootPath:$web,enabled:true,tags:["work"]},
  {name:"disabled",rootPath:$disabled,enabled:false,tags:["work"]}
]' > "$config_path"

cdp_exec_parse api -- sh --json 'path with spaces' ';touch marker' ''
assert_eq "$CDP_EXEC_JSON" false 'command argv json isolation'
assert_eq "${#CDP_EXEC_ARGUMENTS[@]}" 4 'argv length preservation'
assert_eq "${CDP_EXEC_ARGUMENTS[1]}" 'path with spaces' 'space argument preservation'
assert_eq "${CDP_EXEC_ARGUMENTS[3]}" '' 'empty argument preservation'

empty_config_code=0
cdp exec api --config '' --dry-run -- sh >"$test_root/empty-config.out" 2>"$test_root/empty-config.err" || empty_config_code=$?
assert_eq "$empty_config_code" 3 'empty config path rejection'

json=$(cdp exec api web api --config "$config_path" --json --dry-run -- sh -c 'exit 0')
assert_eq "$(jq -r '.results | map(.name) | join(",")' <<< "$json")" 'api,web' 'explicit order and dedup'
assert_eq "$(jq -r '.selector.value | join(",")' <<< "$json")" 'api,web,api' 'explicit selector document'

json=$(cdp exec @wOrK --config "$config_path" --json --dry-run -- sh -c 'exit 0')
assert_eq "$(jq -r '.results | map(.name) | join(",")' <<< "$json")" 'api,web' 'tag selection order'
json=$(cdp exec --all --config "$config_path" --json --dry-run -- sh -c 'exit 0')
assert_eq "$(jq -r '.results | map(.name) | join(",")' <<< "$json")" 'api,web' 'all selection order'

mkdir -p "$test_root/renamed" "$test_root/legacy"
workspace_config="$test_root/workspace-projects.json"
jq -n --arg renamed "$test_root/renamed" --arg legacy "$test_root/legacy" \
    --arg disabled "$test_root/disabled" --arg invalid "$test_root/invalid" \
    --arg missing "$test_root/missing" --arg ambiguous "$test_root/ambiguous" '[
  {name:"renamed",rootPath:$renamed,enabled:true},
  {name:"legacy",rootPath:$legacy,enabled:true},
  {name:"disabled",rootPath:$disabled,enabled:false},
  {name:"invalid",rootPath:$invalid,enabled:true,paths:{linux:""}},
  {name:"missing",rootPath:$missing,enabled:true},
  {name:"dupA",rootPath:$ambiguous,enabled:true},
  {name:"dupB",rootPath:$ambiguous,enabled:true}
]' > "$workspace_config"
jq -n --arg renamed "$test_root/renamed" --arg disabled "$test_root/disabled" \
    --arg invalid "$test_root/invalid" --arg missing "$test_root/missing" --arg ambiguous "$test_root/ambiguous" '[{
  name:"team",projects:[
    {name:"old",rootPath:$renamed,size:9,open:"bad;launcher"},
    "legacy",
    {name:"gone",rootPath:"raw/missing"},
    {name:"duplicate",rootPath:$ambiguous},
    {name:"disabled",rootPath:$disabled},
    {name:"invalid",rootPath:$invalid},
    {name:"missing",rootPath:$missing},
    {name:"again",rootPath:$renamed}
  ]
}]' > "$test_root/workspaces.json"
json=$(cdp exec --workspace team --config "$workspace_config" --json --dry-run -- sh -c 'exit 0' || true)
assert_eq "$(jq -r '.results | map(.name) | join(",")' <<< "$json")" \
    'renamed,legacy,gone,duplicate,disabled,invalid,missing' 'workspace stable reference order'
assert_eq "$(jq -r '.results | map(.status) | join(",")' <<< "$json")" \
    'planned,planned,missing_project,ambiguous_project,disabled_project,path_profile_invalid,path_missing' \
    'workspace unavailable statuses'

probe="$test_root/argv-probe.sh"
cat > "$probe" <<'SH'
#!/bin/sh
printf 'cwd=%s\n' "$PWD"
printf 'count=%s\n' "$#"
for value in "$@"; do printf '<%s>\n' "$value"; done
SH
chmod +x "$probe"
marker="$test_root/injected.txt"
json=$(cdp exec api --config "$config_path" --json --yes -- "$probe" 'path with spaces' ";touch $marker" '')
assert_eq "$(jq -r '.results[0].status' <<< "$json")" succeeded 'native argv execution'
assert_eq "$(jq -r '.results[0].stdout' <<< "$json")" \
    "cwd=$test_root/api
count=3
<path with spaces>
<;touch $marker>
<>" 'native argv capture'
[[ ! -e "$marker" ]] || fail 'metacharacter argument was evaluated'

continue_json=$(cdp exec --all --config "$config_path" --jobs 1 --json --yes -- sh -c \
    'case "$PWD" in *api) exit 7;; esac; exit 0' || true)
assert_eq "$(jq -r '.results | map(.status) | join(",")' <<< "$continue_json")" \
    'failed,succeeded' 'continue mode'
assert_eq "$(jq -r '.summary.exitCode' <<< "$continue_json")" 1 'continue exit code'

fast_code=0
fast_json=$(cdp exec --all --config "$config_path" --jobs 1 --fail-fast --json --yes -- sh -c \
    'case "$PWD" in *api) exit 7;; esac; exit 0') || fast_code=$?
assert_eq "$fast_code" 2 'fail-fast process exit code'
assert_eq "$(jq -r '.results | map(.status) | join(",")' <<< "$fast_json")" \
    'failed,canceled' 'fail-fast cancellation'

preflight_code=0
preflight=$(cdp exec disabled api --config "$config_path" --fail-fast --json --yes -- sh -c 'exit 0') || preflight_code=$?
assert_eq "$preflight_code" 2 'preflight fail-fast exit code'
assert_eq "$(jq -r '.results | map(.status) | join(",")' <<< "$preflight")" \
    'disabled_project,canceled' 'preflight fail-fast cancellation'

timeout_code=0
timeout_json=$(cdp exec api --config "$config_path" --timeout 1 --json --yes -- sh -c 'sleep 2') || timeout_code=$?
assert_eq "$timeout_code" 1 'timeout exit code'
assert_eq "$(jq -r '.results[0].status' <<< "$timeout_json")" timed_out 'timeout status'

no_yes_out="$test_root/no-yes.out"; no_yes_err="$test_root/no-yes.err"; no_yes_code=0
cdp exec api --config "$config_path" -- sh -c "printf x > '$marker'" >"$no_yes_out" 2>"$no_yes_err" || no_yes_code=$?
assert_eq "$no_yes_code" 3 'missing approval exit code'
[[ ! -s "$no_yes_out" ]] || fail 'missing approval wrote stdout'
[[ ! -e "$marker" ]] || fail 'missing approval created side effect'

dry_json=$(cdp exec api --config "$config_path" --json --dry-run -- sh -c "printf x > '$marker'")
assert_eq "$(jq -r '.results[0].status' <<< "$dry_json")" planned 'dry-run planned status'
[[ ! -e "$marker" ]] || fail 'dry-run created side effect'

fatal_out="$test_root/fatal.out"; fatal_err="$test_root/fatal.err"; fatal_code=0
cdp exec gone --config "$config_path" --json --dry-run -- sh -c 'exit 0' >"$fatal_out" 2>"$fatal_err" || fatal_code=$?
assert_eq "$fatal_code" 3 'fatal selector exit code'
[[ ! -s "$fatal_out" ]] || fail 'fatal JSON path wrote stdout'
grep -q 'not found' "$fatal_err" || fail 'fatal selector diagnostic missing'

printf '%s\n' '{"name":"api","rootPath":"/tmp/api","enabled":true}' > "$test_root/object-projects.json"
object_code=0
cdp exec api --config "$test_root/object-projects.json" --json --dry-run -- sh >"$test_root/object.out" 2>"$test_root/object.err" || object_code=$?
assert_eq "$object_code" 3 'non-array config rejection'
[[ ! -s "$test_root/object.out" ]] || fail 'non-array config wrote JSON stdout'

CDP_EXEC_CONCURRENCY=3 CDP_EXEC_TIMEOUT_SECONDS=42 \
    json=$(cdp exec api --config "$config_path" --json --dry-run -- sh -c 'exit 0')
assert_eq "$(jq -r '.options.jobs' <<< "$json")" 3 'environment concurrency default'
assert_eq "$(jq -r '.options.timeoutSeconds' <<< "$json")" 42 'environment timeout default'

echo 'cdp exec shell tests: ok'
