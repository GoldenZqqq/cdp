# cdp shell domain: State.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

cdp_state_path() {
    if [[ -n "$CDP_STATE_PATH" ]]; then
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

    if jq --arg name "$name" --arg path "$root_path" --arg now "$now" '
        .recentProjects as $recent |
        .recentProjects = (
            (($recent // []) | map(select(.rootPath != $path))) +
            [{
                "name": $name,
                "rootPath": $path,
                "lastVisitedAt": $now,
                "visitCount": (((($recent // []) | map(select(.rootPath == $path)) | .[0].visitCount) // 0) + 1)
            }]
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

cdp-recent() {
    local count="${1:-10}"

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' command not found. Please install jq.${NC}"
        return 1
    fi

    if ! [[ "$count" =~ ^[0-9]+$ ]] || [[ "$count" -le 0 ]]; then
        count=10
    fi

    local state_path
    state_path=$(cdp_state_path)

    if [[ ! -f "$state_path" ]]; then
        echo -e "${YELLOW}No recent projects yet. Switch with cdp first.${NC}"
        return 0
    fi

    local recent_projects
    recent_projects=$(jq -r --argjson count "$count" '
        (.recentProjects // [])
        | sort_by(.lastVisitedAt)
        | reverse
        | .[:$count]
        | .[]
        | [.name, .lastVisitedAt, ((.visitCount // 1) | tostring), .rootPath]
        | @tsv
    ' "$state_path" 2>/dev/null)

    if [[ -z "$recent_projects" ]]; then
        echo -e "${YELLOW}No recent projects yet. Switch with cdp first.${NC}"
        return 0
    fi

    local name_width=14
    local name
    local last_used
    local visits
    local project_path
    while IFS=$'\t' read -r name last_used visits project_path; do
        if (( ${#name} > name_width )); then
            name_width=${#name}
        fi
    done <<< "$recent_projects"
    if (( name_width > 30 )); then
        name_width=30
    fi

    echo -e "\n${CYAN}cdp recent${NC} ${GRAY}($(line_count "$recent_projects") shown)${NC}"
    echo -e "${GRAY}$(printf -- '-%.0s' {1..110})${NC}"
    printf "  ${GRAY}%-4s${NC} ${CYAN}%-*s${NC} ${GRAY}%-24s %-7s %s${NC}\n" "#" "$name_width" "Project" "Last used" "Visits" "Path"
    echo -e "${GRAY}$(printf -- '-%.0s' {1..110})${NC}"

    local index=1
    while IFS=$'\t' read -r name last_used visits project_path; do
        local display_name
        local display_last
        local display_path
        display_name=$(truncate_text "$name" "$name_width")
        display_last=$(truncate_text "$last_used" 24)
        display_path=$(convert_windows_to_wsl "$project_path")
        printf "  ${GRAY}%02d  ${NC} ${GREEN}%-*s${NC} ${GRAY}%-24s ${CYAN}%-7s${NC} ${GRAY}%s${NC}\n" "$index" "$name_width" "$display_name" "$display_last" "$visits" "$display_path"
        ((index++))
    done <<< "$recent_projects"

    echo -e "${GRAY}$(printf -- '-%.0s' {1..110})${NC}"
    echo -e "${GRAY}state: $state_path${NC}"
}

# Function to add current directory as a project
