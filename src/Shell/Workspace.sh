# cdp shell domain: Workspace.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

resolve_workspace_launcher() {
    local opener="$1"

    case "$opener" in
        ''|*[!A-Za-z0-9._:/-]*)
            echo "Error: launcher must be a single executable name or safe path without arguments." >&2
            return 1
            ;;
    esac

    local opener_lower
    opener_lower="$(printf '%s' "$opener" | tr '[:upper:]' '[:lower:]')"
    case "$opener_lower" in
        code|vscode)
            printf 'code\034.\034VS Code\n'
            ;;
        cursor)
            printf 'cursor\034.\034Cursor\n'
            ;;
        codex)
            printf 'codex\034\034Codex\n'
            ;;
        claude)
            printf 'claude\034\034Claude\n'
            ;;
        gemini)
            printf 'gemini\034\034Gemini\n'
            ;;
        *)
            printf '%s\034\034%s\n' "$opener" "$opener"
            ;;
    esac
}

cdp_open_workspace() {
    local opener="$1"
    local project_name="$2"
    local project_path="$3"
    local command_name
    local command_arg
    local label

    if ! resolve_workspace_launcher "$opener" >/dev/null; then
        return 1
    fi
    IFS=$'\034' read -r command_name command_arg label < <(resolve_workspace_launcher "$opener")

    if [[ -n "$CDP_OPEN_DRY_RUN" ]]; then
        echo -e "${GRAY}Would open $project_name with $label.${NC}"
        return 0
    fi

    if ! command -v "$command_name" &> /dev/null; then
        echo -e "${RED}Error: '$command_name' command not found.${NC}"
        return 1
    fi

    echo -e "${CYAN}Opening with $label...${NC}"
    if [[ -n "$command_arg" ]]; then
        "$command_name" "$command_arg"
    else
        "$command_name"
    fi
}


cdp-workspace() {
    cdp_parse_safety_options "$@" || return 1
    set -- "${CDP_SAFETY_ARGS[@]}"
    local action=""
    local config_path=""
    local open_override=""
    local workspace_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --open|-o)
                [[ -z "${2:-}" ]] && { echo -e "${RED}Error: missing value after --open.${NC}"; return 1; }
                [[ -n "$open_override" ]] && { echo -e "${RED}Error: --open specified more than once.${NC}"; return 1; }
                open_override="$2"
                shift 2
                ;;
            --config)
                [[ -z "${2:-}" ]] && { echo -e "${RED}Error: missing value after --config.${NC}"; return 1; }
                [[ -n "$config_path" ]] && { echo -e "${RED}Error: --config specified more than once.${NC}"; return 1; }
                config_path="$2"
                shift 2
                ;;
            *)
                workspace_args+=("$1")
                shift
                ;;
        esac
    done

    set -- "${workspace_args[@]}"
    action="${1:-}"
    [[ $# -gt 0 ]] && shift

    if [[ -n "$open_override" ]] && ! resolve_workspace_launcher "$open_override" >/dev/null; then
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        echo -e "${RED}Error: 'jq' command not found.${NC}"
        return 1
    fi

    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config 2>/dev/null)
    fi
    local config_dir
    config_dir=$(dirname "$config_path" 2>/dev/null)
    local ws_path="${config_dir}/workspaces.json"

    case "$action" in
        --list|-l|list)
            if $CDP_SAFETY_DRY_RUN || $CDP_SAFETY_YES; then
                echo -e "${RED}Error: workspace --list does not accept safety options.${NC}"
                return 1
            fi
            if [[ $# -gt 0 ]]; then
                echo -e "${RED}Error: workspace --list does not accept project arguments.${NC}"
                return 1
            fi
            if [[ ! -f "$ws_path" ]]; then
                echo -e "${YELLOW}No workspaces defined.${NC}"
                echo -e "${GRAY}Create one: cdp workspace --add <name> <project1> <project2> ...${NC}"
                return
            fi
            echo ""
            echo -e "${CYAN}cdp workspaces${NC}"
            printf '%.0s-' {1..60}; echo ""
            jq -r '.[] | "  [0;32m\(.name)[0m\(if .open then " [[0;36m\(.open)[0m]" else "" end) -> [0;90m\(.projects | join(", "))[0m"' "$ws_path" 2>/dev/null
            printf '%.0s-' {1..60}; echo ""
            ;;
        --add|-a|add)
            local ws_name="${1:-}"
            [[ $# -gt 0 ]] && shift
            local ws_projects=("$@")
            local expected_fingerprint=missing

            if [[ -z "$ws_name" || ${#ws_projects[@]} -eq 0 ]]; then
                echo -e "${YELLOW}Usage: cdp workspace --add <name> <project1> <project2> ...${NC}"
                return
            fi

            if [[ -f "$ws_path" ]]; then
                expected_fingerprint=$(cdp_json_fingerprint "$ws_path")
                if jq -e --arg n "$ws_name" '.[] | select(.name == $n)' "$ws_path" &>/dev/null; then
                    echo -e "${YELLOW}Workspace '$ws_name' already exists.${NC}"
                    return
                fi
            fi

            local projects_json
            projects_json=$(printf '%s\n' "${ws_projects[@]}" | jq -R . | jq -s .)

            local new_ws
            if [[ -n "$open_override" ]]; then
                new_ws=$(jq -n --arg name "$ws_name" --argjson projects "$projects_json" --arg open "$open_override" '{name: $name, projects: $projects, open: $open}')
            else
                new_ws=$(jq -n --arg name "$ws_name" --argjson projects "$projects_json" '{name: $name, projects: $projects}')
            fi

            if $CDP_SAFETY_DRY_RUN; then
                echo -e "${GRAY}Dry run: workspace '$ws_name' was not created.${NC}"
                cdp_action_result add-workspace "$ws_name" preview false
                return 0
            fi

            if [[ -f "$ws_path" ]]; then
                local existing
                existing=$(cat "$ws_path")
                cdp_write_json_text "$ws_path" "$(echo "$existing" | jq --argjson ws "$new_ws" '. + [$ws]')" "$expected_fingerprint" || return 1
            else
                cdp_write_json_text "$ws_path" "$(echo "[$new_ws]" | jq '.')" "$expected_fingerprint" || return 1
            fi
            echo -e "${GREEN}Workspace '$ws_name' created with ${#ws_projects[@]} projects.${NC}"
            cdp_action_result add-workspace "$ws_name" succeeded true
            ;;
        *)
            local ws_name="$action"
            if [[ -z "$ws_name" ]]; then
                echo -e "${YELLOW}Usage: cdp workspace <name> | cdp workspace --list | cdp workspace --add <name> <projects...>${NC}"
                return
            fi
            if [[ $# -gt 0 ]]; then
                echo -e "${RED}Error: workspace launch accepts one workspace name.${NC}"
                return 1
            fi

            if [[ ! -f "$ws_path" ]]; then
                echo -e "${RED}No workspaces defined.${NC}"
                return
            fi

            local ws_data
            ws_data=$(jq -r --arg n "$ws_name" '.[] | select(.name == $n)' "$ws_path" 2>/dev/null)
            if [[ -z "$ws_data" ]]; then
                echo -e "${RED}Workspace '$ws_name' not found.${NC}"
                local available
                available=$(jq -r '.[].name' "$ws_path" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
                [[ -n "$available" ]] && echo -e "${GRAY}Available: $available${NC}"
                return
            fi

            local ws_open
            ws_open=$(echo "$ws_data" | jq -r '.open // empty')
            [[ -n "$open_override" ]] && ws_open="$open_override"
            local launcher_command=""
            local launcher_arg=""
            local launcher_label=""
            local -a launcher_args=()
            if [[ -n "$ws_open" ]]; then
                if ! resolve_workspace_launcher "$ws_open" >/dev/null; then
                    return 1
                fi
                IFS=$'\034' read -r launcher_command launcher_arg launcher_label < <(resolve_workspace_launcher "$ws_open")
                launcher_args=("$launcher_command")
                [[ -n "$launcher_arg" ]] && launcher_args+=("$launcher_arg")
            fi
            local ws_projects_list
            ws_projects_list=$(echo "$ws_data" | jq -r '.projects[]')

            local -a launch_names=()
            local -a launch_paths=()
            local workspace_failed=false
            echo -e "${YELLOW}Workspace launch plan:${NC} $ws_name"
            while IFS= read -r proj_name <&3; do
                proj_name="${proj_name%$'\r'}"
                [[ -z "$proj_name" ]] && continue
                local planned_path
                planned_path=$(jq -r --arg n "$proj_name" '.[] | select(.enabled == true) | select(.name == $n) | .rootPath' "$config_path" 2>/dev/null | head -1)
                planned_path="${planned_path%$'\r'}"
                planned_path=$(convert_windows_to_wsl "$planned_path")
                if [[ -z "$planned_path" || ! -d "$planned_path" ]]; then
                    echo -e "  ${YELLOW}skip${NC} $proj_name (project/path unavailable)"
                    cdp_action_result launch-workspace-project "$proj_name" failed false project-or-path-missing
                    workspace_failed=true
                    continue
                fi
                launch_names+=("$proj_name")
                launch_paths+=("$planned_path")
                echo -e "  ${CYAN}launch${NC} $proj_name -> ${GRAY}$planned_path${NC}"
            done 3<<< "$ws_projects_list"

            local launch_approval=0
            cdp_require_high_risk_approval "workspace '$ws_name' launch" || launch_approval=$?
            if [[ $launch_approval -eq 2 ]]; then
                for proj_name in "${launch_names[@]}"; do
                    cdp_action_result launch-workspace-project "$proj_name" preview false
                done
                [[ "$workspace_failed" == true ]] && return 1
                return 0
            fi
            [[ $launch_approval -eq 0 ]] || return 1

            local has_tmux=false
            command -v tmux &>/dev/null && has_tmux=true
            local project_index=0
            local proj_name=""
            local proj_path=""

            if $has_tmux; then
                local session_name="cdp-${ws_name}"
                local first=true
                for ((project_index=0; project_index<${#launch_names[@]}; project_index++)); do
                    proj_name="${launch_names[$project_index]}"
                    proj_path="${launch_paths[$project_index]}"

                    if $first; then
                        if [[ ${#launcher_args[@]} -gt 0 ]]; then
                            if ! tmux new-session -d -s "$session_name" -c "$proj_path" -n "$proj_name" "${launcher_args[@]}"; then
                                cdp_action_result launch-workspace-project "$proj_name" failed false tmux-launch-failed
                                workspace_failed=true
                                continue
                            fi
                        else
                            if ! tmux new-session -d -s "$session_name" -c "$proj_path" -n "$proj_name"; then
                                cdp_action_result launch-workspace-project "$proj_name" failed false tmux-launch-failed
                                workspace_failed=true
                                continue
                            fi
                        fi
                        first=false
                    else
                        if [[ ${#launcher_args[@]} -gt 0 ]]; then
                            if ! tmux new-window -t "$session_name" -c "$proj_path" -n "$proj_name" "${launcher_args[@]}"; then
                                cdp_action_result launch-workspace-project "$proj_name" failed false tmux-launch-failed
                                workspace_failed=true
                                continue
                            fi
                        else
                            if ! tmux new-window -t "$session_name" -c "$proj_path" -n "$proj_name"; then
                                cdp_action_result launch-workspace-project "$proj_name" failed false tmux-launch-failed
                                workspace_failed=true
                                continue
                            fi
                        fi
                    fi
                    echo -e "${GREEN}  Opened window: $proj_name${NC}"
                    cdp_action_result launch-workspace-project "$proj_name" succeeded true
                done

                if ! $first; then
                    tmux attach-session -t "$session_name" 2>/dev/null || tmux switch-client -t "$session_name" 2>/dev/null
                fi
            else
                for ((project_index=0; project_index<${#launch_names[@]}; project_index++)); do
                    proj_name="${launch_names[$project_index]}"
                    proj_path="${launch_paths[$project_index]}"
                    echo -e "${CYAN}  $proj_name${NC} -> ${GRAY}$proj_path${NC}"
                    cdp_action_result launch-workspace-project "$proj_name" skipped false tmux-unavailable
                done
                echo ""
                echo -e "${YELLOW}Install tmux for multi-window workspace launching.${NC}"
            fi
            if [[ "$workspace_failed" == true ]]; then
                return 1
            fi
            return 0
            ;;
    esac
}

# Main cdp function
