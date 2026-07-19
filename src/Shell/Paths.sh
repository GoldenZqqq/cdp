# cdp shell domain: Paths.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

CDP_PROJECT_RAW_PATH=""
CDP_PROJECT_RESOLVED_PATH=""
CDP_PROJECT_PATH_PROFILE=""
CDP_PROJECT_PATH_SOURCE=""
CDP_PROJECT_PATH_EXPLICIT=false
CDP_PROJECT_PATH_ERROR_CODE=""
CDP_PROJECT_PATH_ERROR_MESSAGE=""

convert_windows_to_wsl() {
    local input_path="$1"

    case "$input_path" in
        [A-Za-z]:/*|[A-Za-z]:\\*)
            local drive
            local remainder
            drive="$(printf '%s' "${input_path%%:*}" | tr '[:upper:]' '[:lower:]')"
            remainder="${input_path#?:}"
            remainder="${remainder#?}"
            remainder="${remainder//\\//}"
            printf '/mnt/%s/%s\n' "$drive" "$remainder"
            ;;
        *) printf '%s\n' "$input_path" ;;
    esac
}

cdp_detect_path_profile() {
    local system_name
    local kernel_name
    system_name="$(uname -s 2>/dev/null || printf unknown)"
    kernel_name="$(uname -r 2>/dev/null || printf unknown)"

    case "$system_name" in
        Darwin) printf 'macos\n'; return 0 ;;
        MINGW*|MSYS*|CYGWIN*) printf 'windows\n'; return 0 ;;
    esac
    if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" || "$kernel_name" == *[Mm]icrosoft* ]]; then
        printf 'wsl\n'
    else
        printf 'linux\n'
    fi
}

cdp_current_path_profile() {
    local requested_profile="${1:-}"
    [[ -n "$requested_profile" ]] || requested_profile="${CDP_PATH_PROFILE:-}"
    if [[ -z "$requested_profile" ]]; then
        cdp_detect_path_profile
        return 0
    fi

    requested_profile="$(printf '%s' "$requested_profile" | tr '[:upper:]' '[:lower:]')"
    case "$requested_profile" in
        windows|wsl|linux|macos) printf '%s\n' "$requested_profile" ;;
        *)
            printf "Error: Invalid CDP_PATH_PROFILE '%s'. Expected windows, wsl, linux, or macos.\n" "$requested_profile" >&2
            return 1
            ;;
    esac
}

cdp_reset_project_path_resolution() {
    CDP_PROJECT_RAW_PATH=""
    CDP_PROJECT_RESOLVED_PATH=""
    CDP_PROJECT_PATH_PROFILE=""
    CDP_PROJECT_PATH_SOURCE=""
    CDP_PROJECT_PATH_EXPLICIT=false
    CDP_PROJECT_PATH_ERROR_CODE=""
    CDP_PROJECT_PATH_ERROR_MESSAGE=""
}

cdp_resolve_project_json() {
    local project_json="$1"
    local requested_profile="${2:-}"
    local profile
    local resolution
    local state
    cdp_reset_project_path_resolution
    profile="$(cdp_current_path_profile "$requested_profile")" || return 1
    CDP_PROJECT_PATH_PROFILE="$profile"

    resolution=$(printf '%s\n' "$project_json" | jq -jr --arg profile "$profile" '
        . as $project |
        (["windows","wsl","linux","macos"] | map(
            . as $candidate | select(
                ($project.paths | type) == "object" and ($project.paths | has($candidate)) and
                ((($project.paths[$candidate] | type) != "string") or (($project.paths[$candidate] | length) == 0))
            )
        ) | .[0]) as $invalidProfile |
        if ((.rootPath | type) != "string") or ((.rootPath | length) == 0) then
            ["invalid", (.rootPath // ""), "", "rootPath", "false", "Project rootPath must be a non-empty string."]
        elif has("paths") and ((.paths | type) != "object") then
            ["invalid", .rootPath, "", ("paths." + $profile), "true", "Project paths must be a JSON object."]
        elif $invalidProfile != null then
            ["invalid", .rootPath, "", ("paths." + $invalidProfile), ($invalidProfile == $profile | tostring), ("Project paths." + $invalidProfile + " must be a non-empty string.")]
        elif ((.paths | type) == "object") and (.paths | has($profile)) then
            ["explicit", .rootPath, .paths[$profile], ("paths." + $profile), "true", ""]
        else
            ["fallback", .rootPath, .rootPath, "rootPath", "false", ""]
        end | join("\u001c")
    ' 2>/dev/null) || {
        CDP_PROJECT_PATH_ERROR_CODE=path_profile_invalid
        CDP_PROJECT_PATH_ERROR_MESSAGE='Project path configuration is invalid JSON.'
        return 2
    }

    IFS=$'\034' read -r state CDP_PROJECT_RAW_PATH CDP_PROJECT_RESOLVED_PATH \
        CDP_PROJECT_PATH_SOURCE CDP_PROJECT_PATH_EXPLICIT CDP_PROJECT_PATH_ERROR_MESSAGE <<< "$resolution"
    if [[ "$state" == invalid ]]; then
        CDP_PROJECT_PATH_ERROR_CODE=path_profile_invalid
        return 2
    fi
    if [[ "$state" == fallback && "$profile" == wsl ]]; then
        CDP_PROJECT_RESOLVED_PATH="$(convert_windows_to_wsl "$CDP_PROJECT_RAW_PATH")"
        CDP_PROJECT_PATH_SOURCE='rootPath:wsl-converted'
    fi
    return 0
}

cdp_project_json_by_name() {
    local config_path="$1"
    local project_name="$2"
    jq -c --arg name "$project_name" \
        '.[] | select(.name == $name and .enabled == true)' "$config_path" 2>/dev/null | head -n1
}

cdp_find_project_by_local_path_json() {
    local config_json="$1"
    local local_path="$2"
    local candidate_path
    candidate_path=$(cd "$local_path" 2>/dev/null && pwd -P || printf '%s' "$local_path")

    while IFS= read -r project_json; do
        [[ -z "$project_json" ]] && continue
        if cdp_resolve_project_json "$project_json"; then
            local resolved_path
            resolved_path=$(cd "$CDP_PROJECT_RESOLVED_PATH" 2>/dev/null && pwd -P || printf '%s' "$CDP_PROJECT_RESOLVED_PATH")
            if [[ "$resolved_path" == "$candidate_path" ]]; then
                printf '%s\n' "$project_json"
                return 0
            fi
        fi
    done < <(printf '%s\n' "$config_json" | jq -c '.[]')
    return 1
}

cdp_new_project_json() {
    local project_name="$1"
    local project_path="$2"
    local profile
    profile="$(cdp_current_path_profile)" || return 1
    jq -cn --arg name "$project_name" --arg project_path "$project_path" --arg profile "$profile" '
        {name:$name,rootPath:$project_path,enabled:true,pinned:false,aliases:[],tags:[],paths:{($profile):$project_path}}
    '
}
