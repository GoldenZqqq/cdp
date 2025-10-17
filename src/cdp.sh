#!/usr/bin/env bash
#
# cdp - Fast project directory switcher for bash/zsh (WSL version)
#
# Compatible with VS Code/Cursor Project Manager and custom JSON configs.
# Shares the same configuration files as the PowerShell version.
#
# Author: GoldenZqqq
# Version: 1.2.0
# License: MIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Function to convert Windows path to WSL path
convert_windows_to_wsl() {
    local path="$1"

    # Check if path looks like Windows path (C:\... or C:/...)
    if [[ "$path" =~ ^([A-Za-z]):[/\\](.*)$ ]]; then
        local drive="${BASH_REMATCH[1],,}"  # Convert to lowercase
        local remainder="${BASH_REMATCH[2]}"

        # Replace backslashes with forward slashes
        remainder="${remainder//\\//}"

        echo "/mnt/$drive/$remainder"
    else
        # Already a Unix path or unknown format
        echo "$path"
    fi
}

# Function to get default config path
get_default_config() {
    # Priority order:
    # 1. CDP_CONFIG environment variable
    # 2. Cursor Project Manager (Windows AppData via WSL) ← Higher priority
    # 3. VS Code Project Manager (Windows AppData via WSL)
    # 4. Custom config in user home (~/.cdp/projects.json) ← Fallback only

    if [[ -n "$CDP_CONFIG" ]]; then
        echo "$CDP_CONFIG"
        return
    fi

    # Try to find Windows AppData via WSL
    local appdata=""
    if [[ -n "$APPDATA" ]]; then
        # If APPDATA env var is set (converted from Windows)
        appdata=$(convert_windows_to_wsl "$APPDATA")
    elif [[ -d "/mnt/c/Users" ]]; then
        # Try to detect current Windows user
        local winuser=$(powershell.exe -NoProfile -Command 'Write-Host $env:USERNAME' 2>/dev/null | tr -d '\r\n')
        if [[ -n "$winuser" ]]; then
            appdata="/mnt/c/Users/$winuser/AppData/Roaming"
        fi
    fi

    if [[ -n "$appdata" ]]; then
        # Check Cursor first
        local cursor_config="$appdata/Cursor/User/globalStorage/alefragnani.project-manager/projects.json"
        if [[ -f "$cursor_config" ]]; then
            echo "$cursor_config"
            return
        fi

        # Check VS Code
        local vscode_config="$appdata/Code/User/globalStorage/alefragnani.project-manager/projects.json"
        if [[ -f "$vscode_config" ]]; then
            echo "$vscode_config"
            return
        fi

        # Also check Windows custom config location
        local windows_custom_config="$appdata/../Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/.cdp/projects.json"
        if [[ -f "$windows_custom_config" ]]; then
            echo "$windows_custom_config"
            return
        fi

        # Check common Windows user profile location
        local win_user_config="/mnt/c/Users/$winuser/.cdp/projects.json"
        if [[ -f "$win_user_config" ]]; then
            echo "$win_user_config"
            return
        fi
    fi

    # Fallback: Custom config path in WSL home (will be created if needed)
    local custom_config="$HOME/.cdp/projects.json"
    echo "$custom_config"
}

# Function to initialize config file
initialize_config() {
    local config_path="$1"

    if [[ ! -f "$config_path" ]]; then
        local config_dir=$(dirname "$config_path")
        mkdir -p "$config_dir"
        echo "[]" > "$config_path"
        echo -e "${GREEN}Created new config file at: $config_path${NC}"
    fi
}

# Main cdp function
cdp() {
    local config_path="$1"

    # Check if fzf is installed
    if ! command -v fzf &> /dev/null; then
        echo -e "${RED}Error: 'fzf' command not found.${NC}"
        echo -e "${CYAN}Please install fzf first:${NC}"
        echo -e "${CYAN}  Ubuntu/Debian: sudo apt install fzf${NC}"
        echo -e "${CYAN}  Fedora: sudo dnf install fzf${NC}"
        echo -e "${CYAN}  Arch: sudo pacman -S fzf${NC}"
        echo -e "${CYAN}  macOS: brew install fzf${NC}"
        return 1
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
    local projects=$(jq -r '.[] | select(.enabled == true) | .name' "$config_path" 2>/dev/null)

    if [[ -z "$projects" ]]; then
        echo -e "${YELLOW}No enabled projects found in configuration.${NC}"
        return 1
    fi

    # Launch fzf for selection
    local selected=$(echo "$projects" | fzf \
        --prompt="Select project: " \
        --height=40% \
        --layout=reverse \
        --border \
        --preview-window=hidden)

    # Process selection
    if [[ -n "$selected" ]]; then
        # Get the rootPath for selected project
        local project_path=$(jq -r --arg name "$selected" \
            '.[] | select(.name == $name and .enabled == true) | .rootPath' \
            "$config_path" 2>/dev/null | head -n1)

        if [[ -n "$project_path" ]]; then
            # Convert Windows path to WSL path if needed
            project_path=$(convert_windows_to_wsl "$project_path")

            # Check if path exists
            if [[ -d "$project_path" ]]; then
                cd "$project_path" || return 1
                echo -e "${GREEN}Switched to project: $selected${NC}"
                echo -e "${GRAY}Path: $project_path${NC}"

                # Update terminal title (works in most terminals)
                echo -ne "\033]0;$selected\007"
            else
                echo -e "${RED}Error: Directory not found: $project_path${NC}"
                return 1
            fi
        else
            echo -e "${RED}Error: Could not find path for project '$selected'.${NC}"
            return 1
        fi
    else
        echo -e "${GRAY}Operation cancelled.${NC}"
        return 0
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
    local enabled_projects=$(jq -r '.[] | select(.enabled == true) | "\(.name)|\(.rootPath)"' "$config_path" 2>/dev/null)

    if [[ -z "$enabled_projects" ]]; then
        echo -e "${YELLOW}No enabled projects found.${NC}"
        return 0
    fi

    # Count projects
    local count=$(echo "$enabled_projects" | wc -l)

    echo -e "\n${CYAN}Enabled Projects ($count):${NC}"
    echo -e "${GRAY}$(printf '=%.0s' {1..80})${NC}"
    echo ""

    local index=1
    while IFS='|' read -r name path; do
        printf "  ${GRAY}[%-3s]${NC} ${GREEN}%s${NC}\n" "$index" "$name"

        # Convert Windows path for display
        local display_path=$(convert_windows_to_wsl "$path")
        printf "         ${GRAY}%s${NC}\n" "$display_path"
        ((index++))
    done <<< "$enabled_projects"

    echo ""
    echo -e "${GRAY}Config file: $config_path${NC}"
}

# Function to add current directory as a project
cdp-add() {
    local name="$1"
    local path="$2"
    local config_path="$3"

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' command not found. Please install jq.${NC}"
        return 1
    fi

    # Determine path to add
    if [[ -z "$path" ]]; then
        path="$PWD"
    fi

    # Resolve to absolute path
    path=$(realpath "$path" 2>/dev/null || echo "$path")

    # Determine project name
    if [[ -z "$name" ]]; then
        name=$(basename "$path")
    fi

    # Get config path
    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    # Initialize config if needed
    initialize_config "$config_path"

    # Check if project already exists
    local existing=$(jq -r --arg path "$path" '.[] | select(.rootPath == $path) | .name' "$config_path" 2>/dev/null)

    if [[ -n "$existing" ]]; then
        echo -e "${YELLOW}Project already exists: $existing${NC}"
        echo -e "${GRAY}Path: $path${NC}"
        return 0
    fi

    # Add new project
    local temp_file=$(mktemp)
    jq --arg name "$name" --arg path "$path" \
        '. += [{"name": $name, "rootPath": $path, "enabled": true}]' \
        "$config_path" > "$temp_file"

    mv "$temp_file" "$config_path"

    echo -e "${GREEN}Project added successfully!${NC}"
    echo -e "  ${CYAN}Name:${NC} $name"
    echo -e "  ${GRAY}Path:${NC} $path"
    echo -e "  ${GRAY}Config:${NC} $config_path"
}

# Export functions for bash/zsh
if [[ -n "$BASH_VERSION" ]]; then
    export -f cdp
    export -f cdp-ls
    export -f cdp-add
fi
