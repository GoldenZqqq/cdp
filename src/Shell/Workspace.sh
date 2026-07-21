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
            echo "Error: Unsupported launcher '$opener'. Use code, cursor, codex, claude, or gemini." >&2
            return 1
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
    cdp_workspace_parse_args "$@" || return 1
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq command not found." >&2
        return 1
    fi
    if [[ -z "$CDP_WORKSPACE_CONFIG_PATH" ]]; then
        CDP_WORKSPACE_CONFIG_PATH=$(get_default_config 2>/dev/null)
    fi
    local config_dir workspace_path workspaces_json projects_json
    config_dir=$(dirname "$CDP_WORKSPACE_CONFIG_PATH" 2>/dev/null)
    workspace_path="$config_dir/workspaces.json"
    workspaces_json=$(cdp_workspace_read_json "$workspace_path") || return 1

    case "$CDP_WORKSPACE_ACTION" in
        usage)
            echo "Usage: cdp workspace <name> | cdp workspace list | cdp workspace add <name> <projects...>"
            return 0
            ;;
        list) cdp_workspace_list_action "$workspaces_json"; return ;;
        remove) cdp_workspace_remove_action "$workspace_path" "$workspaces_json" "$CDP_WORKSPACE_NAME"; return ;;
    esac

    if [[ ! -f "$CDP_WORKSPACE_CONFIG_PATH" ]] || ! jq -e 'type == "array"' "$CDP_WORKSPACE_CONFIG_PATH" >/dev/null 2>&1; then
        echo "Error: project configuration must be an existing JSON array: $CDP_WORKSPACE_CONFIG_PATH" >&2
        return 1
    fi
    projects_json=$(cat "$CDP_WORKSPACE_CONFIG_PATH")
    case "$CDP_WORKSPACE_ACTION" in
        show) cdp_workspace_show_action "$workspaces_json" "$projects_json" "$CDP_WORKSPACE_NAME" ;;
        add) cdp_workspace_add_action "$workspace_path" "$workspaces_json" "$projects_json" "$CDP_WORKSPACE_NAME" "${CDP_WORKSPACE_PROJECTS[@]}" ;;
        edit) cdp_workspace_edit_action "$workspace_path" "$workspaces_json" "$projects_json" "$CDP_WORKSPACE_NAME" "${CDP_WORKSPACE_PROJECTS[@]}" ;;
        validate) cdp_workspace_validate_action "$workspace_path" "$workspaces_json" "$projects_json" "$CDP_WORKSPACE_NAME" ;;
        open) cdp_workspace_launch_action "$workspaces_json" "$projects_json" "$CDP_WORKSPACE_NAME" ;;
        *) echo "Error: unsupported workspace action: $CDP_WORKSPACE_ACTION" >&2; return 1 ;;
    esac
}

# Main cdp function
