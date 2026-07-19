#!/usr/bin/env bash

set -euo pipefail

script_path="$0"
if [[ -n "${BASH_SOURCE:-}" ]]; then script_path="${BASH_SOURCE[0]}"; fi
repo_root="$(cd "$(dirname "$script_path")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-persistence-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

source "$repo_root/src/cdp.sh"

target="$test_root/projects.json"
candidate="$test_root/candidate.json"
printf '[]\n' > "$target"
original_fingerprint=$(cdp_json_fingerprint "$target")
printf '[{"name":"one"}]\n' > "$candidate"
cdp_commit_json_file "$target" "$candidate" "$original_fingerprint"
jq -e '.[0].name == "one"' "$target" >/dev/null

if cdp_commit_json_file "$target" "$candidate" "$original_fingerprint" >/dev/null 2>&1; then
    echo 'stale fingerprint was accepted' >&2
    exit 1
fi

printf '{\n' > "$candidate"
before_invalid=$(cdp_json_fingerprint "$target")
if cdp_commit_json_file "$target" "$candidate" "$before_invalid" >/dev/null 2>&1; then
    echo 'invalid JSON candidate was accepted' >&2
    exit 1
fi
[[ "$(cdp_json_fingerprint "$target")" == "$before_invalid" ]]

printf '[]\n' > "$candidate"
before_flush=$(cdp_json_fingerprint "$target")
sync() { return 1; }
if cdp_commit_json_file "$target" "$candidate" "$before_flush" >/dev/null 2>&1; then
    echo 'flush failure was ignored' >&2
    exit 1
fi
unset -f sync
[[ "$(cdp_json_fingerprint "$target")" == "$before_flush" ]]
[[ ! -d "$target.cdp.lock" ]]

permission_dir="$test_root/permission"
mkdir "$permission_dir"
permission_target="$permission_dir/projects.json"
permission_candidate="$permission_dir/candidate.json"
printf '[]\n' > "$permission_target"
printf '[{"name":"permission"}]\n' > "$permission_candidate"
permission_before=$(cdp_json_fingerprint "$permission_target")
chmod 500 "$permission_dir"
if [[ ! -w "$permission_dir" ]]; then
    if cdp_commit_json_file "$permission_target" "$permission_candidate" "$permission_before" >/dev/null 2>&1; then
        echo 'permission failure was ignored' >&2
        exit 1
    fi
    [[ "$(cdp_json_fingerprint "$permission_target")" == "$permission_before" ]]
    [[ ! -d "$permission_target.cdp.lock" ]]
fi
chmod 700 "$permission_dir"

mkdir "$target.cdp.lock"
printf '[]\n' > "$candidate"
if cdp_commit_json_file "$target" "$candidate" "$before_invalid" >/dev/null 2>&1; then
    echo 'foreign lock was ignored' >&2
    exit 1
fi
[[ -d "$target.cdp.lock" ]]
rmdir "$target.cdp.lock"

for index in 1 2 3 4 5; do
    fingerprint=$(cdp_json_fingerprint "$target")
    printf '[{"index":%s}]\n' "$index" > "$candidate"
    cdp_commit_json_file "$target" "$candidate" "$fingerprint"
done

backup_count=$(find "$test_root" -type f -name 'projects.json.cdp-backup.*' | wc -l | tr -d ' ')
[[ "$backup_count" == 3 ]]
jq -e '.[0].index == 5' "$target" >/dev/null

restore_backup=$(cdp_valid_json_backups "$target" | sed -n '1p')
printf '{\n' > "$target"

doctor_output=$(cdp-doctor "$target" 2>&1 || true)
[[ "$doctor_output" == *"valid cdp backup(s) available"* ]]

cdp_restore_json_backup "$target" "$restore_backup"
jq -e . "$target" >/dev/null

replacement_target="$test_root/replacement.json"
replacement_candidate="$test_root/replacement-candidate.json"
printf '[]\n' > "$replacement_target"
printf '[{"name":"replacement"}]\n' > "$replacement_candidate"
replacement_before=$(cdp_json_fingerprint "$replacement_target")
mv() { return 1; }
if cdp_commit_json_file "$replacement_target" "$replacement_candidate" "$replacement_before" >/dev/null 2>&1; then
    echo 'replacement failure was ignored' >&2
    exit 1
fi
unset -f mv
[[ "$(cdp_json_fingerprint "$replacement_target")" == "$replacement_before" ]]
[[ ! -d "$replacement_target.cdp.lock" ]]
if find "$test_root" -maxdepth 1 -type f -name '.replacement.json.cdp-tmp.*' | grep -q .; then
    echo 'replacement failure left a temporary file' >&2
    exit 1
fi
if find "$test_root" -maxdepth 1 -type f -name 'replacement.json.cdp-backup.*' | grep -q .; then
    echo 'replacement failure left a backup artifact' >&2
    exit 1
fi

echo 'cdp persistence shell tests: ok'
