# cdp shell domain: Config.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

get_stored_config_choice() {
    local config_choice_file="$HOME/.cdp/config"
    if [[ -f "$config_choice_file" ]]; then
        local stored_path=$(cat "$config_choice_file" 2>/dev/null | tr -d '\n\r')
        if [[ -n "$stored_path" ]]; then
            echo "$stored_path"
        fi
    fi
}

# Function to save config choice
save_config_choice() {
    local config_path="$1"
    local config_choice_file="$HOME/.cdp/config"
    local config_dir=$(dirname "$config_choice_file")

    mkdir -p "$config_dir"
    echo -n "$config_path" > "$config_choice_file"
}


get_all_available_configs() {
    local configs=()
    local sources=()

    # Try to find Windows user directory
    local winuser=""

    # Method 1: Try to get from WSLENV or existing Windows env vars
    if [[ -n "${WSLENV:-}" ]] && [[ -n "${USERNAME:-}" ]]; then
        winuser="$USERNAME"
    fi

    # Method 2: Try PowerShell (if available)
    if [[ -z "$winuser" ]] && command -v powershell.exe &> /dev/null; then
        winuser=$(powershell.exe -NoProfile -Command 'Write-Host $env:USERNAME' 2>/dev/null | tr -d '\r\n')
    fi

    # Method 3: Try to detect from current WSL user's Windows home
    if [[ -z "$winuser" ]] && [[ -d "/mnt/c/Users" ]]; then
        local current_user=$(whoami)
        if [[ -d "/mnt/c/Users/$current_user" ]]; then
            winuser="$current_user"
        else
            for userdir in /mnt/c/Users/*/; do
                local dirname=$(basename "$userdir")
                if [[ "$dirname" != "Public" ]] && [[ "$dirname" != "Default" ]] && [[ "$dirname" != "All Users" ]] && [[ "$dirname" != "Default User" ]]; then
                    if [[ -d "$userdir/AppData" ]] || [[ -d "$userdir/Documents" ]]; then
                        winuser="$dirname"
                        break
                    fi
                fi
            done
        fi
    fi

    # Check all possible config locations
    if [[ -n "$winuser" ]]; then
        local appdata="/mnt/c/Users/$winuser/AppData/Roaming"

        local cursor_config="$appdata/Cursor/User/globalStorage/alefragnani.project-manager/projects.json"
        if [[ -f "$cursor_config" ]]; then
            configs+=("$cursor_config")
            sources+=("Cursor Project Manager")
        fi

        local vscode_config="$appdata/Code/User/globalStorage/alefragnani.project-manager/projects.json"
        if [[ -f "$vscode_config" ]]; then
            configs+=("$vscode_config")
            sources+=("VS Code Project Manager")
        fi

        local win_user_config="/mnt/c/Users/$winuser/.cdp/projects.json"
        if [[ -f "$win_user_config" ]]; then
            configs+=("$win_user_config")
            sources+=("Windows User Config (~/.cdp)")
        fi
    fi

    # Check macOS Application Support paths
    if [[ "$(uname -s)" == "Darwin" ]]; then
        local mac_cursor_config="$HOME/Library/Application Support/Cursor/User/globalStorage/alefragnani.project-manager/projects.json"
        if [[ -f "$mac_cursor_config" ]]; then
            configs+=("$mac_cursor_config")
            sources+=("Cursor Project Manager")
        fi

        local mac_vscode_config="$HOME/Library/Application Support/Code/User/globalStorage/alefragnani.project-manager/projects.json"
        if [[ -f "$mac_vscode_config" ]]; then
            configs+=("$mac_vscode_config")
            sources+=("VS Code Project Manager")
        fi
    fi

    # Check WSL local config
    local wsl_config="$HOME/.cdp/projects.json"
    if [[ -f "$wsl_config" ]]; then
        configs+=("$wsl_config")
        sources+=("WSL Local Config (~/.cdp)")
    fi

    # Return results as newline-separated strings
    # Format: path|source
    for i in "${!configs[@]}"; do
        echo "${configs[$i]}|${sources[$i]}"
    done
}

# Function to get default config path
get_default_config() {
    # Priority order:
    # 1. CDP_CONFIG environment variable (highest priority, skip selection)
    # 2. Stored user choice from previous selection (~/.cdp/config)
    # 3. If multiple configs exist, let user choose and save choice
    # 4. Otherwise return the first available or default path

    if [[ -n "$CDP_CONFIG" ]]; then
        echo "$CDP_CONFIG"
        return
    fi

    # Check for stored config choice
    local stored_choice=$(get_stored_config_choice)
    if [[ -n "$stored_choice" ]] && [[ -f "$stored_choice" ]]; then
        echo "$stored_choice"
        return
    fi

    # Find all available configs
    local available_configs=$(get_all_available_configs)

    # If no configs found, return default (will be created)
    if [[ -z "$available_configs" ]]; then
        echo "$HOME/.cdp/projects.json"
        return
    fi

    # Count configs
    local config_count=$(line_count "$available_configs")

    # If only one config, use it without mutating the active-choice file.
    if [[ $config_count -eq 1 ]]; then
        local selected_path=$(echo "$available_configs" | cut -d'|' -f1)
        echo "$selected_path"
        return
    fi

    # Multiple configs resolve deterministically. Persisted selection is an
    # explicit high-impact action through cdp-config.
    local selected_path
    selected_path=$(echo "$available_configs" | head -n 1 | cut -d'|' -f1)
    echo "Warning: multiple configs found; using $selected_path. Use cdp-config to choose explicitly." >&2
    echo "$selected_path"
}

# Function to initialize config file
initialize_config() {
    local config_path="$1"

    if [[ ! -f "$config_path" ]]; then
        cdp_write_json_text "$config_path" '[]' missing || return 1
        echo -e "${GREEN}Created new config file at: $config_path${NC}"
    fi
}


is_config_path_arg() {
    local arg="$1"

    if [[ -z "$arg" ]]; then
        return 1
    fi

    [[ -f "$arg" ||
        "$arg" == *.json ||
        "$arg" == *"/"* ||
        "$arg" == *"\\"* ||
        "$arg" == "~/"* ||
        "$arg" =~ ^[A-Za-z]: ]]
}

line_count() {
    local value="$1"

    if [[ -z "$value" ]]; then
        echo 0
        return
    fi

    local count=0
    while IFS= read -r _; do
        count=$((count + 1))
    done <<< "$value"
    echo "$count"
}

find_project_matches() {
    local config_path="$1"
    local query="$2"
    local exact_matches

    if [[ "$query" == @* ]]; then
        local tag_query="${query#@}"
        jq -r --arg query "$tag_query" '
            ($query | ascii_downcase) as $needle |
            .[] |
            select(.enabled == true) |
            select(((.tags // []) | map(ascii_downcase) | index($needle)) != null) |
            .name
        ' "$config_path" 2>/dev/null
        return
    fi

    exact_matches=$(jq -r --arg query "$query" '
        ($query | ascii_downcase) as $needle |
        .[] |
        select(.enabled == true) |
        select(
            ((.name // "") | ascii_downcase) == $needle or
            (((.aliases // []) | map(ascii_downcase) | index($needle)) != null)
        ) |
        .name
    ' "$config_path" 2>/dev/null)

    if [[ -n "$exact_matches" ]]; then
        printf '%s\n' "$exact_matches"
        return
    fi

    jq -r --arg query "$query" '
        ($query | ascii_downcase) as $needle |
        .[] |
        select(.enabled == true) |
        select(
            ((.name // "") | ascii_downcase | contains($needle)) or
            ((.rootPath // "") | ascii_downcase | contains($needle)) or
            (if ((.paths // null) | type) == "object" then
                ((.paths | to_entries | map(select((.value | type) == "string") | (.value | ascii_downcase | contains($needle)))) | any)
             else false end) or
            (((.aliases // []) | map(ascii_downcase) | map(contains($needle)) | any)) or
            (((.tags // []) | map(ascii_downcase) | map(contains($needle)) | any))
        ) |
        .name
    ' "$config_path" 2>/dev/null
}

sorted_enabled_project_names() {
    local config_path="$1"

    jq -r '
        to_entries
        | map(select(.value.enabled == true))
        | sort_by(if .value.pinned == true then 0 else 1 end, .key)
        | .[].value.name
    ' "$config_path" 2>/dev/null
}

sorted_enabled_project_rows() {
    local config_path="$1"

    jq -r '
        to_entries
        | map(select(.value.enabled == true))
        | sort_by(if .value.pinned == true then 0 else 1 end, .key)
        | .[]
        | [.value.name, ((.value.pinned == true) | tostring), .value.rootPath]
        | @tsv
    ' "$config_path" 2>/dev/null
}


cdp-config() {
    cdp_parse_safety_options "$@" || return 1
    set -- "${CDP_SAFETY_ARGS[@]}"
    local selected_index="${1:-}"
    [[ $# -le 1 ]] || { echo -e "${RED}Error: cdp-config accepts an optional selection number.${NC}"; return 1; }
    echo -e "\n========================================"
    echo -e "  ${CYAN}Change Configuration File${NC}"
    echo -e "========================================"
    echo ""

    # Find all available configs
    local available_configs=$(get_all_available_configs)

    if [[ -z "$available_configs" ]]; then
        echo -e "${YELLOW}No configuration files found.${NC}"
        echo ""
        echo -e "${CYAN}Available options:${NC}"
        echo -e "  ${GRAY}1. Create a custom config with:${NC} ${CYAN}cdp-add${NC}"
        echo -e "  ${GRAY}2. Install Project Manager extension in VS Code/Cursor${NC}"
        return 0
    fi

    # Show current config
    local current_config=$(get_stored_config_choice)
    if [[ -n "$current_config" ]]; then
        echo -e "${CYAN}Current configuration:${NC}"
        local current_source=$(echo "$available_configs" | grep -F "$current_config" | cut -d'|' -f2)
        if [[ -n "$current_source" ]]; then
            echo -e "  ${GREEN}$current_source${NC}"
        fi
        echo -e "  ${GRAY}$current_config${NC}"
        echo ""
    fi

    # Show all available configs
    echo -e "${CYAN}Available configuration files:${NC}"
    echo -e "${GRAY}$(printf '=%.0s' {1..80})${NC}"
    echo ""

    local index=1
    local -a config_paths=()
    local -a config_sources=()
    while IFS='|' read -r config_entry_path source; do
        config_paths+=("$config_entry_path")
        config_sources+=("$source")

        local is_current=""
        if [[ "$config_entry_path" == "$current_config" ]]; then
            is_current=" ${CYAN}(current)${NC}"
        fi

        echo -e "  ${YELLOW}[$index]${NC} ${GREEN}$source${NC}$is_current"
        echo -e "      ${GRAY}$config_entry_path${NC}"
        ((index++))
    done <<< "$available_configs"

    echo ""

    # Get user selection
    local config_count=${#config_paths[@]}
    while true; do
        local selection="$selected_index"
        if [[ -z "$selection" ]]; then
            echo -e "${RED}Configuration selection requires a number plus --yes, or a number plus --dry-run.${NC}"
            return 1
        fi

        if [[ "$selection" == "0" ]]; then
            echo -e "\n${GRAY}Operation cancelled.${NC}"
            return 0
        fi

        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le $config_count ]]; then
            local selected_path="${config_paths[$((selection-1))]}"
            local selected_source="${config_sources[$((selection-1))]}"

            echo -e "${YELLOW}Configuration selection plan:${NC} $selected_source -> $selected_path"
            local approval_status=0
            cdp_require_high_risk_approval "active configuration selection" || approval_status=$?
            if [[ $approval_status -eq 2 ]]; then
                cdp_action_result select-config "$selected_path" preview false
                return 0
            fi
            [[ $approval_status -eq 0 ]] || return 1

            # Save the choice
            save_config_choice "$selected_path"

            echo -e "\n========================================"
            echo -e "  ${GREEN}Configuration Updated!${NC}"
            echo -e "========================================"
            echo ""
            echo -e "${GRAY}Now using:${NC} ${GREEN}$selected_source${NC}"
            echo -e "${GRAY}Path:${NC} ${CYAN}$selected_path${NC}"
            echo -e "${GRAY}Saved to:${NC} ${CYAN}~/.cdp/config${NC}"
            echo ""
            cdp_action_result select-config "$selected_path" succeeded true
            return 0
        else
            echo -e "${RED}Invalid selection. Please enter a number between 0 and $config_count.${NC}"
            return 1
        fi
    done
}
