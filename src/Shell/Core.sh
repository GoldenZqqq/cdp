# cdp shell domain: Core.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

cdp_parse_safety_options() {
    CDP_SAFETY_DRY_RUN=false
    CDP_SAFETY_YES=false
    CDP_SAFETY_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) CDP_SAFETY_DRY_RUN=true ;;
            --yes) CDP_SAFETY_YES=true ;;
            *) CDP_SAFETY_ARGS+=("$1") ;;
        esac
        shift
    done
    if $CDP_SAFETY_DRY_RUN && $CDP_SAFETY_YES; then
        echo -e "${RED}Error: --dry-run and --yes cannot be used together.${NC}" >&2
        return 1
    fi
}

cdp_require_high_risk_approval() {
    local action="$1"
    if $CDP_SAFETY_DRY_RUN; then
        echo -e "${GRAY}Dry run: $action was not executed.${NC}"
        return 2
    fi
    if ! $CDP_SAFETY_YES; then
        echo -e "${RED}Action requires explicit confirmation. Re-run with --yes or preview with --dry-run.${NC}" >&2
        return 1
    fi
    return 0
}

cdp_action_result() {
    local action="$1"
    local target="$2"
    local result_status="$3"
    local changed="$4"
    local error="${5:-}"
    if [[ -n "$error" ]]; then
        printf 'action=%s target=%s status=%s changed=%s error=%s\n' "$action" "$target" "$result_status" "$changed" "$error"
    else
        printf 'action=%s target=%s status=%s changed=%s\n' "$action" "$target" "$result_status" "$changed"
    fi
}


cdp_sha256_file() {
    local input_file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$input_file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$input_file" | awk '{print $1}'
    else
        openssl dgst -sha256 "$input_file" | awk '{print $NF}'
    fi
}

cdp_json_fingerprint() {
    local target_path="$1"
    if [[ ! -f "$target_path" ]]; then
        printf '%s\n' missing
        return 0
    fi
    cdp_sha256_file "$target_path"
}

cdp_json_temp_file() {
    local target_path="$1"
    local target_dir
    local target_name
    target_dir=$(dirname "$target_path")
    target_name=$(basename "$target_path")
    mkdir -p "$target_dir"
    mktemp "$target_dir/.$target_name.cdp-tmp.XXXXXX"
}

cdp_prune_json_backups() {
    local target_path="$1"
    local keep="${2:-3}"
    local target_dir
    local target_name
    local backup_path
    local backups=()
    target_dir=$(dirname "$target_path")
    target_name=$(basename "$target_path")
    while IFS= read -r backup_path; do
        [[ -n "$backup_path" ]] && backups+=("$backup_path")
    done < <(find "$target_dir" -maxdepth 1 -type f -name "$target_name.cdp-backup.*" -print 2>/dev/null)
    [[ ${#backups[@]} -le $keep ]] && return 0
    LC_ALL=C ls -1t "${backups[@]}" 2>/dev/null |
        awk -v keep="$keep" 'NR > keep' |
        while IFS= read -r backup_path; do
            [[ -n "$backup_path" ]] && rm -f -- "$backup_path"
        done
}

cdp_flush_file() {
    local input_file="$1"
    sync -f "$input_file" 2>/dev/null || sync 2>/dev/null
}

cdp_stage_json_candidate() {
    local target_path="$1"
    local candidate_path="$2"
    local staged_path
    staged_path=$(cdp_json_temp_file "$target_path") || return 1
    if ! cat "$candidate_path" > "$staged_path"; then
        rm -f -- "$staged_path"
        return 1
    fi
    if ! jq -e . "$staged_path" >/dev/null 2>&1; then
        rm -f -- "$staged_path"
        echo "Error: refusing to persist invalid JSON: $target_path" >&2
        return 1
    fi
    if ! cdp_flush_file "$staged_path"; then
        rm -f -- "$staged_path"
        echo "Error: failed to flush JSON document: $target_path" >&2
        return 1
    fi
    printf '%s\n' "$staged_path"
}

cdp_create_json_backup() {
    local target_path="$1"
    local backup_stamp
    local backup_path
    [[ ! -f "$target_path" ]] && return 0
    backup_stamp=$(date -u +'%Y%m%d%H%M%S')
    backup_path=$(mktemp "$target_path.cdp-backup.$backup_stamp.XXXXXX") || return 1
    if ! cp "$target_path" "$backup_path" || ! cdp_flush_file "$backup_path"; then
        rm -f -- "$backup_path"
        echo "Error: failed to preserve JSON backup: $target_path" >&2
        return 1
    fi
    printf '%s\n' "$backup_path"
}

cdp_commit_json_file() {
    local target_path="$1"
    local candidate_path="$2"
    local expected_fingerprint="${3:-}"
    local lock_path="$target_path.cdp.lock"
    local staged_path=""
    local backup_path=""
    local current_fingerprint

    mkdir "$lock_path" 2>/dev/null || {
        echo "Error: JSON document is locked by another cdp process: $target_path" >&2
        return 1
    }
    current_fingerprint=$(cdp_json_fingerprint "$target_path")
    if [[ -n "$expected_fingerprint" && "$expected_fingerprint" != "$current_fingerprint" ]]; then
        rmdir "$lock_path" 2>/dev/null || true
        echo "Error: JSON document changed since it was read: $target_path" >&2
        return 1
    fi
    staged_path=$(cdp_stage_json_candidate "$target_path" "$candidate_path") || {
        rmdir "$lock_path" 2>/dev/null || true
        return 1
    }
    backup_path=$(cdp_create_json_backup "$target_path") || {
        rm -f -- "$staged_path"
        rmdir "$lock_path" 2>/dev/null || true
        return 1
    }

    if ! mv -f "$staged_path" "$target_path"; then
        rm -f -- "$staged_path"
        [[ -n "$backup_path" ]] && rm -f -- "$backup_path"
        rmdir "$lock_path" 2>/dev/null || true
        return 1
    fi
    cdp_prune_json_backups "$target_path" 3
    rmdir "$lock_path" 2>/dev/null || true
}

cdp_write_json_text() {
    local target_path="$1"
    local json_text="$2"
    local expected_fingerprint="${3:-}"
    local candidate_path
    candidate_path=$(cdp_json_temp_file "$target_path") || return 1
    printf '%s\n' "$json_text" > "$candidate_path"
    if cdp_commit_json_file "$target_path" "$candidate_path" "$expected_fingerprint"; then
        rm -f -- "$candidate_path"
        return 0
    fi
    rm -f -- "$candidate_path"
    return 1
}

cdp_valid_json_backups() {
    local target_path="$1"
    local target_dir
    local target_name
    local backup_path
    target_dir=$(dirname "$target_path")
    target_name=$(basename "$target_path")
    find "$target_dir" -maxdepth 1 -type f -name "$target_name.cdp-backup.*" -print 2>/dev/null |
        sort -r |
        while IFS= read -r backup_path; do
            jq -e . "$backup_path" >/dev/null 2>&1 && printf '%s\n' "$backup_path"
        done
}

cdp_restore_json_backup() {
    local target_path="$1"
    local backup_path="$2"
    local expected_fingerprint
    if ! cdp_valid_json_backups "$target_path" | grep -Fx "$backup_path" >/dev/null 2>&1; then
        echo "Error: backup is missing or invalid: $backup_path" >&2
        return 1
    fi
    expected_fingerprint=$(cdp_json_fingerprint "$target_path")
    cdp_commit_json_file "$target_path" "$backup_path" "$expected_fingerprint"
}

cdp_sha256_text() {
    local value="$1"
    printf '%s' "$value" | if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
    else
        openssl dgst -sha256 | awk '{print $NF}'
    fi
}
