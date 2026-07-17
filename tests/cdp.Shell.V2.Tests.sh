#!/usr/bin/env sh

set -eu
set -o pipefail

if [[ -n "${CDP_TEST_REPO_ROOT:-}" ]]; then
    repo_root="$CDP_TEST_REPO_ROOT"
    script_dir="$repo_root/tests"
else
    script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
    repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
fi
test_tmp_base="$(CDPATH= cd -- "${TMPDIR:-/tmp}" && pwd -P)"
test_root="$(mktemp -d "$test_tmp_base/cdp-shell-v2.XXXXXX")"
case "$test_root" in
    "$test_tmp_base"/cdp-shell-v2.*) ;;
    *) echo "Unexpected test root: $test_root" >&2; exit 1 ;;
esac
trap 'rm -rf -- "$test_root"' EXIT INT TERM

original_home="${HOME:-}"
original_path="$PATH"
export HOME="$test_root/home"
export CDP_STATE_PATH="$test_root/state.json"
mkdir -p "$HOME"

source "$repo_root/src/cdp.sh"

if [[ -n "${CDP_TEST_JQ_EXE:-}" ]] && ! command -v jq >/dev/null 2>&1; then
    test_wslpath_command="$(command -v wslpath)"
    test_tr_command="$(command -v tr)"
    jq_bridge() {
        local -a jq_args
        jq_args=("$@")
        if [[ ${#jq_args[@]} -gt 0 && -f "${jq_args[-1]}" ]]; then
            jq_args[-1]="$("$test_wslpath_command" -w "${jq_args[-1]}")"
        fi
        "$CDP_TEST_JQ_EXE" "${jq_args[@]}" | "$test_tr_command" -d '\r'
    }
    jq() { jq_bridge "$@"; }
    export CDP_TEST_REAL_JQ=jq_bridge
fi

if [[ -n "${CDP_TEST_FAKE_FZF:-}" ]] && ! command -v fzf >/dev/null 2>&1; then
    fzf() { return 0; }
fi

fail() {
    echo "FAIL: $*" >&2
    return 1
}

assert_contains() {
    local value="$1"
    local expected="$2"
    case "$value" in
        *"$expected"*) ;;
        *) fail "expected output containing '$expected', got: $value" ;;
    esac
}

assert_not_contains() {
    local value="$1"
    local unexpected="$2"
    case "$value" in
        *"$unexpected"*) fail "unexpected output '$unexpected', got: $value" ;;
        *) ;;
    esac
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    [[ "$actual" == "$expected" ]] || fail "expected '$expected', got '$actual'"
}

assert_failure_contains() {
    local expected="$1"
    shift
    local output=""
    if output=$("$@" 2>&1); then
        fail "expected command to fail: $*"
    fi
    assert_contains "$output" "$expected"
}

remove_test_function() {
    if [[ -n "${BASH_VERSION:-}" ]]; then
        unset -f "$1" 2>/dev/null || true
    else
        unfunction "$1" 2>/dev/null || true
    fi
}

for dependency in jq git fzf; do
    command -v "$dependency" >/dev/null 2>&1 || fail "required test dependency missing: $dependency"
done
real_jq="${CDP_TEST_REAL_JQ:-$(command -v jq)}"

project_path="$test_root/project with spaces"
legacy_path="$test_root/legacy-project"
mkdir -p "$project_path" "$legacy_path"
config_path="$test_root/projects.json"

MSYS2_ARG_CONV_EXCL='*' jq -n \
    --arg project_path "$project_path" \
    --arg legacy_path "$legacy_path" \
    '[
        {
            "name": "HookProject",
            "rootPath": $project_path,
            "enabled": true,
            "pinned": false,
            "aliases": [],
            "tags": [],
            "onEnter": {
                "bash": "export CDP_TEST_HOOK_BASH=ran",
                "env": {"CDP_TEST_HOOK_ENV": "enabled"}
            }
        },
        {
            "name": "LegacyFailure",
            "rootPath": $legacy_path,
            "enabled": true,
            "pinned": false,
            "aliases": [],
            "tags": [],
            "onEnter": "false"
        },
        {
            "name": "HiddenProject",
            "rootPath": $project_path,
            "enabled": false,
            "pinned": false,
            "aliases": [],
            "tags": []
        }
    ]' > "$config_path"

empty_path="$test_root/empty-path"
mkdir -p "$empty_path"

probe_missing_jq() (
    export PATH="$empty_path"
    remove_test_function jq
    cdp-status "$config_path"
)

probe_missing_git() (
    export PATH="$empty_path"
    jq() { "$real_jq" "$@"; }
    cdp-status "$config_path"
)

probe_missing_fzf() (
    export PATH="$empty_path"
    remove_test_function fzf
    jq() { "$real_jq" "$@"; }
    cdp "$config_path"
)

assert_failure_contains "'jq' command not found" probe_missing_jq
assert_failure_contains "'git' command not found" probe_missing_git
assert_failure_contains "'fzf' command not found" probe_missing_fzf
assert_failure_contains "Configuration file not found" cdp "$test_root/missing-projects.json"

invalid_config="$test_root/invalid-projects.json"
printf '%s\n' '{not-json' > "$invalid_config"
assert_failure_contains "expected a top-level project array" cdp-doctor "$invalid_config"
echo "  dependency and config errors: ok"

(
    cd "$test_root"
    cdp HookProject "$config_path" >/dev/null
    assert_equals "$project_path" "$PWD"
    assert_equals "enabled" "$CDP_TEST_HOOK_ENV"
    assert_equals "ran" "$CDP_TEST_HOOK_BASH"
)

legacy_output=$(cd "$test_root" && cdp LegacyFailure "$config_path" 2>&1)
assert_contains "$legacy_output" "onEnter warning: command failed"

launcher_output=$(
    cd "$test_root"
    export CDP_OPEN_DRY_RUN=1
    cdp HookProject "$config_path" --open codex 2>&1
)
assert_contains "$launcher_output" "Would open HookProject with Codex"

cdp pin HookProject "$config_path" >/dev/null
assert_equals "true" "$(jq -r '.[] | select(.name == "HookProject") | .pinned' "$config_path")"
cdp unpin HookProject "$config_path" >/dev/null
assert_equals "false" "$(jq -r '.[] | select(.name == "HookProject") | .pinned' "$config_path")"
cdp alias HookProject hook "$config_path" >/dev/null
cdp tag HookProject work "$config_path" >/dev/null
(
    cd "$test_root"
    cdp hook "$config_path" >/dev/null
    assert_equals "$project_path" "$PWD"
    cdp '@work' "$config_path" >/dev/null
    assert_equals "$project_path" "$PWD"
)
cdp clean "$config_path" >/dev/null
assert_equals "false" "$(jq -r '.[] | select(.name == "HookProject") | .pinned' "$config_path")"

recent_output=$(cdp recent 5 2>&1)
assert_contains "$recent_output" "HookProject"
assert_equals "HookProject" "$(jq -r '.recentProjects[0].name' "$CDP_STATE_PATH")"

status_output=$(cdp status "$config_path" 2>&1)
assert_contains "$status_output" "HookProject"
assert_contains "$status_output" "not a git repo"
echo "  lifecycle, hooks, and status: ok"

workspace_path="$test_root/workspaces.json"
cdp-workspace --add team HookProject MissingProject --open codex --config "$config_path" >/dev/null
jq -e '
    length == 1 and
    .[0].name == "team" and
    .[0].projects == ["HookProject", "MissingProject"] and
    .[0].open == "codex"
' "$workspace_path" >/dev/null

workspace_list=$(cdp-workspace --list --config "$config_path" 2>&1)
assert_contains "$workspace_list" "team"
assert_contains "$workspace_list" "codex"

fake_bin="$test_root/fake-bin"
tmux_log="$test_root/tmux.log"
mkdir -p "$fake_bin"
printf '%s\n' \
    '#!/bin/sh' \
    'printf "<%s>" "$@" >> "$CDP_TEST_TMUX_LOG"' \
    'printf "\n" >> "$CDP_TEST_TMUX_LOG"' > "$fake_bin/tmux"
chmod +x "$fake_bin/tmux"

workspace_launch=""
if ! workspace_launch=$(
    export CDP_TEST_TMUX_LOG="$tmux_log"
    export PATH="$fake_bin:$PATH"
    cdp-workspace team --config "$config_path" 2>&1
); then
    fail "workspace launch failed: $workspace_launch"
fi
export PATH="$original_path"
command -v basename >/dev/null 2>&1 || fail "basename missing after workspace; PATH=$PATH"
assert_contains "$workspace_launch" "Opened window: HookProject"
assert_contains "$workspace_launch" "Skipping 'MissingProject'"
tmux_calls="$(cat "$tmux_log")"
assert_contains "$tmux_calls" "<new-session><-d><-s><cdp-team><-c><$project_path><-n><HookProject>"
assert_contains "$tmux_calls" "<send-keys><-t><cdp-team><codex><Enter>"
echo "  workspace isolation: ok"

init_root="$test_root/init-repos"
scan_root="$test_root/scan-repos"
mkdir -p "$init_root/gamma/.git" "$scan_root/alpha/.git" "$scan_root/nested/beta/.git"
cdp-init "$init_root" "$test_root/init-projects.json" 2 >/dev/null
assert_equals "1" "$(jq length "$test_root/init-projects.json")"
printf '%s\n' '[]' > "$test_root/scan-projects.json"
cdp-scan "$scan_root" "$test_root/scan-projects.json" 3 >/dev/null
assert_equals "2" "$(jq length "$test_root/scan-projects.json")"
echo "  init and scan: ok"

converted_path="$(convert_windows_to_wsl 'C:\Work\api')"
assert_equals "/mnt/c/Work/api" "$converted_path"

export CDP_CONFIG="$config_path"
if [[ -n "${BASH_VERSION:-}" ]]; then
    COMP_WORDS=(cdp st)
    COMP_CWORD=1
    COMPREPLY=()
    _cdp_completions
    completion_text="${COMPREPLY[*]}"
    assert_contains "$completion_text" "status"

    COMP_WORDS=(cdp wo)
    COMP_CWORD=1
    COMPREPLY=()
    _cdp_completions
    completion_text="${COMPREPLY[*]}"
    assert_contains "$completion_text" "workspace"

    COMP_WORDS=(cdp Hoo)
    COMP_CWORD=1
    COMPREPLY=()
    _cdp_completions
    completion_text="${COMPREPLY[*]}"
    assert_contains "$completion_text" "HookProject"
    assert_not_contains "$completion_text" "HiddenProject"

    COMP_WORDS=(cdp HookProject --open co)
    COMP_CWORD=3
    COMPREPLY=()
    _cdp_completions
    completion_text="${COMPREPLY[*]}"
    assert_contains "$completion_text" "code"
    assert_contains "$completion_text" "codex"
    shell_name="bash"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    typeset -ga CDP_TEST_COMPLETIONS
    compadd() {
        if [[ "${1:-}" == "-a" ]]; then
            local array_name="$2"
            CDP_TEST_COMPLETIONS+=("${(@P)array_name}")
        else
            [[ "${1:-}" == "--" ]] && shift
            CDP_TEST_COMPLETIONS+=("$@")
        fi
    }

    run_zsh_completion() {
        CDP_TEST_COMPLETIONS=()
        _cdp_zsh_complete_words "$#" "$@"
    }

    run_zsh_completion cdp st
    completion_text="${CDP_TEST_COMPLETIONS[*]}"
    assert_contains "$completion_text" "status"

    run_zsh_completion cdp wo
    completion_text="${CDP_TEST_COMPLETIONS[*]}"
    assert_contains "$completion_text" "workspace"

    run_zsh_completion cdp Hoo
    completion_text="${CDP_TEST_COMPLETIONS[*]}"
    assert_contains "$completion_text" "HookProject"
    assert_not_contains "$completion_text" "HiddenProject"

    run_zsh_completion cdp HookProject --open co
    completion_text="${CDP_TEST_COMPLETIONS[*]}"
    assert_contains "$completion_text" "code"
    assert_contains "$completion_text" "codex"
    shell_name="zsh"
else
    fail "unsupported shell"
fi

echo "  completion and path conversion: ok"

export HOME="$original_home"
echo "cdp shell v2 tests ($shell_name): ok"
