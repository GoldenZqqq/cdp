#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fragment_root="$repo_root/src/Shell"
output_path="$repo_root/src/cdp.sh"
check_only=false

if [[ "${1:-}" == "--check" ]]; then
    check_only=true
elif [[ $# -gt 0 ]]; then
    echo "usage: $0 [--check]" >&2
    exit 2
fi

fragments=(
    Runtime.sh
    Core.sh
    Config.sh
    Paths.sh
    State.sh
    Frecency.sh
    Picker.sh
    Hooks.sh
    Health.sh
    Scan.sh
    StatusBatch.sh
    Status.sh
    StatusOutput.sh
    WorkspaceLifecycle.sh
    Workspace.sh
    ExecSelection.sh
    ExecOutput.sh
    Exec.sh
    Projects.sh
    ProjectMetadata.sh
    Commands.sh
    Completion.sh
)

temporary_path="$(mktemp "${TMPDIR:-/tmp}/cdp-shell-build.XXXXXX")"
cleanup() {
    rm -f "$temporary_path"
}
trap cleanup EXIT

fragment_index=0
fragment_count="${#fragments[@]}"
for fragment in "${fragments[@]}"; do
    fragment_path="$fragment_root/$fragment"
    if [[ ! -f "$fragment_path" ]]; then
        echo "missing shell fragment: $fragment_path" >&2
        exit 1
    fi
    cat "$fragment_path" >> "$temporary_path"
    fragment_index=$((fragment_index + 1))
    if [[ "$fragment_index" -lt "$fragment_count" ]]; then
        printf '\n' >> "$temporary_path"
    fi
done

if $check_only; then
    if cmp -s "$temporary_path" "$output_path"; then
        echo "shell artifact is synchronized"
        exit 0
    fi
    echo "shell artifact is stale; run scripts/Build-ShellScript.sh" >&2
    exit 1
fi

chmod 644 "$temporary_path"
mv "$temporary_path" "$output_path"
echo "generated $output_path"
