#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-cli-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

source "$repo_root/src/cdp.sh"

assert_failure_contains() {
    local expected="$1"
    shift
    local output=""
    if output=$("$@" 2>&1); then
        echo "Expected command to fail: $*" >&2
        return 1
    fi
    case "$output" in
        *"$expected"*) ;;
        *)
            echo "Expected failure containing '$expected', got: $output" >&2
            return 1
            ;;
    esac
}

assert_failure_contains "--fix and --push cannot be used together" cdp-status --fix --push
assert_failure_contains "--dirty cannot be combined" cdp-status --dirty --fix
assert_failure_contains "unknown status option" cdp-status --unknown
assert_failure_contains "require --fix or --push" cdp-status --yes
assert_failure_contains "cannot be used together" cdp-status --fix --dry-run --yes
assert_failure_contains "cannot be used together" cdp-status --json --no-color
assert_failure_contains "read-only status" cdp-status --json --fix
assert_failure_contains "read-only status" cdp-status --no-color --push
assert_failure_contains "missing value after --open" cdp-workspace --add team api --open
assert_failure_contains "single executable name" cdp-workspace --add team api --open 'codex;echo'

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required for the successful workspace parser test." >&2
    exit 1
fi

config_path="$test_root/projects.json"
workspace_path="$test_root/workspaces.json"
mkdir -p "$test_root/api" "$test_root/web"
printf '[{"name":"api","rootPath":"%s","enabled":true},{"name":"web","rootPath":"%s","enabled":true}]\n' \
    "$test_root/api" "$test_root/web" > "$config_path"

cdp-workspace --add team api web --open codex --config "$config_path"

jq -e '
    length == 1 and
    .[0].name == "team" and
    (.[0].projects | map(.name)) == ["api", "web"] and
    (.[0].projects | map(.rootPath)) == [$api, $web] and
    .[0].open == "codex"
' --arg api "$test_root/api" --arg web "$test_root/web" "$workspace_path" >/dev/null

echo "cdp CLI parser shell tests: ok"
