# cdp shell domain: Hooks.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

cdp_hook_trust_path() {
    if [[ -n "${CDP_HOOK_TRUST_PATH:-}" ]]; then
        printf '%s\n' "$CDP_HOOK_TRUST_PATH"
    else
        printf '%s/.cdp/hook-trust.json\n' "$HOME"
    fi
}

cdp_normalize_config_path() {
    local config_path
    local config_dir
    local config_name
    config_path=$(convert_windows_to_wsl "$1")
    config_dir=$(dirname "$config_path")
    config_name=$(basename "$config_path")
    if (cd "$config_dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$config_name"); then
        return 0
    fi
    printf '%s\n' "$config_path"
}

cdp_load_hook_trust_store() {
    CDP_HOOK_TRUST_PATH_VALUE=$(cdp_hook_trust_path)
    if [[ ! -f "$CDP_HOOK_TRUST_PATH_VALUE" ]]; then
        CDP_HOOK_TRUST_FINGERPRINT=missing
        CDP_HOOK_TRUST_DOCUMENT='{"version":1,"entries":[]}'
        return 0
    fi
    chmod 600 "$CDP_HOOK_TRUST_PATH_VALUE" 2>/dev/null || {
        echo 'Error: unable to secure cdp hook trust store.' >&2
        return 1
    }
    CDP_HOOK_TRUST_DOCUMENT=$(cat "$CDP_HOOK_TRUST_PATH_VALUE")
    jq -e 'type == "object" and .version == 1 and (.entries | type == "array")' \
        "$CDP_HOOK_TRUST_PATH_VALUE" >/dev/null 2>&1 || {
        echo 'Error: invalid cdp hook trust store.' >&2
        return 1
    }
    CDP_HOOK_TRUST_FINGERPRINT=$(cdp_json_fingerprint "$CDP_HOOK_TRUST_PATH_VALUE")
}

cdp_save_hook_trust_store() {
    local json_text="$1"
    local expected_fingerprint="$2"
    (umask 077; cdp_write_json_text "$CDP_HOOK_TRUST_PATH_VALUE" "$json_text" "$expected_fingerprint") || return 1
    chmod 600 "$CDP_HOOK_TRUST_PATH_VALUE" 2>/dev/null || {
        echo 'Error: unable to secure cdp hook trust store.' >&2
        return 1
    }
}

cdp_hook_identity_from_json() {
    local config_path="$1"
    local project_json="$2"
    local hook_kind
    local hook_command
    local name_hash
    local root_hash
    local command_hash
    local config_content_hash
    hook_kind=$(printf '%s' "$project_json" | jq -r 'if (.onEnter | type) == "string" then "bash" elif (.onEnter.bash // "") != "" then "bash" else "" end')
    hook_command=$(printf '%s' "$project_json" | jq -r 'if (.onEnter | type) == "string" then .onEnter elif (.onEnter.bash // "") != "" then .onEnter.bash else "" end')
    [[ -z "$hook_kind" || -z "$hook_command" || "$hook_command" == null ]] && return 1
    name_hash=$(cdp_sha256_text "$(printf '%s' "$project_json" | jq -r '.name')")
    root_hash=$(cdp_sha256_text "$(printf '%s' "$project_json" | jq -r '.rootPath')")
    command_hash=$(cdp_sha256_text "$hook_command")
    config_content_hash=$(cdp_json_fingerprint "$config_path")
    CDP_HOOK_CONFIG_FINGERPRINT=$(cdp_sha256_text "$(cdp_normalize_config_path "$config_path")")
    CDP_HOOK_PROJECT_FINGERPRINT=$(cdp_sha256_text "name=$name_hash;root=$root_hash")
    CDP_HOOK_FINGERPRINT=$(cdp_sha256_text "config=$config_content_hash;kind=$hook_kind;command=$command_hash")
    CDP_HOOK_KIND="$hook_kind"
}

cdp_hook_project_json() {
    local config_path="$1"
    local project_query="$2"
    local matches
    matches=$(find_project_matches "$config_path" "$project_query")
    [[ "$(line_count "$matches")" -eq 1 ]] || return 1
    jq -c --arg name "$matches" '.[] | select(.enabled == true and .name == $name)' "$config_path" 2>/dev/null | head -n 1
}

cdp_hook_is_trusted() {
    local config_path="$1"
    local project_json="$2"
    CDP_HOOK_TRUST_ERROR=false
    cdp_hook_identity_from_json "$config_path" "$project_json" || return 1
    if ! cdp_load_hook_trust_store; then
        CDP_HOOK_TRUST_ERROR=true
        return 1
    fi
    jq -e --arg cf "$CDP_HOOK_CONFIG_FINGERPRINT" \
        --arg pf "$CDP_HOOK_PROJECT_FINGERPRINT" \
        --arg hf "$CDP_HOOK_FINGERPRINT" \
        '.entries[] | select(.configFingerprint == $cf and .projectFingerprint == $pf and .hookFingerprint == $hf)' \
        <<< "$CDP_HOOK_TRUST_DOCUMENT" >/dev/null 2>&1
}

cdp_hook_list() {
    local config_path="$1"
    cdp_load_hook_trust_store || return 1
    echo -e "${CYAN}cdp hook trust${NC}"
    while IFS= read -r project_json <&3; do
        [[ -z "$project_json" ]] && continue
        cdp_hook_identity_from_json "$config_path" "$project_json" || continue
        local state="untrusted"
        if jq -e --arg cf "$CDP_HOOK_CONFIG_FINGERPRINT" --arg pf "$CDP_HOOK_PROJECT_FINGERPRINT" \
            '.entries[] | select(.configFingerprint == $cf and .projectFingerprint == $pf)' \
            <<< "$CDP_HOOK_TRUST_DOCUMENT" >/dev/null 2>&1; then
            state="stale"
        fi
        if cdp_hook_is_trusted "$config_path" "$project_json"; then state="trusted"; fi
        echo "  $(printf '%s' "$project_json" | jq -r '.name') [$CDP_HOOK_KIND] $state"
    done 3< <(jq -c '.[] | select(.enabled == true and .onEnter != null)' "$config_path")
}

cdp_hook_trust() {
    local config_path="$1"
    local project_name="$2"
    local project_json
    project_json=$(cdp_hook_project_json "$config_path" "$project_name")
    [[ -z "$project_json" ]] && { echo 'Error: hook trust requires one enabled project match.' >&2; return 1; }
    cdp_hook_identity_from_json "$config_path" "$project_json" || { echo 'Error: project has no supported command hook.' >&2; return 1; }
    if $CDP_SAFETY_DRY_RUN; then
        echo -e "${GRAY}Would trust hook for project: $project_name${NC}"
        cdp_action_result hook-trust "$project_name" preview false
        return 0
    fi
    cdp_load_hook_trust_store || return 1
    local trusted_at
    trusted_at=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    local updated
    updated=$(jq --arg cf "$CDP_HOOK_CONFIG_FINGERPRINT" --arg pf "$CDP_HOOK_PROJECT_FINGERPRINT" \
        --arg hf "$CDP_HOOK_FINGERPRINT" --arg at "$trusted_at" \
        '.entries = ([.entries[] | select(.configFingerprint != $cf or .projectFingerprint != $pf)] + [{configFingerprint:$cf,projectFingerprint:$pf,hookFingerprint:$hf,trustedAt:$at}])' \
        <<< "$CDP_HOOK_TRUST_DOCUMENT")
    cdp_save_hook_trust_store "$updated" "$CDP_HOOK_TRUST_FINGERPRINT" || return 1
    echo -e "${GREEN}Trusted hook for project: $project_name${NC}"
}

cdp_hook_revoke() {
    local config_path="$1"
    local project_name="$2"
    cdp_load_hook_trust_store || return 1
    local config_fingerprint
    config_fingerprint=$(cdp_sha256_text "$(cdp_normalize_config_path "$config_path")")
    local updated
    if [[ "$project_name" == "--all" ]]; then
        updated=$(jq --arg cf "$config_fingerprint" '.entries = [.entries[] | select(.configFingerprint != $cf)]' <<< "$CDP_HOOK_TRUST_DOCUMENT")
    else
        local project_json
        project_json=$(cdp_hook_project_json "$config_path" "$project_name")
        [[ -z "$project_json" ]] && { echo 'Error: hook revoke requires one enabled project match.' >&2; return 1; }
        cdp_hook_identity_from_json "$config_path" "$project_json" || return 1
        updated=$(jq --arg cf "$config_fingerprint" --arg pf "$CDP_HOOK_PROJECT_FINGERPRINT" \
            '.entries = [.entries[] | select(.configFingerprint != $cf or .projectFingerprint != $pf)]' \
            <<< "$CDP_HOOK_TRUST_DOCUMENT")
    fi
    local target="$project_name"
    [[ "$project_name" == "--all" ]] && target="all hooks for active config"
    if $CDP_SAFETY_DRY_RUN; then
        echo -e "${GRAY}Would revoke hook trust: $target${NC}"
        cdp_action_result hook-revoke "$target" preview false
        return 0
    fi
    cdp_save_hook_trust_store "$updated" "$CDP_HOOK_TRUST_FINGERPRINT" || return 1
    echo -e "${GREEN}Hook trust revoked.${NC}"
}

cdp-hook() {
    local action="${1:-}"
    local project_name=""
    local config_path=""
    local all=false
    [[ $# -gt 0 ]] && shift
    cdp_parse_safety_options "$@" || return 1
    set -- "${CDP_SAFETY_ARGS[@]}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config|-config) [[ -n "${2:-}" ]] || { echo 'Error: missing value after --config.' >&2; return 1; }; config_path="$2"; shift 2 ;;
            --all) all=true; shift ;;
            -*) echo "Error: unknown hook option: $1" >&2; return 1 ;;
            *)
                if [[ -z "$project_name" ]]; then
                    project_name="$1"
                elif [[ -z "$config_path" ]] && is_config_path_arg "$1"; then
                    config_path="$1"
                else
                    echo 'Error: hook accepts one project and one config path.' >&2
                    return 1
                fi
                shift
                ;;
        esac
    done
    [[ -z "$action" ]] && action=list
    if [[ "$action" == list && -n "$project_name" && -z "$config_path" ]] && is_config_path_arg "$project_name"; then
        config_path="$project_name"
        project_name=""
    elif [[ "$action" == revoke && "$all" == true && -n "$project_name" && -z "$config_path" ]] && is_config_path_arg "$project_name"; then
        config_path="$project_name"
        project_name=""
    fi
    [[ -z "$config_path" ]] && config_path=$(get_default_config)
    if [[ "$action" == list ]]; then
        if $CDP_SAFETY_DRY_RUN || $CDP_SAFETY_YES; then
            echo 'Error: hook list does not accept safety options.' >&2
            return 1
        fi
        [[ -z "$project_name" && "$all" == false ]] || { echo 'Error: hook list does not accept a project.' >&2; return 1; }
        cdp_hook_list "$config_path"
    elif [[ "$action" == trust ]]; then
        [[ -n "$project_name" && "$all" == false ]] || { echo 'Error: hook trust requires a project.' >&2; return 1; }
        cdp_hook_trust "$config_path" "$project_name"
    elif [[ "$action" == revoke ]]; then
        [[ "$all" == true || -n "$project_name" ]] || { echo 'Error: hook revoke requires a project or --all.' >&2; return 1; }
        cdp_hook_revoke "$config_path" "${project_name:---all}"
    else
        echo "Error: unknown hook action: $action" >&2
        return 1
    fi
}

# Function to get stored config choice path

cdp_apply_on_enter_env() {
    local on_enter="$1"
    if printf '%s' "$on_enter" | jq -e 'type == "object"' >/dev/null 2>&1; then
        local env_key
        local env_value
        while IFS= read -r env_key <&3; do
            [[ -z "$env_key" ]] && continue
            case "$env_key" in
                [A-Za-z_]* ) ;;
                * )
                    echo -e "${YELLOW}  onEnter warning: invalid environment variable name skipped.${NC}"
                    continue
                    ;;
            esac
            case "$env_key" in
                *[!A-Za-z0-9_]* )
                    echo -e "${YELLOW}  onEnter warning: invalid environment variable name skipped.${NC}"
                    continue
                    ;;
            esac
            env_value=$(printf '%s' "$on_enter" | jq -r --arg key "$env_key" '.env[$key] | tostring')
            export "$env_key=$env_value"
        done 3<<< "$(printf '%s' "$on_enter" | jq -r '.env // {} | keys[]')"
    fi
}

cdp_apply_on_enter() {
    local on_enter="$1"
    local allow_hook="$2"
    local config_path="$3"
    local project_json="$4"
    local no_hook="$5"
    local hook_command=""

    if [[ "$no_hook" == true ]]; then
        echo -e "${YELLOW}  onEnter skipped by --no-hook.${NC}"
        return 0
    fi

    cdp_apply_on_enter_env "$on_enter"
    if printf '%s' "$on_enter" | jq -e 'type == "object"' >/dev/null 2>&1; then
        hook_command=$(printf '%s' "$on_enter" | jq -r '.bash // empty')
    else
        hook_command="$on_enter"
    fi

    hook_command="${hook_command%$'\r'}"
    [[ -z "$hook_command" || "$hook_command" == "null" ]] && return 0
    if [[ "$allow_hook" != true ]]; then
        if ! cdp_hook_is_trusted "$config_path" "$project_json"; then
            echo -e "${YELLOW}  onEnter command skipped: trust this project hook or use --allow-hook once.${NC}"
            return 0
        fi
    fi

    if ! eval "$hook_command" 2>/dev/null; then
        echo -e "${YELLOW}  onEnter warning: command failed.${NC}"
    fi
}
