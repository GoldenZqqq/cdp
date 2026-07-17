#!/usr/bin/env bash
#
# cdp - Fast project directory switcher for bash/zsh (WSL version)
#
# Compatible with VS Code/Cursor Project Manager and custom JSON configs.
# Shares the same configuration files as the PowerShell version.
#
# Author: GoldenZqqq
# Version: 2.0.4
# License: MIT

CDP_VERSION="2.0.4"

# zsh compatibility: use bash-like array indexing and regex matching
if [[ -n "${ZSH_VERSION:-}" ]]; then
    setopt KSH_ARRAYS BASH_REMATCH 2>/dev/null
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD_CYAN='\033[1;36m'
NC='\033[0m' # No Color

cdp_brand_header() {
    echo ""
    echo -e "${CYAN}         _${NC}"
    echo -e "${CYAN}  ___ __| |_ __${NC}"
    echo -e "${CYAN} / __/ _\` | \"_ \\\\${NC}"
    echo -e "${CYAN}| (_| (_| | |_) |${NC}"
    echo -e "${CYAN} \\___\\__,_| .__/${NC}"
    echo -e "${CYAN}          |_|${NC}"
    echo -e "${GREEN}cdp v$CDP_VERSION${NC}"
    echo -e "${GRAY}fast project switching for PowerShell and WSL${NC}"
    echo ""
}

cdp_upgrade_command() {
    echo "bash <(curl -fsSL https://raw.githubusercontent.com/GoldenZqqq/cdp/main/install-wsl.sh) --auto"
}

cdp_picker_header() {
    local shown_count="$1"
    local total_count="$2"
    local config_path="$3"
    local project_text

    if [[ "$shown_count" == "$total_count" ]]; then
        project_text="$total_count projects"
    else
        project_text="$shown_count shown / $total_count projects"
    fi

    echo "cdp v$CDP_VERSION | $project_text | enter to warp | $config_path"
}

truncate_text() {
    local value="$1"
    local max_length="$2"

    if (( ${#value} <= max_length )); then
        echo "$value"
        return
    fi

    echo "${value:0:$((max_length - 3))}..."
}

sanitize_picker_field() {
    local value="$1"
    value="${value//$'\t'/ }"
    value="${value//$'\r'/ }"
    value="${value//$'\n'/ }"
    echo "$value"
}

cdp_picker_preview() {
    local name="$1"
    local raw_path="$2"
    local target_path="$3"
    local preview_file="$4"
    local path_state="path missing"
    local git_state="git repo not detected"

    if [[ -d "$target_path" ]]; then
        path_state="path exists"
    fi

    if [[ -e "$target_path/.git" ]]; then
        git_state="git repo detected"
    fi

    {
        echo "cdp project"
        echo "-----------"
        echo "name   $name"
        echo "path   $raw_path"
        echo ""
        echo "state  $path_state"
        echo "git    $git_state"
        echo ""
        echo "Enter  switch to this project"
        echo "Esc    cancel"
    } > "$preview_file"
}

cdp_picker_rows() {
    local projects="$1"
    local config_path="$2"
    local preview_dir="$3"
    local index=1
    local name

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue

        local raw_path
        local display_path
        local pinned
        local name_label
        local safe_name
        local safe_path
        raw_path=$(jq -r --arg name "$name" \
            '.[] | select(.name == $name and .enabled == true) | .rootPath' \
            "$config_path" 2>/dev/null | head -n1)
        pinned=$(jq -r --arg name "$name" \
            '.[] | select(.name == $name and .enabled == true) | (.pinned == true)' \
            "$config_path" 2>/dev/null | head -n1)
        display_path=$(convert_windows_to_wsl "$raw_path")
        safe_name=$(sanitize_picker_field "$name")
        safe_path=$(sanitize_picker_field "$display_path")
        name_label="$safe_name"
        if [[ "$pinned" == "true" ]]; then
            name_label="[pin] $safe_name"
        fi

        cdp_picker_preview "$safe_name" "$safe_path" "$display_path" "$preview_dir/$index.txt"
        printf "%s\t%s\t%s\t%b%3d%b\t%b%s%b\t%b%s%b\n" \
            "$index" "$safe_name" "$raw_path" \
            "$GRAY" "$index" "$NC" \
            "$BOLD_CYAN" "$name_label" "$NC" \
            "$GRAY" "$safe_path" "$NC"
        ((index++))
    done <<< "$projects"
}

# Function to convert Windows path to WSL path
convert_windows_to_wsl() {
    local input_path="$1"

    # Check if path looks like Windows path (C:\... or C:/...)
    if [[ "$input_path" =~ ^([A-Za-z]):[/\\](.*)$ ]]; then
        local drive
        drive="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')"
        local remainder="${BASH_REMATCH[2]}"

        # Replace backslashes with forward slashes
        remainder="${remainder//\\//}"

        echo "/mnt/$drive/$remainder"
    else
        # Already a Unix path or unknown format
        echo "$input_path"
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

    if [[ ! -f "$state_path" ]] || ! jq -e 'type == "object"' "$state_path" >/dev/null 2>&1; then
        echo '{"recentProjects":[]}' > "$state_path"
    fi
}

cdp_record_recent() {
    local name="$1"
    local root_path="$2"

    [[ -z "$name" || -z "$root_path" ]] && return 0
    command -v jq >/dev/null 2>&1 || return 0

    local state_path
    local temp_file
    local now
    state_path=$(cdp_state_path)
    initialize_state "$state_path"
    temp_file=$(mktemp)
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
    ' "$state_path" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$state_path"
    else
        rm -f "$temp_file"
    fi
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
    while IFS='|' read -r config_entry_path source; do
        config_paths+=("$config_entry_path")
        echo -e "  ${YELLOW}[$index]${NC} ${GREEN}$source${NC}"
        echo -e "      ${GRAY}$config_entry_path${NC}"
        ((index++))
    done <<< "$available_configs"

    echo ""
    echo -e "${GRAY}Your choice will be saved. Use ${CYAN}cdp-config${GRAY} to change it later.${NC}"
    echo -e "${GRAY}Or set ${CYAN}\$CDP_CONFIG${GRAY} to override.${NC}"
    echo ""

    # Get user selection
    while true; do
        printf "Select config file (1-%s): " "$config_count"
        read -r selection

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

cdp_print_check() {
    local check_status="$1"
    local name="$2"
    local message="$3"

    case "$check_status" in
        ok)
            echo -e "${GREEN}[OK]   ${NC}${name}: ${GRAY}${message}${NC}"
            ;;
        warn)
            echo -e "${YELLOW}[WARN] ${NC}${name}: ${GRAY}${message}${NC}"
            ;;
        *)
            echo -e "${RED}[FAIL] ${NC}${name}: ${GRAY}${message}${NC}"
            ;;
    esac
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

cdp_about() {
    local config_path="$1"
    local project_count="unknown"
    local enabled_count="unknown"

    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    if [[ -f "$config_path" ]] && command -v jq &> /dev/null; then
        project_count=$(jq 'length' "$config_path" 2>/dev/null || echo 0)
        enabled_count=$(jq '[.[] | select(.enabled == true)] | length' "$config_path" 2>/dev/null || echo 0)
    fi

    cdp_brand_header
    echo -e "${GRAY}Module:${NC} ${CYAN}${BASH_SOURCE[0]:-${(%):-%x}}${NC}"
    echo -e "${GRAY}Config:${NC} ${CYAN}$config_path${NC}"
    echo -e "${GRAY}Projects:${NC} ${GREEN}$enabled_count enabled / $project_count total${NC}"
    echo -e "${GRAY}Upgrade:${NC} ${CYAN}$(cdp_upgrade_command)${NC}"
}

cdp-init() {
    local root_path="$1"
    local config_path="$2"
    local max_depth="${3:-4}"

    if [[ -z "$config_path" ]]; then
        config_path="$HOME/.cdp/projects.json"
    fi

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
        cdp-scan "$root_path" "$config_path" "$max_depth"
    fi
}

resolve_workspace_launcher() {
    local opener="$1"

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

cdp_display_width() {
    local text="$1"
    if [[ -z "$text" ]]; then echo 0; return; fi
    local width=0
    local ch code
    local i=0
    local len=${#text}
    while [[ $i -lt $len ]]; do
        ch="${text:$i:1}"
        code=$(LC_ALL=C printf '%d' "'$ch" 2>/dev/null || echo 0)
        if [[ $code -ge 128 ]]; then
            width=$((width + 2))
        else
            width=$((width + 1))
        fi
        i=$((i + 1))
    done
    echo "$width"
}

cdp_pad_text() {
    local text="$1"
    local target_width="$2"
    local actual_width
    actual_width=$(cdp_display_width "$text")
    local padding=$((target_width - actual_width))
    if [[ $padding -gt 0 ]]; then
        printf '%s%*s' "$text" "$padding" ""
    else
        printf '%s' "$text"
    fi
}

cdp_limit_text() {
    local text="$1"
    local max_len="$2"
    local actual
    actual=$(cdp_display_width "$text")
    if [[ $actual -le $max_len ]]; then
        printf '%s' "$text"
        return
    fi
    local result=""
    local current=0
    local i=0
    local len=${#text}
    while [[ $i -lt $len ]]; do
        local ch="${text:$i:1}"
        local code
        code=$(LC_ALL=C printf '%d' "'$ch" 2>/dev/null || echo 0)
        local cw=1
        [[ $code -ge 128 ]] && cw=2
        if [[ $((current + cw)) -gt $((max_len - 3)) ]]; then
            break
        fi
        result+="$ch"
        current=$((current + cw))
        i=$((i + 1))
    done
    printf '%s...' "$result"
}

cdp-status() {
    local config_path=""
    local dirty_only=false
    local tag_filter=""
    local do_fix=false
    local do_push=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dirty|-d) dirty_only=true ;;
            --fix)      do_fix=true ;;
            --push)     do_push=true ;;
            --config)
                [[ -z "${2:-}" ]] && { echo -e "${RED}Error: missing value after --config.${NC}"; return 1; }
                [[ -n "$config_path" ]] && { echo -e "${RED}Error: config path specified more than once.${NC}"; return 1; }
                config_path="$2"
                shift
                ;;
            @*)
                [[ -n "$tag_filter" ]] && { echo -e "${RED}Error: only one status tag filter is allowed.${NC}"; return 1; }
                tag_filter="$1"
                ;;
            -*)
                echo -e "${RED}Error: unknown status option: $1${NC}"
                return 1
                ;;
            *)
                [[ -n "$config_path" ]] && { echo -e "${RED}Error: config path specified more than once.${NC}"; return 1; }
                config_path="$1"
                ;;
        esac
        shift
    done

    if $do_fix && $do_push; then
        echo -e "${RED}Error: --fix and --push cannot be used together.${NC}"
        return 1
    fi
    if $dirty_only && { $do_fix || $do_push; }; then
        echo -e "${RED}Error: --dirty cannot be combined with status actions.${NC}"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' command not found.${NC}"
        return 1
    fi

    if ! command -v git &> /dev/null; then
        echo -e "${RED}Error: 'git' command not found.${NC}"
        return 1
    fi

    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    if [[ ! -f "$config_path" ]]; then
        echo -e "${RED}Error: Configuration file not found at: $config_path${NC}"
        return 1
    fi

    local jq_filter='.[] | select(.enabled == true)'
    if [[ -n "$tag_filter" ]]; then
        local tag_query="${tag_filter#@}"
        jq_filter=".[] | select(.enabled == true) | select(((.tags // []) | map(ascii_downcase) | index(\"$(echo "$tag_query" | tr '[:upper:]' '[:lower:]')\")) != null)"
    fi

    local projects
    projects=$(jq -r "$jq_filter | [.name, .rootPath] | @tsv" "$config_path" 2>/dev/null)

    if [[ -z "$projects" ]]; then
        echo -e "${YELLOW}No projects to check.${NC}"
        return
    fi

    local total=0
    local attention_count=0
    local missing_count=0
    local output_lines=()
    local max_name_len=14
    local max_branch_len=12

    # First pass: collect data
    local -a names=() raw_paths=() paths=() branches=() statuses=() status_colors=() syncs=() sync_colors=() last_commits=() needs_attention=()
    local proj_total
    proj_total=$(line_count "$projects")
    local proj_scanned=0

    while IFS=$'\t' read -r pname ppath; do
        pname="${pname%$'\r'}"
        ppath="${ppath%$'\r'}"
        [[ -z "$pname" ]] && continue
        local raw_ppath="$ppath"
        ppath=$(convert_windows_to_wsl "$raw_ppath")
        proj_scanned=$((proj_scanned + 1))
        printf "\r  Scanning %d/%d... " "$proj_scanned" "$proj_total" >&2
        total=$((total + 1))

        local name_len
        name_len=$(cdp_display_width "$pname")
        [[ $name_len -gt $max_name_len ]] && max_name_len=$name_len

        names+=("$pname")
        raw_paths+=("$raw_ppath")
        paths+=("$ppath")

        if [[ ! -d "$ppath" ]]; then
            branches+=("-")
            statuses+=("path missing")
            status_colors+=("$RED")
            syncs+=("")
            sync_colors+=("$GRAY")
            last_commits+=("")
            needs_attention+=(true)
            missing_count=$((missing_count + 1))
            continue
        fi

        local inside_work_tree
        inside_work_tree=$(git -C "$ppath" rev-parse --is-inside-work-tree 2>/dev/null || true)
        if [[ "$inside_work_tree" != "true" ]]; then
            branches+=("-")
            statuses+=("not a git repo")
            status_colors+=("$GRAY")
            syncs+=("")
            sync_colors+=("$GRAY")
            last_commits+=("")
            needs_attention+=(false)
            continue
        fi

        local branch
        branch=$(git -C "$ppath" branch --show-current 2>/dev/null)
        [[ -z "$branch" ]] && branch=$(git -C "$ppath" rev-parse --short HEAD 2>/dev/null)
        branches+=("$branch")
        local branch_len
        branch_len=$(cdp_display_width "$branch")
        [[ $branch_len -gt $max_branch_len ]] && max_branch_len=$branch_len

        local dirty_count=0
        local untracked_count=0
        local porcelain
        porcelain=$(git -C "$ppath" status --porcelain 2>/dev/null)
        if [[ -n "$porcelain" ]]; then
            while IFS= read -r line; do
                if [[ "${line:0:2}" == "??" ]]; then
                    untracked_count=$((untracked_count + 1))
                else
                    dirty_count=$((dirty_count + 1))
                fi
            done <<< "$porcelain"
        fi

        local ahead=0 behind=0
        ahead=$(git -C "$ppath" rev-list --count "@{u}..HEAD" 2>/dev/null || echo 0)
        behind=$(git -C "$ppath" rev-list --count "HEAD..@{u}" 2>/dev/null || echo 0)

        local last_commit
        last_commit=$(git -C "$ppath" log -1 --format="%cr" 2>/dev/null)
        last_commits+=("$last_commit")

        if [[ $dirty_count -gt 0 && $untracked_count -gt 0 ]]; then
            statuses+=("x $dirty_count dirty + $untracked_count untracked")
            status_colors+=("$RED")
            needs_attention+=(true)
            attention_count=$((attention_count + 1))
        elif [[ $dirty_count -gt 0 ]]; then
            statuses+=("x $dirty_count dirty")
            status_colors+=("$RED")
            needs_attention+=(true)
            attention_count=$((attention_count + 1))
        elif [[ $untracked_count -gt 0 ]]; then
            statuses+=("! $untracked_count untracked")
            status_colors+=("$YELLOW")
            needs_attention+=(true)
            attention_count=$((attention_count + 1))
        else
            statuses+=("+ clean")
            status_colors+=("$GREEN")
            needs_attention+=(false)
        fi

        local sync_text=""
        local s_color="$GRAY"
        [[ $ahead -gt 0 ]] && sync_text="^${ahead}"
        [[ $behind -gt 0 ]] && { [[ -n "$sync_text" ]] && sync_text="$sync_text "; sync_text="${sync_text}v${behind}"; }
        [[ $behind -gt 0 ]] && s_color="$YELLOW"
        [[ $behind -eq 0 && $ahead -gt 0 ]] && s_color="$CYAN"
        if [[ $behind -gt 0 ]]; then
            if [[ "${needs_attention[${#needs_attention[@]}-1]}" != "true" ]]; then
                attention_count=$((attention_count + 1))
            fi
            needs_attention[${#needs_attention[@]}-1]=true
        fi
        syncs+=("$sync_text")
        sync_colors+=("$s_color")
    done <<< "$projects"
    printf "\r                          \r" >&2

    # --fix: remove path-missing projects (skip table render)
    if $do_fix; then
        if [[ $missing_count -eq 0 ]]; then
            echo -e "${GREEN}No path-missing projects to remove.${NC}"
            return
        fi
        echo -e "\n${YELLOW}Removing $missing_count path-missing projects:${NC}"
        for ((i=0; i<total; i++)); do
            if [[ "${statuses[$i]}" == "path missing" ]]; then
                echo -e "  ${GRAY}x ${names[$i]}  ${raw_paths[$i]}${NC}"
            fi
        done
        local missing_raw_paths=()
        for ((i=0; i<total; i++)); do
            [[ "${statuses[$i]}" == "path missing" ]] && missing_raw_paths+=("${raw_paths[$i]}")
        done
        local missing_json
        missing_json=$(printf '%s\n' "${missing_raw_paths[@]}" | jq -R . | jq -s .)
        local new_json
        new_json=$(jq --argjson missing "$missing_json" '[.[] | . as $project | select(($project.enabled != true) or (($missing | index($project.rootPath)) == null))]' "$config_path")
        local kept_count
        kept_count=$(printf '%s\n' "$new_json" | jq 'length')
        printf '%s\n' "$new_json" > "$config_path"
        echo -e "\n${GREEN}Removed $missing_count projects. $kept_count projects remain.${NC}"
        return
    fi

    # --push: push all repos ahead of remote (skip table render)
    if $do_push; then
        local push_count=0
        for ((i=0; i<total; i++)); do
            if [[ -n "${syncs[$i]}" && "${syncs[$i]}" == *"^"* && -d "${paths[$i]}" ]]; then
                [[ $push_count -eq 0 ]] && echo -e "\n${YELLOW}Pushing repos ahead of remote:${NC}"
                printf "  %s... " "${names[$i]}"
                if git -C "${paths[$i]}" push 2>/dev/null; then
                    echo -e "${GREEN}done${NC}"
                else
                    echo -e "${RED}failed${NC}"
                fi
                push_count=$((push_count + 1))
            fi
        done
        [[ $push_count -eq 0 ]] && echo -e "${GREEN}No repos ahead of remote.${NC}"
        return
    fi

    [[ $max_name_len -gt 24 ]] && max_name_len=24
    [[ $max_branch_len -gt 20 ]] && max_branch_len=20

    local filter_label=""
    $dirty_only && filter_label=" (dirty only)"
    [[ -n "$tag_filter" ]] && filter_label=" ($tag_filter)"

    # Print header
    local shown_count=0
    for ((i=0; i<total; i++)); do
        if ! $dirty_only || [[ "${needs_attention[$i]}" == "true" ]]; then
            shown_count=$((shown_count + 1))
        fi
    done
    echo ""
    echo -e "${CYAN}cdp project status ${GRAY}(${shown_count} projects${filter_label})${NC}"
    printf '%.0s-' {1..110}; echo ""
    printf "  %-4s %-${max_name_len}s %-${max_branch_len}s %-24s %-10s %s\n" "#" "Project" "Branch" "Status" "Sync" "Last Commit"
    printf '%.0s-' {1..110}; echo ""

    local idx=1
    for ((i=0; i<total; i++)); do
        if $dirty_only && [[ "${needs_attention[$i]}" != "true" ]]; then
            continue
        fi

        local display_name
        display_name=$(cdp_limit_text "${names[$i]}" "$max_name_len")

        local display_branch
        display_branch=$(cdp_limit_text "${branches[$i]}" "$max_branch_len")

        local num
        num=$(printf "%02d" $idx)

        printf "  ${GRAY}%-4s${NC} ${GREEN}%s${NC} ${BOLD_CYAN}%s${NC} ${status_colors[$i]}%-24s${NC} ${sync_colors[$i]}%-10s${NC} ${GRAY}%s${NC}\n" \
            "$num" "$(cdp_pad_text "$display_name" "$max_name_len")" "$(cdp_pad_text "$display_branch" "$max_branch_len")" "${statuses[$i]}" "${syncs[$i]}" "${last_commits[$i]}"

        idx=$((idx + 1))
    done

    printf '%.0s-' {1..110}; echo ""

    local summary_parts=()
    [[ $attention_count -gt 0 ]] && summary_parts+=("$attention_count repos need attention")
    [[ $missing_count -gt 0 ]] && summary_parts+=("$missing_count path missing")

    if [[ ${#summary_parts[@]} -gt 0 ]]; then
        local joined
        joined=$(printf " | %s" "${summary_parts[@]}")
        joined="${joined:3}"
        echo -e "${YELLOW}${joined}${NC}"
    else
        echo -e "${GREEN}All projects clean.${NC}"
    fi

    if [[ ${#summary_parts[@]} -gt 0 ]]; then
        echo ""
        [[ $missing_count -gt 0 ]] && echo -e "${GRAY}  Tip: cdp status --fix   Remove $missing_count path-missing projects${NC}"
        local ahead_count=0
        for ((i=0; i<total; i++)); do
            [[ -n "${syncs[$i]}" && "${syncs[$i]}" == *"^"* ]] && ahead_count=$((ahead_count + 1))
        done
        [[ $ahead_count -gt 0 ]] && echo -e "${GRAY}  Tip: cdp status --push  Push $ahead_count repos ahead of remote${NC}"
    fi
    return 0
}

cdp-workspace() {
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

            if [[ -z "$ws_name" || ${#ws_projects[@]} -eq 0 ]]; then
                echo -e "${YELLOW}Usage: cdp workspace --add <name> <project1> <project2> ...${NC}"
                return
            fi

            if [[ -f "$ws_path" ]] && jq -e --arg n "$ws_name" '.[] | select(.name == $n)' "$ws_path" &>/dev/null; then
                echo -e "${YELLOW}Workspace '$ws_name' already exists.${NC}"
                return
            fi

            local projects_json
            projects_json=$(printf '%s\n' "${ws_projects[@]}" | jq -R . | jq -s .)

            local new_ws
            if [[ -n "$open_override" ]]; then
                new_ws=$(jq -n --arg name "$ws_name" --argjson projects "$projects_json" --arg open "$open_override" '{name: $name, projects: $projects, open: $open}')
            else
                new_ws=$(jq -n --arg name "$ws_name" --argjson projects "$projects_json" '{name: $name, projects: $projects}')
            fi

            if [[ -f "$ws_path" ]]; then
                local existing
                existing=$(cat "$ws_path")
                echo "$existing" | jq --argjson ws "$new_ws" '. + [$ws]' > "$ws_path"
            else
                mkdir -p "$config_dir"
                echo "[$new_ws]" | jq '.' > "$ws_path"
            fi
            echo -e "${GREEN}Workspace '$ws_name' created with ${#ws_projects[@]} projects.${NC}"
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
            local ws_projects_list
            ws_projects_list=$(echo "$ws_data" | jq -r '.projects[]')

            local has_tmux=false
            command -v tmux &>/dev/null && has_tmux=true

            if $has_tmux; then
                local session_name="cdp-${ws_name}"
                local first=true
                while IFS= read -r proj_name <&3; do
                    proj_name="${proj_name%$'\r'}"
                    [[ -z "$proj_name" ]] && continue
                    local proj_path
                    proj_path=$(jq -r --arg n "$proj_name" '.[] | select(.enabled == true) | select(.name == $n) | .rootPath' "$config_path" 2>/dev/null | head -1)
                    proj_path="${proj_path%$'\r'}"
                    proj_path=$(convert_windows_to_wsl "$proj_path")
                    [[ -z "$proj_path" || ! -d "$proj_path" ]] && { echo -e "${YELLOW}  Skipping '$proj_name' (not found)${NC}"; continue; }

                    if $first; then
                        tmux new-session -d -s "$session_name" -c "$proj_path" -n "$proj_name"
                        [[ -n "$ws_open" ]] && tmux send-keys -t "$session_name" "$ws_open" Enter
                        first=false
                    else
                        tmux new-window -t "$session_name" -c "$proj_path" -n "$proj_name"
                        [[ -n "$ws_open" ]] && tmux send-keys -t "$session_name" "$ws_open" Enter
                    fi
                    echo -e "${GREEN}  Opened window: $proj_name${NC}"
                done 3<<< "$ws_projects_list"

                if ! $first; then
                    tmux attach-session -t "$session_name" 2>/dev/null || tmux switch-client -t "$session_name" 2>/dev/null
                fi
            else
                while IFS= read -r proj_name <&3; do
                    proj_name="${proj_name%$'\r'}"
                    [[ -z "$proj_name" ]] && continue
                    local proj_path
                    proj_path=$(jq -r --arg n "$proj_name" '.[] | select(.enabled == true) | select(.name == $n) | .rootPath' "$config_path" 2>/dev/null | head -1)
                    proj_path="${proj_path%$'\r'}"
                    proj_path=$(convert_windows_to_wsl "$proj_path")
                    echo -e "${CYAN}  $proj_name${NC} -> ${GRAY}$proj_path${NC}"
                done 3<<< "$ws_projects_list"
                echo ""
                echo -e "${YELLOW}Install tmux for multi-window workspace launching.${NC}"
            fi
            ;;
    esac
}

# Main cdp function
cdp() {
    case "$1" in
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
            if [[ "${1:-}" == "--fix" || "${1:-}" == "-f" ]]; then
                shift
                cdp-clean "$@"
            else
                cdp-doctor "$@"
            fi
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
            *)
                positional_args+=("$1")
                shift
                ;;
        esac
    done

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

    # Get the rootPath for selected project
    local raw_project_path=$(jq -r --arg name "$selected" \
        '.[] | select(.name == $name and .enabled == true) | .rootPath' \
        "$config_path" 2>/dev/null | head -n1)

    if [[ -n "$raw_project_path" ]]; then
        # Convert Windows path to WSL path if needed
        local project_path
        project_path=$(convert_windows_to_wsl "$raw_project_path")

        # Check if path exists
        if [[ -d "$project_path" ]]; then
            cd "$project_path" || return 1
            cdp_record_recent "$selected" "$raw_project_path"
            echo -e "${GREEN}Switched to project: $selected${NC}"
            echo -e "${GRAY}Path: $project_path${NC}"

            # Update terminal title (works in most terminals)
            echo -ne "\033]0;$selected\007"

            # Execute onEnter hook if defined
            local on_enter
            on_enter=$(jq -r --arg name "$selected" '.[] | select(.name == $name) | .onEnter // empty' "$config_path" 2>/dev/null)
            on_enter="${on_enter%$'\r'}"
            if [[ -n "$on_enter" && "$on_enter" != "null" ]]; then
                if echo "$on_enter" | jq -e 'type == "object"' &>/dev/null 2>&1; then
                    local bash_cmd
                    bash_cmd=$(echo "$on_enter" | jq -r '.bash // empty' 2>/dev/null)
                    bash_cmd="${bash_cmd%$'\r'}"
                    [[ -n "$bash_cmd" ]] && eval "$bash_cmd" 2>/dev/null || echo -e "${YELLOW}  onEnter warning: $bash_cmd${NC}"
                    local env_keys
                    env_keys=$(echo "$on_enter" | jq -r '.env // {} | to_entries[] | "\(.key)=\(.value)"' 2>/dev/null)
                    while IFS= read -r kv; do
                        kv="${kv%$'\r'}"
                        [[ -n "$kv" ]] && export "$kv"
                    done <<< "$env_keys"
                else
                    eval "$on_enter" 2>/dev/null || echo -e "${YELLOW}  onEnter warning: command failed${NC}"
                fi
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
        display_path=$(convert_windows_to_wsl "$project_path")
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
cdp-add() {
    local name="$1"
    local project_path="$2"
    local config_path="$3"

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

    # Initialize config if needed
    initialize_config "$config_path"

    # Check if project already exists
    local existing=$(jq -r --arg path "$project_path" '.[] | select(.rootPath == $path) | .name' "$config_path" 2>/dev/null)

    if [[ -n "$existing" ]]; then
        echo -e "${YELLOW}Project already exists: $existing${NC}"
        echo -e "${GRAY}Path: $project_path${NC}"
        return 0
    fi

    # Add new project
    local temp_file=$(mktemp)
    jq --arg name "$name" --arg path "$project_path" \
        '. += [{"name": $name, "rootPath": $path, "enabled": true, "pinned": false, "aliases": [], "tags": []}]' \
        "$config_path" > "$temp_file"

    mv "$temp_file" "$config_path"

    echo -e "${GREEN}Project added successfully!${NC}"
    echo -e "  ${CYAN}Name:${NC} $name"
    echo -e "  ${GRAY}Path:${NC} $project_path"
    echo -e "  ${GRAY}Config:${NC} $config_path"
}

set_project_pin() {
    local name="$1"
    local pinned="$2"
    local config_path="$3"

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' command not found. Please install jq.${NC}"
        return 1
    fi

    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    initialize_config "$config_path"

    local matches
    if [[ -z "$name" ]]; then
        matches=$(jq -r --arg path "$PWD" '.[] | select(.rootPath == $path) | .name' "$config_path" 2>/dev/null)
    else
        matches=$(find_project_matches "$config_path" "$name")
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
    local temp_file
    local state_text="Pinned"
    target="$matches"
    temp_file=$(mktemp)
    if [[ "$pinned" != "true" ]]; then
        state_text="Unpinned"
    fi

    jq --arg name "$target" --argjson pinned "$pinned" '
        map(if .name == $name then . + {"pinned": $pinned} else . end)
    ' "$config_path" > "$temp_file"
    mv "$temp_file" "$config_path"

    echo -e "${GREEN}$state_text project: $target${NC}"
}

cdp-pin() {
    set_project_pin "$1" true "$2"
}

cdp-unpin() {
    set_project_pin "$1" false "$2"
}

cdp-clean() {
    local config_path="$1"

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' command not found. Please install jq.${NC}"
        return 1
    fi

    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    initialize_config "$config_path"

    local temp_file
    temp_file=$(mktemp)
    jq '
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
    ' "$config_path" > "$temp_file"
    mv "$temp_file" "$config_path"

    local missing_count=0
    while IFS=$'\t' read -r name raw_project_path; do
        [[ -z "$name" && -z "$raw_project_path" ]] && continue
        local resolved_path
        resolved_path=$(convert_windows_to_wsl "$raw_project_path")
        if [[ ! -d "$resolved_path" ]]; then
            temp_file=$(mktemp)
            jq --arg path "$raw_project_path" 'map(if .rootPath == $path then .enabled = false else . end)' \
                "$config_path" > "$temp_file"
            mv "$temp_file" "$config_path"
            ((missing_count += 1))
        fi
    done < <(jq -r '.[] | select(.enabled == true) | [.name, .rootPath] | @tsv' "$config_path")

    echo -e "${GREEN}cdp config repaired:${NC} $config_path"
    echo -e "${GRAY}  DisabledMissingPaths: $missing_count${NC}"
}

update_project_list_value() {
    local name="$1"
    local value="$2"
    local property="$3"
    local remove="$4"
    local config_path="$5"

    if [[ -z "$name" || -z "$value" ]]; then
        echo -e "${YELLOW}Project name and metadata value are required.${NC}"
        return 1
    fi

    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    initialize_config "$config_path"

    local matches
    local match_count
    matches=$(find_project_matches "$config_path" "$name")
    match_count=$(line_count "$matches")
    if [[ "$match_count" -ne 1 ]]; then
        echo -e "${YELLOW}Expected one project match, found $match_count.${NC}"
        return 1
    fi

    local target
    local temp_file
    target="$matches"
    temp_file=$(mktemp)
    jq --arg name "$target" --arg value "$value" --arg property "$property" --argjson remove "$remove" '
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
    ' "$config_path" > "$temp_file"
    mv "$temp_file" "$config_path"

    echo -e "${GREEN}Updated $property for project: $target${NC}"
}

cdp-alias() {
    update_project_list_value "$1" "$2" "aliases" false "$3"
}

cdp-unalias() {
    update_project_list_value "$1" "$2" "aliases" true "$3"
}

cdp-tag() {
    update_project_list_value "$1" "$2" "tags" false "$3"
}

cdp-untag() {
    update_project_list_value "$1" "$2" "tags" true "$3"
}

cdp-scan() {
    local root_path="$1"
    local config_path="$2"
    local max_depth="${3:-4}"

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

    initialize_config "$config_path"

    local repos
    repos=$(find_git_repos "$root_path" "$max_depth" | sort -u)

    local found_count=0
    local added_count=0
    local skipped_count=0
    local repo

    if [[ -n "$repos" ]]; then
        while IFS= read -r repo <&3; do
            [[ -z "$repo" ]] && continue
            ((found_count += 1))

            if jq -e --arg path "$repo" '.[] | select(.rootPath == $path)' "$config_path" >/dev/null 2>&1; then
                ((skipped_count += 1))
                continue
            fi

            local name
            local temp_file
            name=$(unique_project_name "$repo" "$config_path")
            temp_file=$(mktemp)
            jq --arg name "$name" --arg path "$repo" \
                '. += [{"name": $name, "rootPath": $path, "enabled": true, "pinned": false, "aliases": [], "tags": []}]' \
                "$config_path" > "$temp_file"
            mv "$temp_file" "$config_path"
            ((added_count += 1))
        done 3<<< "$repos"
    fi

    echo -e "${CYAN}Git repositories found:${NC} $found_count"
    echo -e "${GREEN}Projects added:${NC} $added_count"
    echo -e "${YELLOW}Projects skipped:${NC} $skipped_count"
    echo -e "${GRAY}Config:${NC} $config_path"
}

# Function to diagnose cdp setup
cdp-doctor() {
    local config_path="$1"
    local config_source="argument"
    local error_count=0
    local warning_count=0

    cdp_brand_header
    echo -e "${CYAN}cdp doctor${NC}"
    echo -e "${GRAY}$(printf '=%.0s' {1..80})${NC}"

    if command -v fzf &> /dev/null; then
        cdp_print_check ok "fzf" "found at $(command -v fzf)"
    else
        cdp_print_check fail "fzf" "not found in PATH"
        ((error_count++))
    fi

    if command -v jq &> /dev/null; then
        cdp_print_check ok "jq" "found at $(command -v jq)"
    else
        cdp_print_check fail "jq" "not found in PATH"
        ((error_count++))
    fi

    if [[ -z "$config_path" ]]; then
        if [[ -n "$CDP_CONFIG" ]]; then
            config_path="$CDP_CONFIG"
            config_source="CDP_CONFIG"
        else
            local stored_choice
            stored_choice=$(get_stored_config_choice)
            if [[ -n "$stored_choice" && -f "$stored_choice" ]]; then
                config_path="$stored_choice"
                config_source="saved choice"
            else
                local available_configs
                available_configs=$(get_all_available_configs)

                if [[ -n "$available_configs" ]]; then
                    local config_count
                    config_count=$(line_count "$available_configs")
                    config_path=$(echo "$available_configs" | head -n1 | cut -d'|' -f1)
                    config_source=$(echo "$available_configs" | head -n1 | cut -d'|' -f2)

                    if [[ "$config_count" -gt 1 ]]; then
                        cdp_print_check warn "config selection" "multiple configs found; run cdp-config to choose one"
                        ((warning_count++))
                    fi
                else
                    config_path="$HOME/.cdp/projects.json"
                    config_source="default custom config"
                fi
            fi
        fi
    fi

    if [[ -f "$config_path" ]]; then
        cdp_print_check ok "config file" "$config_source -> $config_path"
    else
        cdp_print_check fail "config file" "not found at $config_path"
        ((error_count++))
        echo ""
        echo -e "${YELLOW}Summary: $error_count error(s), $warning_count warning(s).${NC}"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        echo ""
        echo -e "${YELLOW}Summary: $error_count error(s), $warning_count warning(s).${NC}"
        return 1
    fi

    if jq -e 'type == "array"' "$config_path" >/dev/null 2>&1; then
        cdp_print_check ok "JSON" "parsed successfully"
    else
        cdp_print_check fail "JSON" "expected a top-level project array"
        ((error_count++))
        echo ""
        echo -e "${YELLOW}Summary: $error_count error(s), $warning_count warning(s).${NC}"
        return 1
    fi

    local project_count
    local enabled_count
    local invalid_count
    local duplicate_count
    local missing_path_count=0

    project_count=$(jq 'length' "$config_path")
    enabled_count=$(jq '[.[] | select(.enabled == true)] | length' "$config_path")
    invalid_count=$(jq '[.[] | select((.name | type != "string") or (.rootPath | type != "string") or (.enabled | type != "boolean"))] | length' "$config_path")
    duplicate_count=$(jq '[group_by(.name)[] | select(length > 1)] | length' "$config_path")

    while IFS='|' read -r name raw_project_path; do
        [[ -z "$name" && -z "$raw_project_path" ]] && continue
        local resolved_path
        resolved_path=$(convert_windows_to_wsl "$raw_project_path")
        if [[ ! -d "$resolved_path" ]]; then
            ((missing_path_count++))
        fi
    done < <(jq -r '.[] | select(.enabled == true) | "\(.name)|\(.rootPath)"' "$config_path")

    if [[ "$invalid_count" -eq 0 ]]; then
        cdp_print_check ok "project schema" "0 invalid project entries"
    else
        cdp_print_check fail "project schema" "$invalid_count invalid project entries"
        ((error_count++))
    fi

    if [[ "$enabled_count" -gt 0 ]]; then
        cdp_print_check ok "enabled projects" "$enabled_count enabled of $project_count total"
    else
        cdp_print_check warn "enabled projects" "0 enabled of $project_count total"
        ((warning_count++))
    fi

    if [[ "$duplicate_count" -eq 0 ]]; then
        cdp_print_check ok "duplicate names" "0 duplicate project names"
    else
        cdp_print_check warn "duplicate names" "$duplicate_count duplicate project names"
        ((warning_count++))
    fi

    if [[ "$missing_path_count" -eq 0 ]]; then
        cdp_print_check ok "project paths" "0 enabled project paths missing"
    else
        cdp_print_check warn "project paths" "$missing_path_count enabled project paths missing"
        ((warning_count++))
    fi

    echo ""
    if [[ "$error_count" -eq 0 && "$warning_count" -eq 0 ]]; then
        echo -e "${GREEN}All checks passed.${NC}"
    else
        echo -e "${YELLOW}Summary: $error_count error(s), $warning_count warning(s).${NC}"
    fi

    [[ "$error_count" -eq 0 ]]
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
        printf "Select config file (1-%s, or 0 to cancel): " "$config_count"
        read -r selection

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
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f cdp
    export -f cdp_about
    export -f cdp-ls
    export -f cdp-add
    export -f cdp-config
    export -f cdp-doctor
    export -f cdp-recent
    export -f cdp-pin
    export -f cdp-unpin
    export -f cdp-clean
    export -f cdp-init
    export -f cdp-alias
    export -f cdp-unalias
    export -f cdp-tag
    export -f cdp-untag
    export -f cdp-scan
fi

_cdp_completions() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local subcommands="status doctor about recent pin unpin alias unalias tag untag clean init scan workspace"
    local launchers="code cursor codex claude gemini"

    if [[ "$prev" == "--open" || "$prev" == "-o" ]]; then
        COMPREPLY=($(compgen -W "$launchers" -- "$cur"))
        return
    fi

    if [[ $COMP_CWORD -eq 1 ]]; then
        local projects=""
        local config_path
        config_path=$(get_default_config 2>/dev/null)
        if [[ -n "$config_path" && -f "$config_path" ]] && command -v jq &>/dev/null; then
            projects=$(jq -r '.[] | select(.enabled == true) | .name' "$config_path" 2>/dev/null | tr '\r' ' ')
        fi
        COMPREPLY=($(compgen -W "$subcommands $projects" -- "$cur"))
        return
    fi

    if [[ "${COMP_WORDS[1]}" =~ ^(pin|unpin|alias|unalias|tag|untag)$ && $COMP_CWORD -eq 2 ]]; then
        local projects=""
        local config_path
        config_path=$(get_default_config 2>/dev/null)
        if [[ -n "$config_path" && -f "$config_path" ]] && command -v jq &>/dev/null; then
            projects=$(jq -r '.[] | select(.enabled == true) | .name' "$config_path" 2>/dev/null | tr '\r' ' ')
        fi
        COMPREPLY=($(compgen -W "$projects" -- "$cur"))
        return
    fi
}

if [[ -n "${BASH_VERSION:-}" ]]; then
    complete -F _cdp_completions cdp
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    autoload -Uz compinit 2>/dev/null
    _cdp_zsh_complete_words() {
        setopt localoptions noksharrays
        local completion_current="$1"
        shift
        local -a completion_words=("$@")
        local subcommands=(status doctor about recent pin unpin alias unalias tag untag clean init scan workspace)
        local launchers=(code cursor codex claude gemini)
        local cur="${completion_words[$completion_current]}"
        local prev="${completion_words[$((completion_current-1))]}"

        if [[ "$prev" == "--open" || "$prev" == "-o" ]]; then
            compadd -a launchers
            return
        fi

        if [[ $completion_current -eq 2 ]]; then
            local projects=()
            local config_path
            config_path=$(get_default_config 2>/dev/null)
            if [[ -n "$config_path" && -f "$config_path" ]] && command -v jq &>/dev/null; then
                projects=(${(f)"$(jq -r '.[] | select(.enabled == true) | .name' "$config_path" 2>/dev/null)"})
            fi
            compadd -a subcommands
            compadd -a projects
            return
        fi

        if [[ "${completion_words[2]}" =~ ^(pin|unpin|alias|unalias|tag|untag)$ && $completion_current -eq 3 ]]; then
            local projects=()
            local config_path
            config_path=$(get_default_config 2>/dev/null)
            if [[ -n "$config_path" && -f "$config_path" ]] && command -v jq &>/dev/null; then
                projects=(${(f)"$(jq -r '.[] | select(.enabled == true) | .name' "$config_path" 2>/dev/null)"})
            fi
            compadd -a projects
            return
        fi
    }
    _cdp_zsh_completions() {
        setopt localoptions noksharrays
        _cdp_zsh_complete_words "$CURRENT" "${words[@]}"
    }
    compdef _cdp_zsh_completions cdp 2>/dev/null || true
fi
