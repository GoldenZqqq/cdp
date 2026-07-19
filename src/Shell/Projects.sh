# cdp shell domain: Projects.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

cdp-add() {
    cdp_parse_safety_options "$@" || return 1
    set -- "${CDP_SAFETY_ARGS[@]}"
    local name="${1:-}"
    local project_path="${2:-}"
    local config_path="${3:-}"
    [[ $# -le 3 ]] || { echo -e "${RED}Error: cdp-add accepts name, path, and config path.${NC}"; return 1; }
    [[ "$name" != -* && "$project_path" != -* && "$config_path" != -* ]] || {
        echo -e "${RED}Error: unknown cdp-add option.${NC}"; return 1;
    }

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' command not found. Please install jq.${NC}"
        return 1
    fi

    # Determine path to add
    if [[ -z "$project_path" ]]; then
        project_path="$PWD"
    fi

    # Resolve to absolute path
    project_path=$(cd "$project_path" 2>/dev/null && pwd -P || echo "$project_path")

    # Determine project name
    if [[ -z "$name" ]]; then
        name=$(basename "$project_path")
    fi

    # Get config path
    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    # Check if project already exists
    local expected_fingerprint
    expected_fingerprint=$(cdp_json_fingerprint "$config_path")
    local config_json='[]'
    if [[ -f "$config_path" ]]; then
        config_json=$(cat "$config_path") || return 1
    fi
    local existing=$(jq -r --arg path "$project_path" '.[] | select(.rootPath == $path) | .name' <<< "$config_json" 2>/dev/null)

    if [[ -n "$existing" ]]; then
        echo -e "${YELLOW}Project already exists: $existing${NC}"
        echo -e "${GRAY}Path: $project_path${NC}"
        cdp_action_result add-project "$name" skipped false
        return 0
    fi

    # Add new project
    local new_json
    new_json=$(jq --arg name "$name" --arg path "$project_path" \
        '. += [{"name": $name, "rootPath": $path, "enabled": true, "pinned": false, "aliases": [], "tags": []}]' \
        <<< "$config_json") || return 1
    if $CDP_SAFETY_DRY_RUN; then
        echo -e "${GRAY}Dry run: no project entry was added.${NC}"
        cdp_action_result add-project "$name" preview false
        return 0
    fi
    local temp_file
    temp_file=$(cdp_json_temp_file "$config_path") || return 1
    printf '%s\n' "$new_json" > "$temp_file"

    cdp_commit_json_file "$config_path" "$temp_file" "$expected_fingerprint" || { rm -f -- "$temp_file"; return 1; }
    rm -f -- "$temp_file"

    echo -e "${GREEN}Project added successfully!${NC}"
    echo -e "  ${CYAN}Name:${NC} $name"
    echo -e "  ${GRAY}Path:${NC} $project_path"
    echo -e "  ${GRAY}Config:${NC} $config_path"
    cdp_action_result add-project "$name" succeeded true
}

cdp-rm() {
    cdp_parse_safety_options "$@" || return 1
    set -- "${CDP_SAFETY_ARGS[@]}"
    local name="${1:-}"
    local config_path="${2:-}"
    [[ $# -le 2 ]] || { echo -e "${RED}Error: remove accepts a project and config path.${NC}"; return 1; }
    [[ -n "$name" ]] || { echo -e "${RED}Error: remove requires a project name.${NC}"; return 1; }
    [[ -z "$config_path" ]] && config_path=$(get_default_config)
    [[ -f "$config_path" ]] || { echo -e "${RED}Error: Configuration file not found at: $config_path${NC}"; return 1; }

    local matches
    matches=$(find_project_matches "$config_path" "$name")
    local match_count
    match_count=$(line_count "$matches")
    if [[ "$match_count" -ne 1 ]]; then
        echo -e "${RED}Error: remove requires one project match; found $match_count.${NC}"
        return 1
    fi

    local target="$matches"
    local target_path
    target_path=$(jq -r --arg name "$target" '.[] | select(.name == $name) | .rootPath' "$config_path" | head -n1)
    echo -e "${YELLOW}Project removal plan:${NC} $target -> $target_path"
    local approval_status=0
    cdp_require_high_risk_approval "project removal" || approval_status=$?
    if [[ $approval_status -eq 2 ]]; then
        cdp_action_result remove-project "$target" preview false
        return 0
    fi
    if [[ $approval_status -ne 0 ]]; then
        cdp_action_result remove-project "$target" canceled false
        return 1
    fi

    local expected_fingerprint
    local new_json
    expected_fingerprint=$(cdp_json_fingerprint "$config_path")
    new_json=$(jq --arg name "$target" '[.[] | select(.name != $name)]' "$config_path") || return 1
    if ! cdp_write_json_text "$config_path" "$new_json" "$expected_fingerprint"; then
        cdp_action_result remove-project "$target" failed false write-failed
        return 1
    fi
    echo -e "${GREEN}Project removed successfully: $target${NC}"
    cdp_action_result remove-project "$target" succeeded true
}


cdp-clean() {
    cdp_parse_safety_options "$@" || return 1
    set -- "${CDP_SAFETY_ARGS[@]}"
    local config_path="${1:-}"
    [[ $# -le 1 ]] || { echo -e "${RED}Error: clean accepts one config path.${NC}"; return 1; }

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' command not found. Please install jq.${NC}"
        return 1
    fi

    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    if [[ ! -f "$config_path" ]]; then
        echo -e "${RED}Error: Configuration file not found at: $config_path${NC}"
        return 1
    fi

    local expected_fingerprint
    expected_fingerprint=$(cdp_json_fingerprint "$config_path")
    local repaired_json
    repaired_json=$(jq '
        def valid_project:
            (.name | type == "string") and
            (.rootPath | type == "string") and
            ((.name | length) > 0) and
            ((.rootPath | length) > 0);
        reduce .[] as $project (
            {projects: [], paths: {}, names: {}};
            if (($project | valid_project) | not) then
                .
            elif .paths[$project.rootPath] then
                .
            else
                (.names[$project.name] // 0) as $seen |
                ($project + {
                    "name": (if $seen == 0 then $project.name else "\($project.name)-\($seen + 1)" end),
                    "enabled": (if ($project.enabled | type) == "boolean" then $project.enabled else false end),
                    "pinned": (if ($project.pinned | type) == "boolean" then $project.pinned else false end),
                    "aliases": (if ($project.aliases | type) == "array" then $project.aliases else [] end),
                    "tags": (if ($project.tags | type) == "array" then $project.tags else [] end)
                }) as $cleanProject |
                .projects += [$cleanProject] |
                .paths[$project.rootPath] = true |
                .names[$project.name] = ($seen + 1)
            end
        ) | .projects
    ' "$config_path") || return 1

    local missing_count=0
    while IFS=$'\t' read -r name raw_project_path; do
        [[ -z "$name" && -z "$raw_project_path" ]] && continue
        local resolved_path
        resolved_path=$(convert_windows_to_wsl "$raw_project_path")
        if [[ ! -d "$resolved_path" ]]; then
            repaired_json=$(printf '%s\n' "$repaired_json" | jq --arg path "$raw_project_path" 'map(if .rootPath == $path then .enabled = false else . end)')
            ((missing_count += 1))
        fi
    done < <(printf '%s\n' "$repaired_json" | jq -r '.[] | select(.enabled == true) | [.name, .rootPath] | @tsv')

    if jq -e --argjson repaired "$repaired_json" '. == $repaired' "$config_path" >/dev/null 2>&1; then
        echo -e "${GREEN}No project configuration repairs are needed.${NC}"
        cdp_action_result repair-config "$config_path" skipped false
        return 0
    fi

    echo -e "${YELLOW}Repair plan:${NC} $config_path"
    echo -e "${GRAY}  DisabledMissingPaths: $missing_count${NC}"
    local approval_status=0
    cdp_require_high_risk_approval "project configuration repair" || approval_status=$?
    if [[ $approval_status -eq 2 ]]; then
        cdp_action_result repair-config "$config_path" preview false
        return 0
    fi
    [[ $approval_status -eq 0 ]] || return 1

    if ! cdp_write_json_text "$config_path" "$repaired_json" "$expected_fingerprint"; then
        cdp_action_result repair-config "$config_path" failed false write-failed
        return 1
    fi

    echo -e "${GREEN}cdp config repaired:${NC} $config_path"
    echo -e "${GRAY}  DisabledMissingPaths: $missing_count${NC}"
    cdp_action_result repair-config "$config_path" succeeded true
}
