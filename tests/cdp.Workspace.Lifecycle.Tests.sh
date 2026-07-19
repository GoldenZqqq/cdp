#!/usr/bin/env sh

set -eu
set -o pipefail

script_path="$0"
if [[ -n "${BASH_SOURCE:-}" ]]; then script_path="${BASH_SOURCE[0]}"; fi
repo_root="$(CDPATH= cd -- "$(dirname -- "$script_path")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-workspace-lifecycle.XXXXXX")"
trap 'rm -rf -- "$test_root"' EXIT INT TERM

export HOME="$test_root/home"
mkdir -p "$HOME" "$test_root/api" "$test_root/web project" "$test_root/bin"
source "$repo_root/src/cdp.sh"

fail() { echo "FAIL: $*" >&2; return 1; }
assert_contains() { case "$1" in *"$2"*) ;; *) fail "expected '$2' in: $1" ;; esac; }
assert_status() { local expected="$1"; shift; set +e; "$@" >/dev/null 2>&1; local actual=$?; set -e; [[ $actual -eq $expected ]] || fail "expected status $expected, got $actual: $*"; }

config_path="$test_root/projects.json"
workspace_path="$test_root/workspaces.json"
jq -n --arg api "$test_root/api" --arg web "$test_root/web project" '[
  {name:"api",rootPath:$api,enabled:true},
  {name:"web",rootPath:$web,enabled:true}
]' > "$config_path"

cdp-workspace add team api web --open codex --layout split-horizontal --config "$config_path" >/dev/null
jq -e --arg api "$test_root/api" --arg web "$test_root/web project" '
  length == 1 and .[0].layout == {mode:"split",direction:"horizontal"} and
  (.[0].projects | map(.name)) == ["api","web"] and
  (.[0].projects | map(.rootPath)) == [$api,$web]
' "$workspace_path" >/dev/null

show_output=$(cdp-workspace show team --config "$config_path" 2>&1)
assert_contains "$show_output" 'Workspace: team'
assert_contains "$show_output" 'Layout: split-horizontal'
assert_contains "$show_output" 'api [ok]'

jq '.[0].futureWorkspace="keep-workspace" | .[0].projects[1].futureReference="keep-reference"' \
    "$workspace_path" > "$workspace_path.next"
mv "$workspace_path.next" "$workspace_path"
cdp-workspace edit team web --clear-open --layout tabs --config "$config_path" >/dev/null
jq -e '.[0].futureWorkspace == "keep-workspace" and .[0].layout.mode == "tabs" and
  (.[0] | has("open") | not) and (.[0].projects | map(.name)) == ["web"]' "$workspace_path" >/dev/null

jq -n --arg api "$test_root/api" --arg web "$test_root/web project" '[{
  name:"migration",futureWorkspace:"keep-workspace",projects:[
    "api",
    {name:"old-web",rootPath:$web,open:"code",size:40,futureReference:"keep-reference"},
    {name:"api",rootPath:"C:/Deleted/api",futureMissing:"keep-missing"},
    null,
    ""
  ]
}]' > "$workspace_path"
set +e
validation_output=$(cdp-workspace validate migration --fix --config "$config_path" 2>&1)
validation_status=$?
set -e
[[ $validation_status -ne 0 ]] || fail 'validate fix should retain an unresolved reference failure'
assert_contains "$validation_output" 'legacy'
assert_contains "$validation_output" 'renamed'
assert_contains "$validation_output" 'missing-project'
jq -e --arg api "$test_root/api" '
  .[0].futureWorkspace == "keep-workspace" and
  .[0].projects[0] == {name:"api",rootPath:$api} and
  .[0].projects[1].name == "web" and .[0].projects[1].open == "code" and
  .[0].projects[1].size == 40 and .[0].projects[1].futureReference == "keep-reference" and
  .[0].projects[2].rootPath == "C:/Deleted/api" and .[0].projects[2].futureMissing == "keep-missing" and
  (.[0].projects | length) == 5 and .[0].projects[3] == null and .[0].projects[4] == ""
' "$workspace_path" >/dev/null

jq '.[0].projects |= .[0:2]' "$workspace_path" > "$workspace_path.next"
mv "$workspace_path.next" "$workspace_path"
before_hash=$(cdp_sha256_file "$workspace_path")
no_change=$(cdp-workspace validate migration --fix --config "$config_path" 2>&1)
assert_contains "$no_change" 'status=skipped'
[[ "$(cdp_sha256_file "$workspace_path")" == "$before_hash" ]] || fail 'no-op validate fix rewrote workspaces.json'

edit_preview=$(cdp-workspace edit migration api --dry-run --config "$config_path" 2>&1)
remove_preview=$(cdp-workspace remove migration --dry-run --config "$config_path" 2>&1)
assert_contains "$edit_preview" 'status=preview'
assert_contains "$remove_preview" 'status=preview'
[[ "$(cdp_sha256_file "$workspace_path")" == "$before_hash" ]] || fail 'workspace dry-run changed workspaces.json'

jq -n --arg api "$test_root/api" --arg web "$test_root/web project" '[{
  name:"invalid",open:"codex;echo",layout:{mode:"split",direction:"diagonal"},projects:[
    {name:"api",rootPath:$api,size:9},
    {name:"web",rootPath:$web,size:40.5},
    {name:"broken"}
  ]
}]' > "$workspace_path"
set +e
invalid_output=$(cdp-workspace validate invalid --config "$config_path" 2>&1)
invalid_status=$?
set -e
[[ $invalid_status -ne 0 ]] || fail 'invalid workspace validation succeeded'
assert_contains "$invalid_output" 'invalid-layout'
assert_contains "$invalid_output" 'invalid-launcher'
assert_contains "$invalid_output" 'invalid-size'
assert_contains "$invalid_output" 'invalid-reference'

cat > "$test_root/bin/tmux" <<'TMUX'
#!/bin/sh
printf 'CALL' >> "$CDP_TEST_TMUX_LOG"
for argument in "$@"; do printf '<%s>' "$argument" >> "$CDP_TEST_TMUX_LOG"; done
printf '\n' >> "$CDP_TEST_TMUX_LOG"
exit 0
TMUX
chmod +x "$test_root/bin/tmux"
tmux_log="$test_root/tmux.log"
export CDP_TEST_TMUX_LOG="$tmux_log"

jq -n --arg api "$test_root/api" --arg web "$test_root/web project" '[{
  name:"split",open:"codex",layout:{mode:"split",direction:"horizontal"},projects:[
    {name:"old-api",rootPath:$api},
    {name:"web",rootPath:$web,open:"code",size:40}
  ]
}]' > "$workspace_path"
PATH="$test_root/bin:$PATH" cdp-workspace open split --yes --config "$config_path" >/dev/null
tmux_calls=$(cat "$tmux_log")
assert_contains "$tmux_calls" "CALL<new-session><-d><-s><cdp-split><-c><$test_root/api><-n><api><codex>"
assert_contains "$tmux_calls" "CALL<split-window><-t><cdp-split><-h><-p><40><-c><$test_root/web project><code><.>"

override_output=$(PATH="$test_root/bin:$PATH" cdp-workspace open split --open cursor --dry-run --config "$config_path" 2>&1)
assert_contains "$override_output" 'api [renamed]'
assert_contains "$override_output" 'launcher=cursor'

: > "$tmux_log"
jq -n --arg api "$test_root/api" '[{
  name:"partial",projects:[
    {name:"deleted",rootPath:"C:/Deleted/project"},
    {name:"api",rootPath:$api}
  ]
}]' > "$workspace_path"
set +e
partial_output=$(PATH="$test_root/bin:$PATH" cdp-workspace open partial --yes --config "$config_path" 2>&1)
partial_status=$?
set -e
[[ $partial_status -ne 0 ]] || fail 'partial workspace failure returned success'
assert_contains "$partial_output" 'missing-project'
assert_contains "$partial_output" 'Opened workspace item: api'
assert_contains "$(cat "$tmux_log")" "<-n><api>"

: > "$tmux_log"
jq -n --arg api "$test_root/api" '[{name:"bad-layout",layout:{mode:"split",direction:"diagonal"},projects:[{name:"api",rootPath:$api}]}]' > "$workspace_path"
assert_status 1 env PATH="$test_root/bin:$PATH" CDP_TEST_TMUX_LOG="$tmux_log" bash -c 'source "$1"; cdp-workspace open bad-layout --yes --config "$2"' _ "$repo_root/src/cdp.sh" "$config_path"
[[ ! -s "$tmux_log" ]] || fail 'invalid layout created a tmux process'

assert_status 1 cdp-workspace edit team --open codex --clear-open --config "$config_path"
assert_status 1 cdp-workspace validate --dry-run --config "$config_path"
assert_status 1 cdp-workspace show team --yes --config "$config_path"

echo "cdp workspace lifecycle shell tests: ok"
