# cdp shell domain: Scan.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

find_git_repos() {
    local root="$1"
    local depth="${2:-4}"

    if [[ -e "$root/.git" ]]; then
        (cd "$root" && pwd -P)
        return
    fi

    if [[ "$depth" -le 0 ]]; then
        return
    fi

    local child
    while IFS= read -r -d $'\0' child; do
        [[ "$(basename "$child")" == ".git" ]] && continue
        find_git_repos "$child" $((depth - 1))
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
}

project_name_exists() {
    local name="$1"
    local config_path="$2"

    jq -e --arg name "$name" '.[] | select(.name == $name)' "$config_path" >/dev/null 2>&1
}

unique_project_name() {
    local project_path="$1"
    local config_path="$2"
    local base_name
    local parent_name
    local candidate
    local index=2

    base_name=$(basename "$project_path")
    if ! project_name_exists "$base_name" "$config_path"; then
        echo "$base_name"
        return
    fi

    parent_name=$(basename "$(dirname "$project_path")")
    if [[ -n "$parent_name" ]]; then
        candidate="${parent_name}-${base_name}"
    else
        candidate="$base_name"
    fi

    local candidate_root="$candidate"
    while project_name_exists "$candidate" "$config_path"; do
        candidate="${candidate_root}-${index}"
        ((index++))
    done

    echo "$candidate"
}


cdp-init() {
    cdp_parse_safety_options "$@" || return 1
    set -- "${CDP_SAFETY_ARGS[@]}"
    local root_path="${1:-}"
    local config_path="${2:-}"
    local max_depth="${3:-4}"
    [[ $# -le 3 ]] || { echo -e "${RED}Error: init accepts root path, config path, and max depth.${NC}"; return 1; }

    if [[ -z "$config_path" ]]; then
        config_path="$HOME/.cdp/projects.json"
    fi

    echo -e "${YELLOW}Initialization plan:${NC} create/select $config_path"
    local approval_status=0
    cdp_require_high_risk_approval "cdp initialization" || approval_status=$?
    if [[ $approval_status -eq 2 ]]; then
        cdp_action_result initialize-cdp "$config_path" preview false
        if [[ -n "$root_path" ]]; then
            cdp-scan "$root_path" "$config_path" "$max_depth" --dry-run
        fi
        return 0
    fi
    [[ $approval_status -eq 0 ]] || return 1

    initialize_config "$config_path"
    save_config_choice "$config_path"

    cdp_brand_header
    echo -e "${GRAY}Config:${NC} ${CYAN}$config_path${NC}"
    echo -e "${GREEN}Saved active config choice.${NC}"

    if command -v fzf &> /dev/null; then
        echo -e "${GREEN}fzf: found${NC}"
    else
        echo -e "${YELLOW}fzf: not found. Install it with your package manager.${NC}"
    fi

    if command -v jq &> /dev/null; then
        echo -e "${GREEN}jq: found${NC}"
    else
        echo -e "${YELLOW}jq: not found. Install jq before using the bash/zsh version.${NC}"
    fi

    if [[ -n "$root_path" ]]; then
        cdp-scan "$root_path" "$config_path" "$max_depth" --yes
    fi
    cdp_action_result initialize-cdp "$config_path" succeeded true
}


cdp-scan() {
    cdp_parse_safety_options "$@" || return 1
    set -- "${CDP_SAFETY_ARGS[@]}"
    local root_path="${1:-}"
    local config_path="${2:-}"
    local max_depth="${3:-4}"
    [[ $# -le 3 ]] || { echo -e "${RED}Error: scan accepts root path, config path, and max depth.${NC}"; return 1; }

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' command not found. Please install jq.${NC}"
        return 1
    fi

    if [[ -z "$root_path" ]]; then
        root_path="$PWD"
    fi

    root_path=$(cd "$root_path" 2>/dev/null && pwd -P)
    if [[ -z "$root_path" || ! -d "$root_path" ]]; then
        echo -e "${RED}Error: Invalid scan path.${NC}"
        return 1
    fi

    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    local repos
    repos=$(find_git_repos "$root_path" "$max_depth" | sort -u)

    local found_count=0
    local added_count=0
    local skipped_count=0
    local repo
    local expected_fingerprint
    expected_fingerprint=$(cdp_json_fingerprint "$config_path")
    local config_json='[]'
    if [[ -f "$config_path" ]]; then
        config_json=$(cat "$config_path") || return 1
    fi

    if [[ -n "$repos" ]]; then
        while IFS= read -r repo <&3; do
            [[ -z "$repo" ]] && continue
            ((found_count += 1))

            if cdp_find_project_by_local_path_json "$config_json" "$repo" >/dev/null; then
                ((skipped_count += 1))
                continue
            fi

            local name
            local base_name
            base_name=$(basename "$repo")
            name="$base_name"
            local suffix=2
            while jq -e --arg name "$name" '.[] | select((.name | ascii_downcase) == ($name | ascii_downcase))' <<< "$config_json" >/dev/null 2>&1; do
                name="$base_name-$suffix"
                suffix=$((suffix + 1))
            done
            local new_project
            new_project=$(cdp_new_project_json "$name" "$repo") || return 1
            config_json=$(jq --argjson project "$new_project" '. += [$project]' <<< "$config_json") || return 1
            ((added_count += 1))
        done 3<<< "$repos"
    fi

    echo -e "${CYAN}Git repositories found:${NC} $found_count"
    echo -e "${GREEN}Projects added:${NC} $added_count"
    echo -e "${YELLOW}Projects skipped:${NC} $skipped_count"
    echo -e "${GRAY}Config:${NC} $config_path"

    if [[ $added_count -eq 0 ]]; then
        cdp_action_result scan-import "$root_path" skipped false
        return 0
    fi
    local approval_status=0
    cdp_require_high_risk_approval "import of $added_count repositories" || approval_status=$?
    if [[ $approval_status -eq 2 ]]; then
        cdp_action_result scan-import "$root_path" preview false
        return 0
    fi
    [[ $approval_status -eq 0 ]] || return 1

    if ! cdp_write_json_text "$config_path" "$config_json" "$expected_fingerprint"; then
        cdp_action_result scan-import "$root_path" failed false write-failed
        return 1
    fi
    cdp_action_result scan-import "$root_path" succeeded true
}

# Function to diagnose cdp setup
