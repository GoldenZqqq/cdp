# cdp shell domain: ProjectMetadata.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

set_project_pin() {
    local pinned="$1"
    shift
    cdp_parse_safety_options "$@" || return 1
    set -- "${CDP_SAFETY_ARGS[@]}"
    local name="${1:-}"
    local config_path="${2:-}"
    [[ $# -le 2 ]] || { echo -e "${RED}Error: pin accepts a project and config path.${NC}"; return 1; }

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' command not found. Please install jq.${NC}"
        return 1
    fi

    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    local matches
    local expected_fingerprint
    expected_fingerprint=$(cdp_json_fingerprint "$config_path")
    local config_json='[]'
    if [[ -f "$config_path" ]]; then
        config_json=$(cat "$config_path") || return 1
        if [[ -z "$name" ]]; then
            matches=$(jq -r --arg path "$PWD" '.[] | select(.rootPath == $path) | .name' <<< "$config_json" 2>/dev/null)
        else
            matches=$(find_project_matches "$config_path" "$name")
        fi
    else
        matches=""
    fi

    local match_count
    match_count=$(line_count "$matches")
    if [[ "$match_count" -eq 0 ]]; then
        echo -e "${YELLOW}No project matched for pin update.${NC}"
        return 1
    fi

    if [[ "$match_count" -gt 1 ]]; then
        echo -e "${YELLOW}Multiple projects matched. Please use a more specific name.${NC}"
        printf '%s\n' "$matches" | sed 's/^/  /'
        return 1
    fi

    local target
    local state_text="Pinned"
    target="$matches"
    if [[ "$pinned" != "true" ]]; then
        state_text="Unpinned"
    fi

    local current_pinned
    current_pinned=$(jq -r --arg name "$target" '.[] | select(.name == $name) | (.pinned == true)' <<< "$config_json" | head -n1)
    if [[ "$current_pinned" == "$pinned" ]]; then
        echo -e "${YELLOW}Project already has the requested pin state: $target${NC}"
        cdp_action_result "$(echo "$state_text" | tr '[:upper:]' '[:lower:]')" "$target" skipped false
        return 0
    fi
    local new_json
    new_json=$(jq --arg name "$target" --argjson pinned "$pinned" '
        map(if .name == $name then . + {"pinned": $pinned} else . end)
    ' <<< "$config_json") || return 1
    if $CDP_SAFETY_DRY_RUN; then
        echo -e "${GRAY}Dry run: no pin state was changed.${NC}"
        cdp_action_result "$(echo "$state_text" | tr '[:upper:]' '[:lower:]')" "$target" preview false
        return 0
    fi
    local temp_file
    temp_file=$(cdp_json_temp_file "$config_path") || return 1
    printf '%s\n' "$new_json" > "$temp_file"
    cdp_commit_json_file "$config_path" "$temp_file" "$expected_fingerprint" || { rm -f -- "$temp_file"; return 1; }
    rm -f -- "$temp_file"

    echo -e "${GREEN}$state_text project: $target${NC}"
    cdp_action_result "$(echo "$state_text" | tr '[:upper:]' '[:lower:]')" "$target" succeeded true
}

cdp-pin() {
    set_project_pin true "$@"
}

cdp-unpin() {
    set_project_pin false "$@"
}


update_project_list_value() {
    local property="$1"
    local remove="$2"
    shift 2
    cdp_parse_safety_options "$@" || return 1
    set -- "${CDP_SAFETY_ARGS[@]}"
    local name="${1:-}"
    local value="${2:-}"
    local config_path="${3:-}"
    [[ $# -le 3 ]] || { echo -e "${RED}Error: metadata update accepts project, value, and config path.${NC}"; return 1; }

    if [[ -z "$name" || -z "$value" ]]; then
        echo -e "${YELLOW}Project name and metadata value are required.${NC}"
        return 1
    fi

    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    [[ -f "$config_path" ]] || { echo -e "${RED}Error: Configuration file not found at: $config_path${NC}"; return 1; }

    local matches
    local match_count
    local expected_fingerprint
    expected_fingerprint=$(cdp_json_fingerprint "$config_path")
    matches=$(find_project_matches "$config_path" "$name")
    match_count=$(line_count "$matches")
    if [[ "$match_count" -ne 1 ]]; then
        echo -e "${YELLOW}Expected one project match, found $match_count.${NC}"
        return 1
    fi

    local target
    target="$matches"
    local current_value
    current_value=$(jq -r --arg name "$target" --arg value "$value" --arg property "$property" '
        .[] | select(.name == $name) | (((.[$property] // []) | map(tostring) | map(ascii_downcase) | index($value | ascii_downcase)) != null)
    ' "$config_path")
    if { [[ "$remove" == true && "$current_value" != true ]] || [[ "$remove" != true && "$current_value" == true ]]; }; then
        echo -e "${YELLOW}Project metadata already has the requested state.${NC}"
        cdp_action_result metadata-update "$target" skipped false
        return 0
    fi
    local new_json
    new_json=$(jq --arg name "$target" --arg value "$value" --arg property "$property" --argjson remove "$remove" '
        map(if .name == $name then
            .[$property] = (
                ((.[$property] // []) | map(tostring)) as $values |
                if $remove then
                    ($values | map(select((ascii_downcase) != ($value | ascii_downcase))))
                elif (($values | map(ascii_downcase) | index($value | ascii_downcase)) == null) then
                    $values + [$value]
                else
                    $values
                end
            )
        else . end)
    ' "$config_path") || return 1
    if $CDP_SAFETY_DRY_RUN; then
        echo -e "${GRAY}Dry run: no project metadata was changed.${NC}"
        cdp_action_result metadata-update "$target" preview false
        return 0
    fi
    local temp_file
    temp_file=$(cdp_json_temp_file "$config_path") || return 1
    printf '%s\n' "$new_json" > "$temp_file"
    cdp_commit_json_file "$config_path" "$temp_file" "$expected_fingerprint" || { rm -f -- "$temp_file"; return 1; }
    rm -f -- "$temp_file"

    echo -e "${GREEN}Updated $property for project: $target${NC}"
    cdp_action_result metadata-update "$target" succeeded true
}

cdp-alias() {
    update_project_list_value aliases false "$@"
}

cdp-unalias() {
    update_project_list_value aliases true "$@"
}

cdp-tag() {
    update_project_list_value tags false "$@"
}

cdp-untag() {
    update_project_list_value tags true "$@"
}
