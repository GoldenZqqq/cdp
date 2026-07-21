#!/usr/bin/env bash

set -euo pipefail

script_path="$0"
if [[ -n "${BASH_SOURCE:-}" ]]; then script_path="${BASH_SOURCE[0]}"; fi
repo_root="$(cd "$(dirname "$script_path")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-launcher-safety.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
source "$repo_root/src/cdp.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "expected '$2' in: $1"; }

project_path="$test_root/project '; special"
config_path="$test_root/projects.json"
state_path="$test_root/state.json"
marker_path="$test_root/hook-marker"
mkdir -p "$project_path"
printf '[{"name":"Unsafe; Project","rootPath":"%s","enabled":true,"onEnter":"touch %s"}]\n' \
    "$project_path" "$marker_path" > "$config_path"

set +e
direct_output=$(
    export CDP_STATE_PATH="$state_path"
    cd "$test_root"
    cdp 'Unsafe; Project' "$config_path" --open 'codex; touch unsafe' 2>&1
)
direct_exit=$?
set -e
[[ $direct_exit -ne 0 ]] || fail 'unsafe direct launcher unexpectedly succeeded'
assert_contains "$direct_output" 'launcher must be'
[[ ! -e "$state_path" && ! -e "$marker_path" ]] || fail 'unsafe direct launcher reached side effects'

set +e
add_output=$(cdp-workspace --add unsafe 'Unsafe; Project' --open custom-tool --config "$config_path" 2>&1)
add_exit=$?
set -e
[[ $add_exit -ne 0 ]] || fail 'unsupported workspace launcher was persisted'
assert_contains "$add_output" 'Unsupported launcher'
[[ ! -e "$test_root/workspaces.json" ]] || fail 'unsafe launcher wrote workspaces.json'

printf '[{"name":"unsafe","projects":["Unsafe; Project"],"open":"custom-tool"}]\n' > "$test_root/workspaces.json"
mkdir -p "$test_root/bin"
cat > "$test_root/bin/tmux" <<'TMUX'
#!/usr/bin/env bash
printf '<%s>' "$@" >> "$CDP_TEST_TMUX_LOG"
printf '\n' >> "$CDP_TEST_TMUX_LOG"
TMUX
chmod +x "$test_root/bin/tmux"
tmux_log="$test_root/tmux.log"
set +e
stored_output=$(PATH="$test_root/bin:$PATH" CDP_TEST_TMUX_LOG="$tmux_log" \
    cdp-workspace unsafe --config "$config_path" 2>&1)
stored_exit=$?
set -e
[[ $stored_exit -ne 0 ]] || fail 'stored unsupported launcher succeeded'
assert_contains "$stored_output" 'invalid-launcher'
[[ ! -s "$tmux_log" ]] || fail 'stored unsupported launcher invoked tmux'

printf '[{"name":"safe","projects":["Unsafe; Project"],"open":"codex"}]\n' > "$test_root/workspaces.json"
dry_output=$(PATH="$test_root/bin:$PATH" CDP_TEST_TMUX_LOG="$tmux_log" \
    cdp-workspace safe --dry-run --config "$config_path" 2>&1)
assert_contains "$dry_output" 'status=preview'
[[ ! -s "$tmux_log" ]] || fail 'workspace dry-run invoked tmux'

echo 'cdp launcher safety shell tests: ok'
