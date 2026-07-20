# cdp shell domain: Commands.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

cdp() {
    if [[ "${1:-}" =~ ^(hook|hooks)$ && "${2:-}" =~ ^(list|trust|revoke)$ ]]; then
        shift
        cdp-hook "$@"
        return
    fi

    case "$1" in
        exec|run)
            shift
            cdp-exec "$@"
            return
            ;;
        status|st)
            shift
            cdp-status "$@"
            return
            ;;
        workspace|ws)
            shift
            cdp-workspace "$@"
            return
            ;;
        doctor|health|check)
            shift
            local doctor_fix=false
            local doctor_args=()
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --fix|-f) doctor_fix=true ;;
                    *) doctor_args+=("$1") ;;
                esac
                shift
            done
            if $doctor_fix; then
                cdp-clean "${doctor_args[@]}"
            else
                cdp_parse_safety_options "${doctor_args[@]}" || return 1
                if $CDP_SAFETY_DRY_RUN || $CDP_SAFETY_YES; then
                    echo -e "${RED}Error: safety options require doctor --fix.${NC}"
                    return 1
                fi
                cdp-doctor "${CDP_SAFETY_ARGS[@]}"
            fi
            return
            ;;
        config|select-config)
            shift
            cdp-config "$@"
            return
            ;;
        about|version|--version|-v)
            shift
            cdp_about "$@"
            return
            ;;
        recent|recents|history)
            shift
            cdp-recent "$@"
            return
            ;;
        pin|pinned|favorite|star)
            shift
            cdp-pin "$@"
            return
            ;;
        unpin|unfavorite|unstar)
            shift
            cdp-unpin "$@"
            return
            ;;
        clean|repair|fix)
            shift
            cdp-clean "$@"
            return
            ;;
        add|add-project)
            shift
            cdp-add "$@"
            return
            ;;
        remove|rm|delete)
            shift
            cdp-rm "$@"
            return
            ;;
        alias|add-alias)
            shift
            cdp-alias "$@"
            return
            ;;
        unalias|remove-alias)
            shift
            cdp-unalias "$@"
            return
            ;;
        tag|add-tag)
            shift
            cdp-tag "$@"
            return
            ;;
        untag|remove-tag)
            shift
            cdp-untag "$@"
            return
            ;;
        init|setup)
            shift
            cdp-init "$@"
            return
            ;;
        scan|import)
            shift
            cdp-scan "$@"
            return
            ;;
    esac

    local query=""
    local config_path=""
    local opener=""
    local allow_hook=false
    local no_hook=false
    local -a positional_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --open|-o)
                if [[ -z "${2:-}" ]]; then
                    echo -e "${RED}Error: missing launcher after $1.${NC}"
                    return 1
                fi
                opener="$2"
                shift 2
                ;;
            --allow-hook|-allow-hook)
                allow_hook=true
                shift
                ;;
            --no-hook|-no-hook)
                no_hook=true
                shift
                ;;
            *)
                positional_args+=("$1")
                shift
                ;;
        esac
    done

    if [[ "$allow_hook" == true && "$no_hook" == true ]]; then
        echo -e "${RED}Error: --allow-hook and --no-hook cannot be used together.${NC}"
        return 1
    fi

    if [[ ${#positional_args[@]} -gt 0 ]]; then
        if is_config_path_arg "${positional_args[0]}"; then
            config_path="${positional_args[0]}"
        else
            query="${positional_args[0]}"
            if [[ ${#positional_args[@]} -gt 1 ]]; then
                config_path="${positional_args[1]}"
            fi
        fi
    fi

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' command not found.${NC}"
        echo -e "${CYAN}Please install jq first:${NC}"
        echo -e "${CYAN}  Ubuntu/Debian: sudo apt install jq${NC}"
        echo -e "${CYAN}  Fedora: sudo dnf install jq${NC}"
        echo -e "${CYAN}  Arch: sudo pacman -S jq${NC}"
        echo -e "${CYAN}  macOS: brew install jq${NC}"
        return 1
    fi

    # Get config path
    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    # Initialize config if it's the custom path and doesn't exist
    local custom_config="$HOME/.cdp/projects.json"
    if [[ "$config_path" == "$custom_config" ]]; then
        initialize_config "$config_path"
    fi

    # Check if config exists
    if [[ ! -f "$config_path" ]]; then
        echo -e "${RED}Error: Configuration file not found at: $config_path${NC}"
        return 1
    fi

    # Read and parse JSON, filter enabled projects
    local projects
    projects=$(sorted_enabled_project_names "$config_path")

    if [[ -z "$projects" ]]; then
        echo -e "${YELLOW}No enabled projects found in configuration.${NC}"
        return 1
    fi

    local selected=""

    if [[ -n "$query" ]]; then
        local matches
        local match_count

        matches=$(find_project_matches "$config_path" "$query")
        match_count=$(line_count "$matches")

        if [[ "$match_count" -eq 0 ]]; then
            echo -e "${YELLOW}No project matched query: $query${NC}"
            return 1
        fi

        if [[ "$match_count" -eq 1 ]]; then
            selected="$matches"
        else
            projects="$matches"
        fi
    fi

    # Launch fzf for selection
    if [[ -z "$selected" ]]; then
        if ! command -v fzf &> /dev/null; then
            echo -e "${RED}Error: 'fzf' command not found.${NC}"
            echo -e "${CYAN}Please install fzf first:${NC}"
            echo -e "${CYAN}  Ubuntu/Debian: sudo apt install fzf${NC}"
            echo -e "${CYAN}  Fedora: sudo dnf install fzf${NC}"
            echo -e "${CYAN}  Arch: sudo pacman -S fzf${NC}"
            echo -e "${CYAN}  macOS: brew install fzf${NC}"
            return 1
        fi

        # Note: --no-mouse prevents IME mouse click conflicts with candidate selection
        local prompt="Select project: "
        if [[ -n "$query" ]]; then
            prompt="cdp ($query) > "
        else
            prompt="cdp > "
        fi
        local total_count
        local shown_count
        local header
        local preview_dir
        local selected_line
        total_count=$(jq '[.[] | select(.enabled == true)] | length' "$config_path" 2>/dev/null || echo 0)
        shown_count=$(line_count "$projects")
        header=$(cdp_picker_header "$shown_count" "$total_count" "$config_path")
        preview_dir=$(mktemp -d "${TMPDIR:-/tmp}/cdp-fzf.XXXXXX")

        selected_line=$(cdp_picker_rows "$projects" "$config_path" "$preview_dir" | fzf \
            --prompt="$prompt" \
            --header="$header" \
            --height=70% \
            --layout=reverse \
            --border=rounded \
            --border-label=" cdp warp " \
            --ansi \
            --delimiter=$'\t' \
            --with-nth=4,5,6 \
            --nth=2,3 \
            --no-mouse \
            --preview="cat '$preview_dir/{1}.txt'" \
            --preview-window=right:50%:wrap \
            --pointer=">" \
            --marker="*" \
            --color="fg:#cdd6f4,bg:-1,hl:#89dceb,fg+:#ffffff,bg+:#313244,hl+:#f5c2e7,prompt:#94e2d5,pointer:#f38ba8,marker:#a6e3a1,border:#89b4fa,header:#bac2de,info:#fab387")

        if [[ -n "$preview_dir" && -d "$preview_dir" ]]; then
            rm -rf "$preview_dir"
        fi

        if [[ -n "$selected_line" ]]; then
            selected=$(printf '%s' "$selected_line" | cut -f2)
        fi
    fi

    # Process selection
    # Note: Don't check exit code to avoid IME-related false cancellations
    # Only check if a project was actually selected
    if [[ -z "$selected" ]]; then
        # User cancelled or no selection made
        return 0
    fi

    local selected_project_json
    selected_project_json=$(cdp_project_json_by_name "$config_path" "$selected")

    if [[ -n "$selected_project_json" ]]; then
        if ! cdp_resolve_project_json "$selected_project_json"; then
            echo -e "${RED}Error: $CDP_PROJECT_PATH_ERROR_MESSAGE${NC}"
            echo -e "${GRAY}Project: $selected; profile: $CDP_PROJECT_PATH_PROFILE${NC}"
            return 1
        fi
        local raw_project_path="$CDP_PROJECT_RAW_PATH"
        local project_path="$CDP_PROJECT_RESOLVED_PATH"

        # Check if path exists
        if [[ -d "$project_path" ]]; then
            cd "$project_path" || return 1
            cdp_record_recent "$selected" "$raw_project_path" "$selected_project_json"
            echo -e "${GREEN}Switched to project: $selected${NC}"
            echo -e "${GRAY}Path: $project_path${NC}"

            # Update terminal title (works in most terminals)
            echo -ne "\033]0;$selected\007"

            # Apply safe environment values and run command hooks only on explicit opt-in.
            local on_enter
            on_enter=$(printf '%s' "$selected_project_json" | jq -r '.onEnter // empty' 2>/dev/null)
            on_enter="${on_enter%$'\r'}"
            if [[ -n "$on_enter" && "$on_enter" != "null" ]]; then
                cdp_apply_on_enter "$on_enter" "$allow_hook" "$config_path" "$selected_project_json" "$no_hook"
            fi

            if [[ -n "$opener" ]]; then
                cdp_open_workspace "$opener" "$selected" "$project_path"
            fi
        else
            echo -e "${RED}Error: Directory not found: $project_path${NC}"
            return 1
        fi
    else
        echo -e "${RED}Error: Could not find path for project '$selected'.${NC}"
        return 1
    fi
}

# Function to list projects
cdp-ls() {
    local config_path="$1"

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' command not found. Please install jq.${NC}"
        return 1
    fi

    # Get config path
    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    # Initialize config if needed
    local custom_config="$HOME/.cdp/projects.json"
    if [[ "$config_path" == "$custom_config" ]]; then
        initialize_config "$config_path"
    fi

    # Check if config exists
    if [[ ! -f "$config_path" ]]; then
        echo -e "${RED}Error: Configuration file not found at: $config_path${NC}"
        return 1
    fi

    # Read enabled projects
    local enabled_projects
    enabled_projects=$(sorted_enabled_project_rows "$config_path")

    if [[ -z "$enabled_projects" ]]; then
        echo -e "${YELLOW}No enabled projects found.${NC}"
        return 0
    fi

    # Count projects
    local count=$(line_count "$enabled_projects")
    local name_width=14
    while IFS=$'\t' read -r name pinned project_path; do
        if (( ${#name} > name_width )); then
            name_width=${#name}
        fi
    done <<< "$enabled_projects"
    if (( name_width > 30 )); then
        name_width=30
    fi

    echo -e "\n${CYAN}cdp projects${NC} ${GRAY}($count enabled)${NC}"
    echo -e "${GRAY}$(printf -- '-%.0s' {1..96})${NC}"
    printf "  ${GRAY}%-4s${NC} ${GRAY}%-5s${NC} ${CYAN}%-*s${NC} ${GRAY}%s${NC}\n" "#" "Pin" "$name_width" "Project" "Path"
    echo -e "${GRAY}$(printf -- '-%.0s' {1..96})${NC}"

    local index=1
    while IFS=$'\t' read -r name pinned project_path; do
        local display_path
        local display_name
        local pin_text=""
        local project_json
        project_json=$(cdp_project_json_by_name "$config_path" "$name")
        if cdp_resolve_project_json "$project_json"; then
            display_path="$CDP_PROJECT_RESOLVED_PATH"
        else
            display_path="<invalid ${CDP_PROJECT_PATH_SOURCE:-path profile}>"
        fi
        display_name=$(truncate_text "$name" "$name_width")
        if [[ "$pinned" == "true" ]]; then
            pin_text="*"
        fi
        printf "  ${GRAY}%02d  ${NC} ${YELLOW}%-5s${NC} ${GREEN}%-*s${NC} ${GRAY}%s${NC}\n" "$index" "$pin_text" "$name_width" "$display_name" "$display_path"
        ((index++))
    done <<< "$enabled_projects"

    echo -e "${GRAY}$(printf -- '-%.0s' {1..96})${NC}"
    echo -e "${GRAY}config: $config_path${NC}"
}
