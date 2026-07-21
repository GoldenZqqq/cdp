#!/usr/bin/env bash

set -euo pipefail

script_path="$0"
if [[ -n "${BASH_SOURCE:-}" ]]; then script_path="${BASH_SOURCE[0]}"; fi
repo_root="$(cd "$(dirname "$script_path")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/cdp-status-remote.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT INT TERM
source "$repo_root/src/cdp.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "expected '$2' in: $1"; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || fail "did not expect '$2' in: $1"; }
assert_equals() { [[ "$2" == "$1" ]] || fail "expected '$1', got '$2'"; }

init_repository() {
    mkdir -p "$1"
    git -C "$1" init --quiet -b main
    git -C "$1" config user.email tests@example.invalid
    git -C "$1" config user.name 'cdp tests'
}

new_remote_fixture() {
    local name="$1"
    fixture_remote="$test_root/$name-remote.git"
    fixture_writer="$test_root/$name-writer"
    fixture_repository="$test_root/$name-repository"
    mkdir -p "$fixture_remote"
    git -C "$fixture_remote" init --quiet --bare
    init_repository "$fixture_writer"
    printf 'initial\n' > "$fixture_writer/tracked.txt"
    git -C "$fixture_writer" add tracked.txt
    git -C "$fixture_writer" commit --quiet -m initial
    git -C "$fixture_writer" remote add origin "$fixture_remote"
    git -C "$fixture_writer" push --quiet -u origin main
    git -C "$fixture_remote" symbolic-ref HEAD refs/heads/main
    git clone --quiet "$fixture_remote" "$fixture_repository"
    git -C "$fixture_repository" config user.email tests@example.invalid
    git -C "$fixture_repository" config user.name 'cdp tests'
}

advance_remote() {
    printf '%s\n' "$2" >> "$1/tracked.txt"
    git -C "$1" add tracked.txt
    git -C "$1" commit --quiet -m "$2"
    git -C "$1" push --quiet origin main
}

new_remote_fixture freshness
fresh_remote="$fixture_remote"
fresh_writer="$fixture_writer"
fresh_repository="$fixture_repository"
advance_remote "$fresh_writer" remote-change
fresh_config="$test_root/freshness.json"
printf '[{"name":"Freshness","rootPath":"%s","enabled":true}]\n' "$fresh_repository" > "$fresh_config"
tracking_before=$(git -C "$fresh_repository" rev-parse refs/remotes/origin/main)
cached_output=$(cdp-status "$fresh_config" 2>&1)
tracking_after_cached=$(git -C "$fresh_repository" rev-parse refs/remotes/origin/main)
assert_contains "$cached_output" cached
assert_equals "$tracking_before" "$tracking_after_cached"
refreshed_output=$(cdp-status --fetch "$fresh_config" 2>&1)
tracking_after_fetch=$(git -C "$fresh_repository" rev-parse refs/remotes/origin/main)
assert_contains "$refreshed_output" refreshed
assert_contains "$refreshed_output" v1
[[ "$tracking_after_fetch" != "$tracking_before" ]] || fail 'explicit fetch did not update tracking ref'

new_remote_fixture mixed-success
success_writer="$fixture_writer"; success_repository="$fixture_repository"
advance_remote "$success_writer" remote-change
new_remote_fixture mixed-failure
failure_repository="$fixture_repository"
git -C "$failure_repository" remote set-url origin "$test_root/missing-secret.git"
mixed_config="$test_root/mixed.json"
printf '[{"name":"Success","rootPath":"%s","enabled":true},{"name":"Failure","rootPath":"%s","enabled":true}]\n' \
    "$success_repository" "$failure_repository" > "$mixed_config"
set +e
mixed_output=$(cdp-status --fetch --fetch-jobs 2 "$mixed_config" 2>&1)
mixed_exit=$?
set -e
assert_equals 1 "$mixed_exit"
assert_contains "$mixed_output" refreshed
assert_contains "$mixed_output" fetch-failed
assert_not_contains "$mixed_output" missing-secret

set +e
invalid_output=$(cdp-status --fetch-jobs 2 "$fresh_config" 2>&1)
invalid_exit=$?
set -e
[[ $invalid_exit -ne 0 ]] || fail '--fetch-jobs without --fetch succeeded'
assert_contains "$invalid_output" 'require --fetch'

new_remote_fixture timeout
timeout_repository="$fixture_repository"
timeout_marker="$test_root/timeout-orphan"
timeout_transport="$test_root/slow-transport.sh"
cat > "$timeout_transport" <<'TRANSPORT'
#!/usr/bin/env sh
sleep 2
printf 'orphaned\n' > "$CDP_STATUS_TIMEOUT_MARKER"
exit 1
TRANSPORT
chmod +x "$timeout_transport"
git -C "$timeout_repository" config protocol.ext.allow always
git -C "$timeout_repository" remote set-url origin "ext::sh $timeout_transport"
timeout_config="$test_root/timeout.json"
printf '[{"name":"Timeout","rootPath":"%s","enabled":true}]\n' "$timeout_repository" > "$timeout_config"
set +e
timeout_output=$(CDP_STATUS_TIMEOUT_MARKER="$timeout_marker" GIT_ALLOW_PROTOCOL=ext \
    cdp-status --fetch --fetch-timeout 1 "$timeout_config" 2>&1)
timeout_exit=$?
set -e
assert_equals 1 "$timeout_exit"
assert_contains "$timeout_output" fetch-failed
assert_contains "$timeout_output" timeout
sleep 1.5
[[ ! -e "$timeout_marker" ]] || fail 'timed-out transport survived cleanup'

new_remote_fixture redaction
redaction_repository="$fixture_repository"
printf 'ahead\n' >> "$redaction_repository/tracked.txt"
git -C "$redaction_repository" add tracked.txt
git -C "$redaction_repository" commit --quiet -m ahead
git -C "$redaction_repository" remote set-url origin 'https://user:secret@example.invalid/repo.git?token=secret'
redaction_config="$test_root/redaction.json"
printf '[{"name":"Redaction","rootPath":"%s","enabled":true}]\n' "$redaction_repository" > "$redaction_config"
redaction_output=$(cdp-status --push --dry-run "$redaction_config" 2>&1)
assert_contains "$redaction_output" 'https://***@example.invalid/repo.git'
assert_not_contains "$redaction_output" secret
assert_not_contains "$redaction_output" token=

new_remote_fixture snapshot
snapshot_remote="$fixture_remote"; snapshot_repository="$fixture_repository"
printf 'planned\n' >> "$snapshot_repository/tracked.txt"
git -C "$snapshot_repository" add tracked.txt
git -C "$snapshot_repository" commit --quiet -m planned
planned_oid=$(git -C "$snapshot_repository" rev-parse HEAD)
printf 'after\n' > "$snapshot_repository/after.txt"
git -C "$snapshot_repository" add after.txt
git -C "$snapshot_repository" commit --quiet -m after
cdp_status_push_snapshot "$snapshot_repository" origin "$planned_oid" refs/heads/main >/dev/null
assert_equals "$planned_oid" "$(git -C "$snapshot_remote" rev-parse refs/heads/main)"

echo 'cdp status remote shell tests: ok'
