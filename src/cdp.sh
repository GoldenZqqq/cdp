#!/usr/bin/env bash
#
# cdp - Fast project directory switcher for bash/zsh (WSL version)
#
# Compatible with VS Code/Cursor Project Manager and custom JSON configs.
# Shares the same configuration files as the PowerShell version.
#
# Author: GoldenZqqq
# Version: 1.2.2
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

# Function to get stored config choice path
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

# Function to find all available config files
get_all_available_configs() {
    local configs=()
    local sources=()

    # Try to find Windows user directory
    local winuser=""

    # Method 1: Try to get from WSLENV or existing Windows env vars
    if [[ -n "$WSLENV" ]] && [[ -n "$USERNAME" ]]; then
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
    local config_count=$(echo "$available_configs" | wc -l)

    # If only one config, use it and save the choice
    if [[ $config_count -eq 1 ]]; then
        local selected_path=$(echo "$available_configs" | cut -d'|' -f1)
        save_config_choice "$selected_path"
        echo "$selected_path"
        return
    fi

    # Multiple configs found - let user choose
    echo -e "\n${CYAN}Multiple configuration files found:${NC}"
    echo -e "${GRAY}$(printf '=%.0s' {1..80})${NC}"
    echo ""

    local index=1
    local -a config_paths=()
    while IFS='|' read -r path source; do
        config_paths+=("$path")
        echo -e "  ${YELLOW}[$index]${NC} ${GREEN}$source${NC}"
        echo -e "      ${GRAY}$path${NC}"
        ((index++))
    done <<< "$available_configs"

    echo ""
    echo -e "${GRAY}Your choice will be saved. Use ${CYAN}cdp-config${GRAY} to change it later.${NC}"
    echo -e "${GRAY}Or set ${CYAN}\$CDP_CONFIG${GRAY} to override.${NC}"
    echo ""

    # Get user selection
    while true; do
        read -p "Select config file (1-$config_count): " selection

        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le $config_count ]]; then
            local selected_path="${config_paths[$((selection-1))]}"
            local selected_source=$(echo "$available_configs" | sed -n "${selection}p" | cut -d'|' -f2)

            # Save the choice
            save_config_choice "$selected_path"

            echo ""
            echo -e "${GREEN}Using: $selected_source${NC}"
            echo -e "${GRAY}Path: $selected_path${NC}"
            echo -e "${GRAY}Saved to: ${CYAN}~/.cdp/config${NC}"
            echo ""

            echo "$selected_path"
            return
        else
            echo -e "${RED}Invalid selection. Please enter a number between 1 and $config_count.${NC}"
        fi
    done
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

# Function to change configuration file
cdp-config() {
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
    while IFS='|' read -r path source; do
        config_paths+=("$path")
        config_sources+=("$source")

        local is_current=""
        if [[ "$path" == "$current_config" ]]; then
            is_current=" ${CYAN}(current)${NC}"
        fi

        echo -e "  ${YELLOW}[$index]${NC} ${GREEN}$source${NC}$is_current"
        echo -e "      ${GRAY}$path${NC}"
        ((index++))
    done <<< "$available_configs"

    echo ""

    # Get user selection
    local config_count=${#config_paths[@]}
    while true; do
        read -p "Select config file (1-$config_count, or 0 to cancel): " selection

        if [[ "$selection" == "0" ]]; then
            echo -e "\n${GRAY}Operation cancelled.${NC}"
            return 0
        fi

        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le $config_count ]]; then
            local selected_path="${config_paths[$((selection-1))]}"
            local selected_source="${config_sources[$((selection-1))]}"

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
            return 0
        else
            echo -e "${RED}Invalid selection. Please enter a number between 0 and $config_count.${NC}"
        fi
    done
}

# Export functions for bash/zsh
if [[ -n "$BASH_VERSION" ]]; then
    export -f cdp
    export -f cdp-ls
    export -f cdp-add
    export -f cdp-config
fi
