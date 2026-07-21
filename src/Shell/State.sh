# cdp shell domain: State.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

cdp_state_path() {
    if [[ -n "${CDP_STATE_PATH:-}" ]]; then
        echo "$CDP_STATE_PATH"
    else
        echo "$HOME/.cdp/state.json"
    fi
}

initialize_state() {
    local state_path="$1"
    local state_dir
    state_dir=$(dirname "$state_path")
    mkdir -p "$state_dir"

    if [[ ! -f "$state_path" ]]; then
        cdp_write_json_text "$state_path" '{"recentProjects":[]}' missing
    elif ! jq -e 'type == "object"' "$state_path" >/dev/null 2>&1; then
        echo "Error: refusing to overwrite invalid cdp state: $state_path" >&2
        return 1
    fi
}

cdp_record_recent() {
    local name="$1"
    local root_path="$2"
    local project_json="${3:-}"

    [[ -z "$name" || -z "$root_path" ]] && return 0
    command -v jq >/dev/null 2>&1 || return 0

    local state_path
    local temp_file
    local expected_fingerprint
    local now
    state_path=$(cdp_state_path)
    initialize_state "$state_path" || return 0
    expected_fingerprint=$(cdp_json_fingerprint "$state_path")
    temp_file=$(cdp_json_temp_file "$state_path") || return 0
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if jq --arg name "$name" --arg path "$root_path" --arg now "$now" --argjson project "${project_json:-null}" '
        .recentProjects as $recent |
        .recentProjects = (
            (($recent // []) | map(select(.rootPath != $path))) +
            [({
                "name": $name,
                "rootPath": $path,
                "lastVisitedAt": $now,
                "visitCount": (((($recent // []) | map(select(.rootPath == $path)) | .[0].visitCount) // 0) + 1)
            } + (if (($project.paths // null) | type) == "object" then {paths:$project.paths} else {} end))]
            | sort_by(.lastVisitedAt)
            | reverse
            | .[:20]
        )
    ' "$state_path" > "$temp_file" 2>/dev/null &&
        cdp_commit_json_file "$state_path" "$temp_file" "$expected_fingerprint"; then
        rm -f -- "$temp_file"
    else
        rm -f -- "$temp_file"
    fi
}

# Function to find all available config files

cdp_reset_recent() {
    local state_path
    local expected_fingerprint
    local temp_file
    local approval_status
    state_path=$(cdp_state_path)

    if [[ ! -f "$state_path" ]]; then
        cdp_action_result recent-reset "$state_path" skipped false
        return 0
    fi
    if ! jq -e 'type == "object" and
        (.recentProjects == null or (.recentProjects | type) == "array")' \
        "$state_path" >/dev/null 2>&1; then
        cdp_action_result recent-reset "$state_path" failed false invalid-state
        return 1
    fi
    if [[ "$(jq '(.recentProjects // []) | length' "$state_path")" -eq 0 ]]; then
        cdp_action_result recent-reset "$state_path" skipped false
        return 0
    fi
    if cdp_require_high_risk_approval 'clear recent project history'; then
        approval_status=0
    else
        approval_status=$?
    fi
    if [[ "$approval_status" -eq 2 ]]; then
        cdp_action_result recent-reset "$state_path" preview false
        return 0
    elif [[ "$approval_status" -ne 0 ]]; then
        cdp_action_result recent-reset "$state_path" canceled false
        return 1
    fi

    expected_fingerprint=$(cdp_json_fingerprint "$state_path")
    temp_file=$(cdp_json_temp_file "$state_path") || return 1
    if jq '.recentProjects = []' "$state_path" > "$temp_file" &&
        cdp_commit_json_file "$state_path" "$temp_file" "$expected_fingerprint"; then
        rm -f -- "$temp_file"
        cdp_action_result recent-reset "$state_path" succeeded true
        return 0
    fi
    rm -f -- "$temp_file"
    cdp_action_result recent-reset "$state_path" failed false write-failed
    return 1
}

cdp_recent_rows() {
    jq -r --argjson count "$2" '
        (.recentProjects // [])
        | sort_by(.lastVisitedAt)
        | reverse
        | .[:$count]
        | .[]
        | [.name, .lastVisitedAt, ((.visitCount // 1) | tostring), .rootPath]
        | @tsv
    ' "$1" 2>/dev/null
}

cdp_recent_name_width() {
    local recent_projects="$1"
    local name_width=14
    local name ignored
    while IFS=$'\t' read -r name ignored; do
        if (( ${#name} > name_width )); then name_width=${#name}; fi
    done <<< "$recent_projects"
    if (( name_width > 30 )); then name_width=30; fi
    printf '%s\n' "$name_width"
}

cdp_render_recent() {
    local recent_projects="$1"
    local state_path="$2"
    local name_width
    local name last_used visits project_path display_name display_last display_path recent_json
    local index=1
    name_width=$(cdp_recent_name_width "$recent_projects")
    echo -e "\n${CYAN}cdp recent${NC} ${GRAY}($(line_count "$recent_projects") shown)${NC}"
    echo -e "${GRAY}$(printf -- '-%.0s' {1..110})${NC}"
    printf "  ${GRAY}%-4s${NC} ${CYAN}%-*s${NC} ${GRAY}%-24s %-7s %s${NC}\n" "#" "$name_width" "Project" "Last used" "Visits" "Path"
    echo -e "${GRAY}$(printf -- '-%.0s' {1..110})${NC}"
    while IFS=$'\t' read -r name last_used visits project_path; do
        display_name=$(truncate_text "$name" "$name_width")
        display_last=$(truncate_text "$last_used" 24)
        recent_json=$(jq -c --arg name "$name" --arg root "$project_path" \
            '.recentProjects[] | select(.name == $name and .rootPath == $root)' "$state_path" | head -n1)
        if cdp_resolve_project_json "$recent_json"; then
            display_path="$CDP_PROJECT_RESOLVED_PATH"
        else
            display_path="$project_path"
        fi
        printf "  ${GRAY}%02d  ${NC} ${GREEN}%-*s${NC} ${GRAY}%-24s ${CYAN}%-7s${NC} ${GRAY}%s${NC}\n" "$index" "$name_width" "$display_name" "$display_last" "$visits" "$display_path"
        ((index++))
    done <<< "$recent_projects"

    echo -e "${GRAY}$(printf -- '-%.0s' {1..110})${NC}"
    echo -e "${GRAY}state: $state_path${NC}"
}

cdp-recent() {
    cdp_parse_safety_options "$@" || return 1
    set -- "${CDP_SAFETY_ARGS[@]}"
    if [[ "${1:-}" == reset ]]; then
        [[ $# -eq 1 ]] || { echo "Error: recent reset accepts no other arguments." >&2; return 1; }
        cdp_reset_recent
        return
    fi
    if $CDP_SAFETY_DRY_RUN || $CDP_SAFETY_YES; then
        echo "Error: recent safety options require the reset action." >&2
        return 1
    fi
    [[ $# -le 1 ]] || { echo "Error: recent accepts a positive count or reset." >&2; return 1; }
    local count="${1:-10}"
    local state_path recent_projects
    command -v jq &>/dev/null || { echo -e "${RED}Error: 'jq' command not found. Please install jq.${NC}"; return 1; }
    if ! [[ "$count" =~ ^[0-9]+$ ]] || [[ "$count" -le 0 ]]; then count=10; fi
    state_path=$(cdp_state_path)
    if [[ ! -f "$state_path" ]]; then
        echo -e "${YELLOW}No recent projects yet. Switch with cdp first.${NC}"
        return 0
    fi
    recent_projects=$(cdp_recent_rows "$state_path" "$count")
    if [[ -z "$recent_projects" ]]; then
        echo -e "${YELLOW}No recent projects yet. Switch with cdp first.${NC}"
        return 0
    fi
    cdp_render_recent "$recent_projects" "$state_path"
}

# Function to add current directory as a project
