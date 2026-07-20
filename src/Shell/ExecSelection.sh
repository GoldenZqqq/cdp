# cdp shell domain: ExecSelection.sh
# shellcheck shell=bash
# Generated runtime fragment; do not source peer fragments.

CDP_EXEC_SELECTOR_KIND=""
CDP_EXEC_SELECTOR_VALUES=()
CDP_EXEC_CONFIG_PATH=""
CDP_EXEC_COMMAND=""
CDP_EXEC_EXECUTABLE=""
CDP_EXEC_ARGUMENTS=()
CDP_EXEC_JOBS=0
CDP_EXEC_TIMEOUT=0
CDP_EXEC_FAIL_FAST=false
CDP_EXEC_CONTINUE=false
CDP_EXEC_JSON=false
CDP_EXEC_DRY_RUN=false
CDP_EXEC_YES=false
CDP_EXEC_NAMES=()
CDP_EXEC_RAW_PATHS=()
CDP_EXEC_PATHS=()
CDP_EXEC_STATUSES=()
CDP_EXEC_EXIT_CODES=()
CDP_EXEC_ELAPSED=()
CDP_EXEC_STDOUT=()
CDP_EXEC_STDERR=()
CDP_EXEC_ERRORS=()

cdp_exec_fail() {
    printf 'Error: %s\n' "$*" >&2
    return 3
}

cdp_exec_reset() {
    CDP_EXEC_SELECTOR_KIND=""; CDP_EXEC_SELECTOR_VALUES=(); CDP_EXEC_CONFIG_PATH=""
    CDP_EXEC_COMMAND=""; CDP_EXEC_EXECUTABLE=""; CDP_EXEC_ARGUMENTS=()
    CDP_EXEC_JOBS=0; CDP_EXEC_TIMEOUT=0; CDP_EXEC_FAIL_FAST=false; CDP_EXEC_CONTINUE=false
    CDP_EXEC_JSON=false; CDP_EXEC_DRY_RUN=false; CDP_EXEC_YES=false
    CDP_EXEC_NAMES=(); CDP_EXEC_RAW_PATHS=(); CDP_EXEC_PATHS=(); CDP_EXEC_STATUSES=()
    CDP_EXEC_EXIT_CODES=(); CDP_EXEC_ELAPSED=(); CDP_EXEC_STDOUT=(); CDP_EXEC_STDERR=(); CDP_EXEC_ERRORS=()
}

cdp_exec_set_selector() {
    local kind="$1" value="${2:-}"
    if [[ -n "$CDP_EXEC_SELECTOR_KIND" && "$CDP_EXEC_SELECTOR_KIND" != "$kind" ]]; then
        cdp_exec_fail 'exec selector types cannot be combined.'; return 3
    fi
    if [[ "$kind" != projects && -n "$CDP_EXEC_SELECTOR_KIND" ]]; then
        cdp_exec_fail 'exec selector types cannot be combined.'; return 3
    fi
    CDP_EXEC_SELECTOR_KIND="$kind"
    [[ "$kind" == all ]] || CDP_EXEC_SELECTOR_VALUES+=("$value")
}

cdp_exec_parse_integer() {
    local option="$1" value="$2" maximum="$3"
    [[ "$value" =~ ^[0-9]+$ ]] || { cdp_exec_fail "exec $option must be between 1 and $maximum."; return 3; }
    (( value >= 1 && value <= maximum )) || { cdp_exec_fail "exec $option must be between 1 and $maximum."; return 3; }
    if [[ "$option" == jobs ]]; then CDP_EXEC_JOBS="$value"; else CDP_EXEC_TIMEOUT="$value"; fi
}

cdp_exec_parse_value_option() {
    local option="$1" value="$2"
    case "$option" in
        --config) [[ -n "$value" ]] || { cdp_exec_fail 'exec config path cannot be empty.'; return 3; }; [[ -z "$CDP_EXEC_CONFIG_PATH" ]] || { cdp_exec_fail '--config specified more than once.'; return 3; }; CDP_EXEC_CONFIG_PATH="$value" ;;
        --workspace) [[ -n "$value" ]] || { cdp_exec_fail 'exec workspace selector cannot be empty.'; return 3; }; cdp_exec_set_selector workspace "$value" ;;
        --jobs) cdp_exec_parse_integer jobs "$value" 16 ;;
        --timeout) cdp_exec_parse_integer timeout "$value" 3600 ;;
    esac
}

cdp_exec_parse_option() {
    case "$1" in
        --all) cdp_exec_set_selector all ;;
        --fail-fast) CDP_EXEC_FAIL_FAST=true ;;
        --continue) CDP_EXEC_CONTINUE=true ;;
        --json) CDP_EXEC_JSON=true ;;
        --dry-run) CDP_EXEC_DRY_RUN=true ;;
        --yes) CDP_EXEC_YES=true ;;
        @*) [[ "$1" != @ ]] || { cdp_exec_fail 'exec tag selector cannot be empty.'; return 3; }; cdp_exec_set_selector tag "${1#@}" ;;
        -*) cdp_exec_fail "unknown exec option: $1"; return 3 ;;
        *) [[ -n "$1" ]] || { cdp_exec_fail 'exec project selector cannot be empty.'; return 3; }; cdp_exec_set_selector projects "$1" ;;
    esac
}

cdp_exec_parse() {
    cdp_exec_reset
    local boundary=false
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == -- ]]; then boundary=true; shift; break; fi
        case "$1" in
            --config|--workspace|--jobs|--timeout)
                [[ $# -ge 2 ]] || { cdp_exec_fail "missing value after $1."; return 3; }
                cdp_exec_parse_value_option "$1" "$2" || return 3
                shift 2
                ;;
            *) cdp_exec_parse_option "$1" || return 3; shift ;;
        esac
    done
    $boundary || { cdp_exec_fail 'cdp exec requires -- before the command.'; return 3; }
    [[ $# -gt 0 && -n "$1" ]] || { cdp_exec_fail 'cdp exec requires a non-empty command after --.'; return 3; }
    CDP_EXEC_COMMAND="$1"; shift; CDP_EXEC_ARGUMENTS=("$@")
    [[ -n "$CDP_EXEC_SELECTOR_KIND" ]] || { cdp_exec_fail 'cdp exec requires projects, @tag, --workspace, or --all.'; return 3; }
    $CDP_EXEC_FAIL_FAST && $CDP_EXEC_CONTINUE && { cdp_exec_fail '--fail-fast and --continue cannot be used together.'; return 3; }
    $CDP_EXEC_DRY_RUN && $CDP_EXEC_YES && { cdp_exec_fail '--dry-run and --yes cannot be used together.'; return 3; }
    return 0
}

cdp_exec_setting() {
    local name="$1" default_value="$2" maximum="$3" value
    value="$default_value"
    case "$name" in
        CDP_EXEC_CONCURRENCY) value="${CDP_EXEC_CONCURRENCY:-$default_value}" ;;
        CDP_EXEC_TIMEOUT_SECONDS) value="${CDP_EXEC_TIMEOUT_SECONDS:-$default_value}" ;;
    esac
    [[ "$value" =~ ^[0-9]+$ ]] || value="$default_value"
    (( value < 1 )) && value=1
    (( value > maximum )) && value="$maximum"
    printf '%s\n' "$value"
}

cdp_exec_raw_seen() {
    local raw_path="$1" existing
    [[ -n "$raw_path" ]] || return 1
    if (( ${#CDP_EXEC_RAW_PATHS[@]} > 0 )); then
        for existing in "${CDP_EXEC_RAW_PATHS[@]}"; do [[ "$existing" == "$raw_path" ]] && return 0; done
    fi
    return 1
}

cdp_exec_append_item() {
    local name="$1" raw_path="$2" resolved_path="$3" item_status="$4" error="${5:-}"
    cdp_exec_raw_seen "$raw_path" && return 0
    CDP_EXEC_NAMES+=("$name"); CDP_EXEC_RAW_PATHS+=("$raw_path"); CDP_EXEC_PATHS+=("$resolved_path")
    CDP_EXEC_STATUSES+=("$item_status"); CDP_EXEC_EXIT_CODES+=(""); CDP_EXEC_ELAPSED+=(0)
    CDP_EXEC_STDOUT+=(""); CDP_EXEC_STDERR+=(""); CDP_EXEC_ERRORS+=("$error")
}

cdp_exec_add_project_json() {
    local project_json="$1" name raw_path resolved_path="" item_status=planned error=""
    name=$(jq -r '.name // empty' <<< "$project_json")
    raw_path=$(jq -r '.rootPath // empty' <<< "$project_json")
    if cdp_resolve_project_json "$project_json"; then resolved_path="$CDP_PROJECT_RESOLVED_PATH"
    else resolved_path="$CDP_PROJECT_RESOLVED_PATH"; item_status=path_profile_invalid; error="$CDP_PROJECT_PATH_ERROR_MESSAGE"; fi
    if [[ "$(jq -r '.enabled == true' <<< "$project_json")" != true ]]; then item_status=disabled_project; error='Project is disabled.'
    elif [[ "$item_status" == planned && ! -d "$resolved_path" ]]; then item_status=path_missing; error='Resolved project path does not exist.'; fi
    cdp_exec_append_item "$name" "$raw_path" "$resolved_path" "$item_status" "$error"
}

cdp_exec_select_projects() {
    local projects_json="$1" name matches count project_json
    for name in "${CDP_EXEC_SELECTOR_VALUES[@]}"; do
        matches=$(jq -c --arg name "$name" '[.[] | select(.name == $name)]' <<< "$projects_json") || return 3
        count=$(jq 'length' <<< "$matches")
        [[ "$count" -gt 0 ]] || { cdp_exec_fail "exec project '$name' not found."; return 3; }
        [[ "$count" -eq 1 ]] || { cdp_exec_fail "exec project '$name' is ambiguous."; return 3; }
        project_json=$(jq -c '.[0]' <<< "$matches"); cdp_exec_add_project_json "$project_json"
    done
}

cdp_exec_select_tag() {
    local projects_json="$1" tag="${CDP_EXEC_SELECTOR_VALUES[0]}" matches project_json count=0
    matches=$(jq -c --arg tag "$tag" '($tag|ascii_downcase) as $t | .[] | select(.enabled == true) | select(((.tags // []) | map(ascii_downcase) | index($t)) != null)' <<< "$projects_json") || return 3
    while IFS= read -r project_json <&3; do [[ -n "$project_json" ]] || continue; cdp_exec_add_project_json "$project_json"; count=$((count + 1)); done 3< <(printf '%s\n' "$matches")
    [[ "$count" -gt 0 ]] || { cdp_exec_fail "exec tag '@$tag' matched no enabled projects."; return 3; }
}

cdp_exec_select_all() {
    local projects_json="$1" project_json count=0
    while IFS= read -r project_json <&3; do [[ -n "$project_json" ]] || continue; cdp_exec_add_project_json "$project_json"; count=$((count + 1)); done 3< <(jq -c '.[] | select(.enabled == true)' <<< "$projects_json")
    [[ "$count" -gt 0 ]] || { cdp_exec_fail 'exec --all matched no enabled projects.'; return 3; }
}

cdp_exec_workspace_status() {
    case "$1" in
        ok|legacy|renamed) printf planned ;;
        missing-project|invalid-reference) printf missing_project ;;
        ambiguous-project) printf ambiguous_project ;;
        disabled-project) printf disabled_project ;;
        invalid-path-profile) printf path_profile_invalid ;;
        missing-path) printf path_missing ;;
        *) printf missing_project ;;
    esac
}

cdp_exec_add_workspace_result() {
    local result="$1" workspace_status item_status error=""
    workspace_status=$(jq -r '.status' <<< "$result"); item_status=$(cdp_exec_workspace_status "$workspace_status")
    [[ "$item_status" == planned ]] || error="Workspace reference status: $workspace_status."
    cdp_exec_append_item "$(jq -r '.name // empty' <<< "$result")" "$(jq -r '.rawPath // empty' <<< "$result")" \
        "$(jq -r '.resolvedPath // empty' <<< "$result")" "$item_status" "$error"
}

cdp_exec_select_workspace() {
    local projects_json="$1" workspace_path workspace_json matches reference sanitized result count=0
    workspace_path="$(dirname "$CDP_EXEC_CONFIG_PATH")/workspaces.json"
    workspace_json=$(cdp_workspace_read_json "$workspace_path") || return 3
    matches=$(jq -c --arg name "${CDP_EXEC_SELECTOR_VALUES[0]}" '[.[] | select(.name == $name)]' <<< "$workspace_json") || return 3
    [[ "$(jq 'length' <<< "$matches")" -eq 1 ]] || { cdp_exec_fail "workspace '${CDP_EXEC_SELECTOR_VALUES[0]}' not found or ambiguous."; return 3; }
    jq -e '.[0].projects | type == "array"' <<< "$matches" >/dev/null 2>&1 || {
        cdp_exec_fail "workspace '${CDP_EXEC_SELECTOR_VALUES[0]}' projects must be a JSON array."; return 3;
    }
    while IFS= read -r reference <&3; do
        [[ -n "$reference" ]] || continue
        sanitized=$(jq -c 'if type == "object" then {name:(.name // null),rootPath:(.rootPath // null)} else . end' <<< "$reference")
        result=$(cdp_workspace_reference_result "$sanitized" "$projects_json" '' '') || return 3
        cdp_exec_add_workspace_result "$result"; count=$((count + 1))
    done 3< <(jq -c '.[0].projects[]?' <<< "$matches")
    [[ "$count" -gt 0 ]] || { cdp_exec_fail "workspace '${CDP_EXEC_SELECTOR_VALUES[0]}' does not contain projects."; return 3; }
}

cdp_exec_resolve_executable() {
    local resolved
    resolved=$(command -v -- "$CDP_EXEC_COMMAND" 2>/dev/null || true)
    [[ -n "$resolved" && "$resolved" == */* && -f "$resolved" && -x "$resolved" ]] || {
        cdp_exec_fail "exec command '$CDP_EXEC_COMMAND' was not found as a native executable."; return 3;
    }
    CDP_EXEC_EXECUTABLE="$resolved"
}

cdp_exec_build_plan() {
    command -v jq >/dev/null 2>&1 || { cdp_exec_fail "'jq' command not found."; return 3; }
    [[ -n "$CDP_EXEC_CONFIG_PATH" ]] || CDP_EXEC_CONFIG_PATH=$(get_default_config)
    [[ -f "$CDP_EXEC_CONFIG_PATH" ]] || { cdp_exec_fail "configuration file not found: $CDP_EXEC_CONFIG_PATH"; return 3; }
    local projects_json
    projects_json=$(cat "$CDP_EXEC_CONFIG_PATH") || { cdp_exec_fail 'failed to read configuration.'; return 3; }
    jq -e 'type == "array"' <<< "$projects_json" >/dev/null 2>&1 || { cdp_exec_fail 'project configuration must be a JSON array.'; return 3; }
    cdp_current_path_profile >/dev/null || { cdp_exec_fail 'invalid CDP_PATH_PROFILE.'; return 3; }
    case "$CDP_EXEC_SELECTOR_KIND" in
        projects) cdp_exec_select_projects "$projects_json" || return 3 ;;
        tag) cdp_exec_select_tag "$projects_json" || return 3 ;;
        workspace) cdp_exec_select_workspace "$projects_json" || return 3 ;;
        all) cdp_exec_select_all "$projects_json" || return 3 ;;
    esac
    [[ "$CDP_EXEC_JOBS" -gt 0 ]] || CDP_EXEC_JOBS=$(cdp_exec_setting CDP_EXEC_CONCURRENCY 4 16)
    [[ "$CDP_EXEC_TIMEOUT" -gt 0 ]] || CDP_EXEC_TIMEOUT=$(cdp_exec_setting CDP_EXEC_TIMEOUT_SECONDS 300 3600)
    cdp_exec_resolve_executable
}
