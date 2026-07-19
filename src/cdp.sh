#!/usr/bin/env bash
# shellcheck shell=bash
# cdp shell domain: Runtime.sh
# Generated from the canonical cdp.sh source; do not source peer fragments.
#
# cdp - Fast project directory switcher for bash/zsh (WSL version)
#
# Compatible with VS Code/Cursor Project Manager and custom JSON configs.
# Shares the same configuration files as the PowerShell version.
#
# Author: GoldenZqqq
# Version: 2.2.0
# License: MIT

CDP_VERSION="2.2.0"

# zsh compatibility: use bash-like array indexing and regex matching
if [[ -n "${ZSH_VERSION:-}" ]]; then
    setopt KSH_ARRAYS BASH_REMATCH TYPESET_SILENT 2>/dev/null
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD_CYAN='\033[1;36m'
NC='\033[0m' # No Color

CDP_SAFETY_DRY_RUN=false
CDP_SAFETY_YES=false
CDP_SAFETY_ARGS=()

# cdp shell domain: Core.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

cdp_parse_safety_options() {
    CDP_SAFETY_DRY_RUN=false
    CDP_SAFETY_YES=false
    CDP_SAFETY_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) CDP_SAFETY_DRY_RUN=true ;;
            --yes) CDP_SAFETY_YES=true ;;
            *) CDP_SAFETY_ARGS+=("$1") ;;
        esac
        shift
    done
    if $CDP_SAFETY_DRY_RUN && $CDP_SAFETY_YES; then
        echo -e "${RED}Error: --dry-run and --yes cannot be used together.${NC}" >&2
        return 1
    fi
}

cdp_require_high_risk_approval() {
    local action="$1"
    if $CDP_SAFETY_DRY_RUN; then
        echo -e "${GRAY}Dry run: $action was not executed.${NC}"
        return 2
    fi
    if ! $CDP_SAFETY_YES; then
        echo -e "${RED}Action requires explicit confirmation. Re-run with --yes or preview with --dry-run.${NC}" >&2
        return 1
    fi
    return 0
}

cdp_action_result() {
    local action="$1"
    local target="$2"
    local result_status="$3"
    local changed="$4"
    local error="${5:-}"
    if [[ -n "$error" ]]; then
        printf 'action=%s target=%s status=%s changed=%s error=%s\n' "$action" "$target" "$result_status" "$changed" "$error"
    else
        printf 'action=%s target=%s status=%s changed=%s\n' "$action" "$target" "$result_status" "$changed"
    fi
}


cdp_sha256_file() {
    local input_file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$input_file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$input_file" | awk '{print $1}'
    else
        openssl dgst -sha256 "$input_file" | awk '{print $NF}'
    fi
}

cdp_json_fingerprint() {
    local target_path="$1"
    if [[ ! -f "$target_path" ]]; then
        printf '%s\n' missing
        return 0
    fi
    cdp_sha256_file "$target_path"
}

cdp_json_temp_file() {
    local target_path="$1"
    local target_dir
    local target_name
    target_dir=$(dirname "$target_path")
    target_name=$(basename "$target_path")
    mkdir -p "$target_dir"
    mktemp "$target_dir/.$target_name.cdp-tmp.XXXXXX"
}

cdp_prune_json_backups() {
    local target_path="$1"
    local keep="${2:-3}"
    local target_dir
    local target_name
    local backup_path
    local backups=()
    target_dir=$(dirname "$target_path")
    target_name=$(basename "$target_path")
    while IFS= read -r backup_path; do
        [[ -n "$backup_path" ]] && backups+=("$backup_path")
    done < <(find "$target_dir" -maxdepth 1 -type f -name "$target_name.cdp-backup.*" -print 2>/dev/null)
    [[ ${#backups[@]} -le $keep ]] && return 0
    LC_ALL=C ls -1t "${backups[@]}" 2>/dev/null |
        awk -v keep="$keep" 'NR > keep' |
        while IFS= read -r backup_path; do
            [[ -n "$backup_path" ]] && rm -f -- "$backup_path"
        done
}

cdp_flush_file() {
    local input_file="$1"
    sync -f "$input_file" 2>/dev/null || sync 2>/dev/null
}

cdp_stage_json_candidate() {
    local target_path="$1"
    local candidate_path="$2"
    local staged_path
    staged_path=$(cdp_json_temp_file "$target_path") || return 1
    if ! cat "$candidate_path" > "$staged_path"; then
        rm -f -- "$staged_path"
        return 1
    fi
    if ! jq -e . "$staged_path" >/dev/null 2>&1; then
        rm -f -- "$staged_path"
        echo "Error: refusing to persist invalid JSON: $target_path" >&2
        return 1
    fi
    if ! cdp_flush_file "$staged_path"; then
        rm -f -- "$staged_path"
        echo "Error: failed to flush JSON document: $target_path" >&2
        return 1
    fi
    printf '%s\n' "$staged_path"
}

cdp_create_json_backup() {
    local target_path="$1"
    local backup_stamp
    local backup_path
    [[ ! -f "$target_path" ]] && return 0
    backup_stamp=$(date -u +'%Y%m%d%H%M%S')
    backup_path=$(mktemp "$target_path.cdp-backup.$backup_stamp.XXXXXX") || return 1
    if ! cp "$target_path" "$backup_path" || ! cdp_flush_file "$backup_path"; then
        rm -f -- "$backup_path"
        echo "Error: failed to preserve JSON backup: $target_path" >&2
        return 1
    fi
    printf '%s\n' "$backup_path"
}

cdp_commit_json_file() {
    local target_path="$1"
    local candidate_path="$2"
    local expected_fingerprint="${3:-}"
    local lock_path="$target_path.cdp.lock"
    local staged_path=""
    local backup_path=""
    local current_fingerprint

    mkdir "$lock_path" 2>/dev/null || {
        echo "Error: JSON document is locked by another cdp process: $target_path" >&2
        return 1
    }
    current_fingerprint=$(cdp_json_fingerprint "$target_path")
    if [[ -n "$expected_fingerprint" && "$expected_fingerprint" != "$current_fingerprint" ]]; then
        rmdir "$lock_path" 2>/dev/null || true
        echo "Error: JSON document changed since it was read: $target_path" >&2
        return 1
    fi
    staged_path=$(cdp_stage_json_candidate "$target_path" "$candidate_path") || {
        rmdir "$lock_path" 2>/dev/null || true
        return 1
    }
    backup_path=$(cdp_create_json_backup "$target_path") || {
        rm -f -- "$staged_path"
        rmdir "$lock_path" 2>/dev/null || true
        return 1
    }

    if ! mv -f "$staged_path" "$target_path"; then
        rm -f -- "$staged_path"
        [[ -n "$backup_path" ]] && rm -f -- "$backup_path"
        rmdir "$lock_path" 2>/dev/null || true
        return 1
    fi
    cdp_prune_json_backups "$target_path" 3
    rmdir "$lock_path" 2>/dev/null || true
}

cdp_write_json_text() {
    local target_path="$1"
    local json_text="$2"
    local expected_fingerprint="${3:-}"
    local candidate_path
    candidate_path=$(cdp_json_temp_file "$target_path") || return 1
    printf '%s\n' "$json_text" > "$candidate_path"
    if cdp_commit_json_file "$target_path" "$candidate_path" "$expected_fingerprint"; then
        rm -f -- "$candidate_path"
        return 0
    fi
    rm -f -- "$candidate_path"
    return 1
}

cdp_valid_json_backups() {
    local target_path="$1"
    local target_dir
    local target_name
    local backup_path
    target_dir=$(dirname "$target_path")
    target_name=$(basename "$target_path")
    find "$target_dir" -maxdepth 1 -type f -name "$target_name.cdp-backup.*" -print 2>/dev/null |
        sort -r |
        while IFS= read -r backup_path; do
            jq -e . "$backup_path" >/dev/null 2>&1 && printf '%s\n' "$backup_path"
        done
}

cdp_restore_json_backup() {
    local target_path="$1"
    local backup_path="$2"
    local expected_fingerprint
    if ! cdp_valid_json_backups "$target_path" | grep -Fx "$backup_path" >/dev/null 2>&1; then
        echo "Error: backup is missing or invalid: $backup_path" >&2
        return 1
    fi
    expected_fingerprint=$(cdp_json_fingerprint "$target_path")
    cdp_commit_json_file "$target_path" "$backup_path" "$expected_fingerprint"
}

cdp_sha256_text() {
    local value="$1"
    printf '%s' "$value" | if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
    else
        openssl dgst -sha256 | awk '{print $NF}'
    fi
}

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

# cdp shell domain: Paths.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

CDP_PROJECT_RAW_PATH=""
CDP_PROJECT_RESOLVED_PATH=""
CDP_PROJECT_PATH_PROFILE=""
CDP_PROJECT_PATH_SOURCE=""
CDP_PROJECT_PATH_EXPLICIT=false
CDP_PROJECT_PATH_ERROR_CODE=""
CDP_PROJECT_PATH_ERROR_MESSAGE=""

convert_windows_to_wsl() {
    local input_path="$1"

    case "$input_path" in
        [A-Za-z]:/*|[A-Za-z]:\\*)
            local drive
            local remainder
            drive="$(printf '%s' "${input_path%%:*}" | tr '[:upper:]' '[:lower:]')"
            remainder="${input_path#?:}"
            remainder="${remainder#?}"
            remainder="${remainder//\\//}"
            printf '/mnt/%s/%s\n' "$drive" "$remainder"
            ;;
        *) printf '%s\n' "$input_path" ;;
    esac
}

cdp_detect_path_profile() {
    local system_name
    local kernel_name
    system_name="$(uname -s 2>/dev/null || printf unknown)"
    kernel_name="$(uname -r 2>/dev/null || printf unknown)"

    case "$system_name" in
        Darwin) printf 'macos\n'; return 0 ;;
        MINGW*|MSYS*|CYGWIN*) printf 'windows\n'; return 0 ;;
    esac
    if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" || "$kernel_name" == *[Mm]icrosoft* ]]; then
        printf 'wsl\n'
    else
        printf 'linux\n'
    fi
}

cdp_current_path_profile() {
    local requested_profile="${1:-}"
    [[ -n "$requested_profile" ]] || requested_profile="${CDP_PATH_PROFILE:-}"
    if [[ -z "$requested_profile" ]]; then
        cdp_detect_path_profile
        return 0
    fi

    requested_profile="$(printf '%s' "$requested_profile" | tr '[:upper:]' '[:lower:]')"
    case "$requested_profile" in
        windows|wsl|linux|macos) printf '%s\n' "$requested_profile" ;;
        *)
            printf "Error: Invalid CDP_PATH_PROFILE '%s'. Expected windows, wsl, linux, or macos.\n" "$requested_profile" >&2
            return 1
            ;;
    esac
}

cdp_reset_project_path_resolution() {
    CDP_PROJECT_RAW_PATH=""
    CDP_PROJECT_RESOLVED_PATH=""
    CDP_PROJECT_PATH_PROFILE=""
    CDP_PROJECT_PATH_SOURCE=""
    CDP_PROJECT_PATH_EXPLICIT=false
    CDP_PROJECT_PATH_ERROR_CODE=""
    CDP_PROJECT_PATH_ERROR_MESSAGE=""
}

cdp_resolve_project_json() {
    local project_json="$1"
    local requested_profile="${2:-}"
    local profile
    local resolution
    local state
    cdp_reset_project_path_resolution
    profile="$(cdp_current_path_profile "$requested_profile")" || return 1
    CDP_PROJECT_PATH_PROFILE="$profile"

    resolution=$(printf '%s\n' "$project_json" | jq -jr --arg profile "$profile" '
        . as $project |
        (["windows","wsl","linux","macos"] | map(
            . as $candidate | select(
                ($project.paths | type) == "object" and ($project.paths | has($candidate)) and
                ((($project.paths[$candidate] | type) != "string") or (($project.paths[$candidate] | length) == 0))
            )
        ) | .[0]) as $invalidProfile |
        if ((.rootPath | type) != "string") or ((.rootPath | length) == 0) then
            ["invalid", (.rootPath // ""), "", "rootPath", "false", "Project rootPath must be a non-empty string."]
        elif has("paths") and ((.paths | type) != "object") then
            ["invalid", .rootPath, "", ("paths." + $profile), "true", "Project paths must be a JSON object."]
        elif $invalidProfile != null then
            ["invalid", .rootPath, "", ("paths." + $invalidProfile), ($invalidProfile == $profile | tostring), ("Project paths." + $invalidProfile + " must be a non-empty string.")]
        elif ((.paths | type) == "object") and (.paths | has($profile)) then
            ["explicit", .rootPath, .paths[$profile], ("paths." + $profile), "true", ""]
        else
            ["fallback", .rootPath, .rootPath, "rootPath", "false", ""]
        end | join("\u001c")
    ' 2>/dev/null) || {
        CDP_PROJECT_PATH_ERROR_CODE=path_profile_invalid
        CDP_PROJECT_PATH_ERROR_MESSAGE='Project path configuration is invalid JSON.'
        return 2
    }

    IFS=$'\034' read -r state CDP_PROJECT_RAW_PATH CDP_PROJECT_RESOLVED_PATH \
        CDP_PROJECT_PATH_SOURCE CDP_PROJECT_PATH_EXPLICIT CDP_PROJECT_PATH_ERROR_MESSAGE <<< "$resolution"
    if [[ "$state" == invalid ]]; then
        CDP_PROJECT_PATH_ERROR_CODE=path_profile_invalid
        return 2
    fi
    if [[ "$state" == fallback && "$profile" == wsl ]]; then
        CDP_PROJECT_RESOLVED_PATH="$(convert_windows_to_wsl "$CDP_PROJECT_RAW_PATH")"
        CDP_PROJECT_PATH_SOURCE='rootPath:wsl-converted'
    fi
    return 0
}

cdp_project_json_by_name() {
    local config_path="$1"
    local project_name="$2"
    jq -c --arg name "$project_name" \
        '.[] | select(.name == $name and .enabled == true)' "$config_path" 2>/dev/null | head -n1
}

cdp_find_project_by_local_path_json() {
    local config_json="$1"
    local local_path="$2"
    local candidate_path
    candidate_path=$(cd "$local_path" 2>/dev/null && pwd -P || printf '%s' "$local_path")

    while IFS= read -r project_json; do
        [[ -z "$project_json" ]] && continue
        if cdp_resolve_project_json "$project_json"; then
            local resolved_path
            resolved_path=$(cd "$CDP_PROJECT_RESOLVED_PATH" 2>/dev/null && pwd -P || printf '%s' "$CDP_PROJECT_RESOLVED_PATH")
            if [[ "$resolved_path" == "$candidate_path" ]]; then
                printf '%s\n' "$project_json"
                return 0
            fi
        fi
    done < <(printf '%s\n' "$config_json" | jq -c '.[]')
    return 1
}

cdp_new_project_json() {
    local project_name="$1"
    local project_path="$2"
    local profile
    profile="$(cdp_current_path_profile)" || return 1
    jq -cn --arg name "$project_name" --arg project_path "$project_path" --arg profile "$profile" '
        {name:$name,rootPath:$project_path,enabled:true,pinned:false,aliases:[],tags:[],paths:{($profile):$project_path}}
    '
}

# cdp shell domain: State.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

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

    if [[ ! -f "$state_path" ]]; then
        cdp_write_json_text "$state_path" '{"recentProjects":[]}' missing
    elif ! jq -e 'type == "object"' "$state_path" >/dev/null 2>&1; then
        echo "Error: refusing to overwrite invalid cdp state: $state_path" >&2
        return 1
    fi
}

cdp_record_recent() {
    local name="$1"
    local root_path="$2"
    local project_json="${3:-}"

    [[ -z "$name" || -z "$root_path" ]] && return 0
    command -v jq >/dev/null 2>&1 || return 0

    local state_path
    local temp_file
    local expected_fingerprint
    local now
    state_path=$(cdp_state_path)
    initialize_state "$state_path" || return 0
    expected_fingerprint=$(cdp_json_fingerprint "$state_path")
    temp_file=$(cdp_json_temp_file "$state_path") || return 0
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if jq --arg name "$name" --arg path "$root_path" --arg now "$now" --argjson project "${project_json:-null}" '
        .recentProjects as $recent |
        .recentProjects = (
            (($recent // []) | map(select(.rootPath != $path))) +
            [({
                "name": $name,
                "rootPath": $path,
                "lastVisitedAt": $now,
                "visitCount": (((($recent // []) | map(select(.rootPath == $path)) | .[0].visitCount) // 0) + 1)
            } + (if (($project.paths // null) | type) == "object" then {paths:$project.paths} else {} end))]
            | sort_by(.lastVisitedAt)
            | reverse
            | .[:20]
        )
    ' "$state_path" > "$temp_file" 2>/dev/null &&
        cdp_commit_json_file "$state_path" "$temp_file" "$expected_fingerprint"; then
        rm -f -- "$temp_file"
    else
        rm -f -- "$temp_file"
    fi
}

# Function to find all available config files

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
        local recent_json
        recent_json=$(jq -c --arg name "$name" --arg root "$project_path" \
            '.recentProjects[] | select(.name == $name and .rootPath == $root)' "$state_path" | head -n1)
        if cdp_resolve_project_json "$recent_json"; then
            display_path="$CDP_PROJECT_RESOLVED_PATH"
        else
            display_path="$project_path"
        fi
        printf "  ${GRAY}%02d  ${NC} ${GREEN}%-*s${NC} ${GRAY}%-24s ${CYAN}%-7s${NC} ${GRAY}%s${NC}\n" "$index" "$name_width" "$display_name" "$display_last" "$visits" "$display_path"
        ((index++))
    done <<< "$recent_projects"

    echo -e "${GRAY}$(printf -- '-%.0s' {1..110})${NC}"
    echo -e "${GRAY}state: $state_path${NC}"
}

# Function to add current directory as a project

# cdp shell domain: Picker.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

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
    echo "bash <(curl -fsSL https://raw.githubusercontent.com/GoldenZqqq/cdp/v$CDP_VERSION/install-wsl.sh) --auto"
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
        echo "path   $target_path"
        echo "raw    $raw_path"
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

        local project_json
        local raw_path
        local display_path
        local pinned
        local name_label
        local safe_name
        local safe_raw_path
        local safe_path
        project_json=$(cdp_project_json_by_name "$config_path" "$name")
        if cdp_resolve_project_json "$project_json"; then
            raw_path="$CDP_PROJECT_RAW_PATH"
            display_path="$CDP_PROJECT_RESOLVED_PATH"
        else
            raw_path=$(printf '%s' "$project_json" | jq -r '.rootPath // empty')
            display_path="<invalid ${CDP_PROJECT_PATH_SOURCE:-path profile}>"
        fi
        pinned=$(jq -r --arg name "$name" \
            '.[] | select(.name == $name and .enabled == true) | (.pinned == true)' \
            "$config_path" 2>/dev/null | head -n1)
        safe_name=$(sanitize_picker_field "$name")
        safe_raw_path=$(sanitize_picker_field "$raw_path")
        safe_path=$(sanitize_picker_field "$display_path")
        name_label="$safe_name"
        if [[ "$pinned" == "true" ]]; then
            name_label="[pin] $safe_name"
        fi

        cdp_picker_preview "$safe_name" "$safe_raw_path" "$display_path" "$preview_dir/$index.txt"
        printf "%s\t%s\t%s\t%b%3d%b\t%b%s%b\t%b%s%b\n" \
            "$index" "$safe_name" "$raw_path" \
            "$GRAY" "$index" "$NC" \
            "$BOLD_CYAN" "$name_label" "$NC" \
            "$GRAY" "$safe_path" "$NC"
        ((index++))
    done <<< "$projects"
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
        LC_ALL=C printf -v code '%d' "'$ch" 2>/dev/null || code=0
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
        LC_ALL=C printf -v code '%d' "'$ch" 2>/dev/null || code=0
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

# cdp shell domain: Hooks.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

cdp_hook_trust_path() {
    if [[ -n "${CDP_HOOK_TRUST_PATH:-}" ]]; then
        printf '%s\n' "$CDP_HOOK_TRUST_PATH"
    else
        printf '%s/.cdp/hook-trust.json\n' "$HOME"
    fi
}

cdp_normalize_config_path() {
    local config_path
    local config_dir
    local config_name
    config_path=$(convert_windows_to_wsl "$1")
    config_dir=$(dirname "$config_path")
    config_name=$(basename "$config_path")
    if (cd "$config_dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$config_name"); then
        return 0
    fi
    printf '%s\n' "$config_path"
}

cdp_load_hook_trust_store() {
    CDP_HOOK_TRUST_PATH_VALUE=$(cdp_hook_trust_path)
    if [[ ! -f "$CDP_HOOK_TRUST_PATH_VALUE" ]]; then
        CDP_HOOK_TRUST_FINGERPRINT=missing
        CDP_HOOK_TRUST_DOCUMENT='{"version":1,"entries":[]}'
        return 0
    fi
    chmod 600 "$CDP_HOOK_TRUST_PATH_VALUE" 2>/dev/null || {
        echo 'Error: unable to secure cdp hook trust store.' >&2
        return 1
    }
    CDP_HOOK_TRUST_DOCUMENT=$(cat "$CDP_HOOK_TRUST_PATH_VALUE")
    jq -e 'type == "object" and .version == 1 and (.entries | type == "array")' \
        "$CDP_HOOK_TRUST_PATH_VALUE" >/dev/null 2>&1 || {
        echo 'Error: invalid cdp hook trust store.' >&2
        return 1
    }
    CDP_HOOK_TRUST_FINGERPRINT=$(cdp_json_fingerprint "$CDP_HOOK_TRUST_PATH_VALUE")
}

cdp_save_hook_trust_store() {
    local json_text="$1"
    local expected_fingerprint="$2"
    (umask 077; cdp_write_json_text "$CDP_HOOK_TRUST_PATH_VALUE" "$json_text" "$expected_fingerprint") || return 1
    chmod 600 "$CDP_HOOK_TRUST_PATH_VALUE" 2>/dev/null || {
        echo 'Error: unable to secure cdp hook trust store.' >&2
        return 1
    }
}

cdp_hook_identity_from_json() {
    local config_path="$1"
    local project_json="$2"
    local hook_kind
    local hook_command
    local name_hash
    local root_hash
    local command_hash
    local config_content_hash
    hook_kind=$(printf '%s' "$project_json" | jq -r 'if (.onEnter | type) == "string" then "bash" elif (.onEnter.bash // "") != "" then "bash" else "" end')
    hook_command=$(printf '%s' "$project_json" | jq -r 'if (.onEnter | type) == "string" then .onEnter elif (.onEnter.bash // "") != "" then .onEnter.bash else "" end')
    [[ -z "$hook_kind" || -z "$hook_command" || "$hook_command" == null ]] && return 1
    name_hash=$(cdp_sha256_text "$(printf '%s' "$project_json" | jq -r '.name')")
    root_hash=$(cdp_sha256_text "$(printf '%s' "$project_json" | jq -r '.rootPath')")
    command_hash=$(cdp_sha256_text "$hook_command")
    config_content_hash=$(cdp_json_fingerprint "$config_path")
    CDP_HOOK_CONFIG_FINGERPRINT=$(cdp_sha256_text "$(cdp_normalize_config_path "$config_path")")
    CDP_HOOK_PROJECT_FINGERPRINT=$(cdp_sha256_text "name=$name_hash;root=$root_hash")
    CDP_HOOK_FINGERPRINT=$(cdp_sha256_text "config=$config_content_hash;kind=$hook_kind;command=$command_hash")
    CDP_HOOK_KIND="$hook_kind"
}

cdp_hook_project_json() {
    local config_path="$1"
    local project_query="$2"
    local matches
    matches=$(find_project_matches "$config_path" "$project_query")
    [[ "$(line_count "$matches")" -eq 1 ]] || return 1
    jq -c --arg name "$matches" '.[] | select(.enabled == true and .name == $name)' "$config_path" 2>/dev/null | head -n 1
}

cdp_hook_is_trusted() {
    local config_path="$1"
    local project_json="$2"
    CDP_HOOK_TRUST_ERROR=false
    cdp_hook_identity_from_json "$config_path" "$project_json" || return 1
    if ! cdp_load_hook_trust_store; then
        CDP_HOOK_TRUST_ERROR=true
        return 1
    fi
    jq -e --arg cf "$CDP_HOOK_CONFIG_FINGERPRINT" \
        --arg pf "$CDP_HOOK_PROJECT_FINGERPRINT" \
        --arg hf "$CDP_HOOK_FINGERPRINT" \
        '.entries[] | select(.configFingerprint == $cf and .projectFingerprint == $pf and .hookFingerprint == $hf)' \
        <<< "$CDP_HOOK_TRUST_DOCUMENT" >/dev/null 2>&1
}

cdp_hook_list() {
    local config_path="$1"
    cdp_load_hook_trust_store || return 1
    echo -e "${CYAN}cdp hook trust${NC}"
    while IFS= read -r project_json <&3; do
        [[ -z "$project_json" ]] && continue
        cdp_hook_identity_from_json "$config_path" "$project_json" || continue
        local state="untrusted"
        if jq -e --arg cf "$CDP_HOOK_CONFIG_FINGERPRINT" --arg pf "$CDP_HOOK_PROJECT_FINGERPRINT" \
            '.entries[] | select(.configFingerprint == $cf and .projectFingerprint == $pf)' \
            <<< "$CDP_HOOK_TRUST_DOCUMENT" >/dev/null 2>&1; then
            state="stale"
        fi
        if cdp_hook_is_trusted "$config_path" "$project_json"; then state="trusted"; fi
        echo "  $(printf '%s' "$project_json" | jq -r '.name') [$CDP_HOOK_KIND] $state"
    done 3< <(jq -c '.[] | select(.enabled == true and .onEnter != null)' "$config_path")
}

cdp_hook_trust() {
    local config_path="$1"
    local project_name="$2"
    local project_json
    project_json=$(cdp_hook_project_json "$config_path" "$project_name")
    [[ -z "$project_json" ]] && { echo 'Error: hook trust requires one enabled project match.' >&2; return 1; }
    cdp_hook_identity_from_json "$config_path" "$project_json" || { echo 'Error: project has no supported command hook.' >&2; return 1; }
    if $CDP_SAFETY_DRY_RUN; then
        echo -e "${GRAY}Would trust hook for project: $project_name${NC}"
        cdp_action_result hook-trust "$project_name" preview false
        return 0
    fi
    cdp_load_hook_trust_store || return 1
    local trusted_at
    trusted_at=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    local updated
    updated=$(jq --arg cf "$CDP_HOOK_CONFIG_FINGERPRINT" --arg pf "$CDP_HOOK_PROJECT_FINGERPRINT" \
        --arg hf "$CDP_HOOK_FINGERPRINT" --arg at "$trusted_at" \
        '.entries = ([.entries[] | select(.configFingerprint != $cf or .projectFingerprint != $pf)] + [{configFingerprint:$cf,projectFingerprint:$pf,hookFingerprint:$hf,trustedAt:$at}])' \
        <<< "$CDP_HOOK_TRUST_DOCUMENT")
    cdp_save_hook_trust_store "$updated" "$CDP_HOOK_TRUST_FINGERPRINT" || return 1
    echo -e "${GREEN}Trusted hook for project: $project_name${NC}"
}

cdp_hook_revoke() {
    local config_path="$1"
    local project_name="$2"
    cdp_load_hook_trust_store || return 1
    local config_fingerprint
    config_fingerprint=$(cdp_sha256_text "$(cdp_normalize_config_path "$config_path")")
    local updated
    if [[ "$project_name" == "--all" ]]; then
        updated=$(jq --arg cf "$config_fingerprint" '.entries = [.entries[] | select(.configFingerprint != $cf)]' <<< "$CDP_HOOK_TRUST_DOCUMENT")
    else
        local project_json
        project_json=$(cdp_hook_project_json "$config_path" "$project_name")
        [[ -z "$project_json" ]] && { echo 'Error: hook revoke requires one enabled project match.' >&2; return 1; }
        cdp_hook_identity_from_json "$config_path" "$project_json" || return 1
        updated=$(jq --arg cf "$config_fingerprint" --arg pf "$CDP_HOOK_PROJECT_FINGERPRINT" \
            '.entries = [.entries[] | select(.configFingerprint != $cf or .projectFingerprint != $pf)]' \
            <<< "$CDP_HOOK_TRUST_DOCUMENT")
    fi
    local target="$project_name"
    [[ "$project_name" == "--all" ]] && target="all hooks for active config"
    if $CDP_SAFETY_DRY_RUN; then
        echo -e "${GRAY}Would revoke hook trust: $target${NC}"
        cdp_action_result hook-revoke "$target" preview false
        return 0
    fi
    cdp_save_hook_trust_store "$updated" "$CDP_HOOK_TRUST_FINGERPRINT" || return 1
    echo -e "${GREEN}Hook trust revoked.${NC}"
}

cdp-hook() {
    local action="${1:-}"
    local project_name=""
    local config_path=""
    local all=false
    [[ $# -gt 0 ]] && shift
    cdp_parse_safety_options "$@" || return 1
    set -- "${CDP_SAFETY_ARGS[@]}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config|-config) [[ -n "${2:-}" ]] || { echo 'Error: missing value after --config.' >&2; return 1; }; config_path="$2"; shift 2 ;;
            --all) all=true; shift ;;
            -*) echo "Error: unknown hook option: $1" >&2; return 1 ;;
            *)
                if [[ -z "$project_name" ]]; then
                    project_name="$1"
                elif [[ -z "$config_path" ]] && is_config_path_arg "$1"; then
                    config_path="$1"
                else
                    echo 'Error: hook accepts one project and one config path.' >&2
                    return 1
                fi
                shift
                ;;
        esac
    done
    [[ -z "$action" ]] && action=list
    if [[ "$action" == list && -n "$project_name" && -z "$config_path" ]] && is_config_path_arg "$project_name"; then
        config_path="$project_name"
        project_name=""
    elif [[ "$action" == revoke && "$all" == true && -n "$project_name" && -z "$config_path" ]] && is_config_path_arg "$project_name"; then
        config_path="$project_name"
        project_name=""
    fi
    [[ -z "$config_path" ]] && config_path=$(get_default_config)
    if [[ "$action" == list ]]; then
        if $CDP_SAFETY_DRY_RUN || $CDP_SAFETY_YES; then
            echo 'Error: hook list does not accept safety options.' >&2
            return 1
        fi
        [[ -z "$project_name" && "$all" == false ]] || { echo 'Error: hook list does not accept a project.' >&2; return 1; }
        cdp_hook_list "$config_path"
    elif [[ "$action" == trust ]]; then
        [[ -n "$project_name" && "$all" == false ]] || { echo 'Error: hook trust requires a project.' >&2; return 1; }
        cdp_hook_trust "$config_path" "$project_name"
    elif [[ "$action" == revoke ]]; then
        [[ "$all" == true || -n "$project_name" ]] || { echo 'Error: hook revoke requires a project or --all.' >&2; return 1; }
        cdp_hook_revoke "$config_path" "${project_name:---all}"
    else
        echo "Error: unknown hook action: $action" >&2
        return 1
    fi
}

# Function to get stored config choice path

cdp_apply_on_enter_env() {
    local on_enter="$1"
    if printf '%s' "$on_enter" | jq -e 'type == "object"' >/dev/null 2>&1; then
        local env_key
        local env_value
        while IFS= read -r env_key <&3; do
            [[ -z "$env_key" ]] && continue
            case "$env_key" in
                [A-Za-z_]* ) ;;
                * )
                    echo -e "${YELLOW}  onEnter warning: invalid environment variable name skipped.${NC}"
                    continue
                    ;;
            esac
            case "$env_key" in
                *[!A-Za-z0-9_]* )
                    echo -e "${YELLOW}  onEnter warning: invalid environment variable name skipped.${NC}"
                    continue
                    ;;
            esac
            env_value=$(printf '%s' "$on_enter" | jq -r --arg key "$env_key" '.env[$key] | tostring')
            export "$env_key=$env_value"
        done 3<<< "$(printf '%s' "$on_enter" | jq -r '.env // {} | keys[]')"
    fi
}

cdp_apply_on_enter() {
    local on_enter="$1"
    local allow_hook="$2"
    local config_path="$3"
    local project_json="$4"
    local no_hook="$5"
    local hook_command=""

    if [[ "$no_hook" == true ]]; then
        echo -e "${YELLOW}  onEnter skipped by --no-hook.${NC}"
        return 0
    fi

    cdp_apply_on_enter_env "$on_enter"
    if printf '%s' "$on_enter" | jq -e 'type == "object"' >/dev/null 2>&1; then
        hook_command=$(printf '%s' "$on_enter" | jq -r '.bash // empty')
    else
        hook_command="$on_enter"
    fi

    hook_command="${hook_command%$'\r'}"
    [[ -z "$hook_command" || "$hook_command" == "null" ]] && return 0
    if [[ "$allow_hook" != true ]]; then
        if ! cdp_hook_is_trusted "$config_path" "$project_json"; then
            echo -e "${YELLOW}  onEnter command skipped: trust this project hook or use --allow-hook once.${NC}"
            return 0
        fi
    fi

    if ! eval "$hook_command" 2>/dev/null; then
        echo -e "${YELLOW}  onEnter warning: command failed.${NC}"
    fi
}

# cdp shell domain: Health.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

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
        local backup_count
        backup_count=$(cdp_valid_json_backups "$config_path" | wc -l | tr -d ' ')
        if [[ "$backup_count" -gt 0 ]]; then
            cdp_print_check fail "JSON" "expected a top-level project array; $backup_count valid cdp backup(s) available"
        else
            cdp_print_check fail "JSON" "expected a top-level project array"
        fi
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
    local invalid_profile_count=0

    project_count=$(jq 'length' "$config_path")
    enabled_count=$(jq '[.[] | select(.enabled == true)] | length' "$config_path")
    invalid_count=$(jq '[.[] | select((.name | type != "string") or (.rootPath | type != "string") or (.enabled | type != "boolean"))] | length' "$config_path")
    duplicate_count=$(jq '[group_by(.name)[] | select(length > 1)] | length' "$config_path")

    while IFS= read -r project_json; do
        [[ -z "$project_json" ]] && continue
        if ! cdp_resolve_project_json "$project_json"; then
            invalid_profile_count=$((invalid_profile_count + 1))
            continue
        fi
        if [[ ! -d "$CDP_PROJECT_RESOLVED_PATH" ]]; then
            ((missing_path_count++))
        fi
    done < <(jq -c '.[] | select(.enabled == true)' "$config_path")

    if [[ "$invalid_count" -eq 0 ]]; then
        cdp_print_check ok "project schema" "0 invalid project entries"
    else
        cdp_print_check fail "project schema" "$invalid_count invalid project entries"
        ((error_count++))
    fi

    if [[ "$invalid_profile_count" -eq 0 ]]; then
        cdp_print_check ok "path profiles" "0 invalid current path profiles"
    else
        cdp_print_check fail "path profiles" "$invalid_profile_count invalid current path profiles"
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

# cdp shell domain: StatusBatch.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

CDP_STATUS_CACHE_KEYS=()
CDP_STATUS_CACHE_TIMES=()
CDP_STATUS_CACHE_VALUES=()

cdp_status_setting() {
    local name="$1" default_value="$2" minimum="$3" maximum="$4"
    local value="$default_value"
    case "$name" in
        CDP_STATUS_CONCURRENCY) value="${CDP_STATUS_CONCURRENCY:-$default_value}" ;;
        CDP_STATUS_TIMEOUT_SECONDS) value="${CDP_STATUS_TIMEOUT_SECONDS:-$default_value}" ;;
        CDP_STATUS_CACHE_TTL) value="${CDP_STATUS_CACHE_TTL:-$default_value}" ;;
    esac
    [[ "$value" =~ ^[0-9]+$ ]] || value="$default_value"
    (( value < minimum )) && value="$minimum"
    (( value > maximum )) && value="$maximum"
    echo "$value"
}

cdp_status_cache_get() {
    local key="$1" ttl="$2" refresh="$3" now i
    [[ "$refresh" == true || "$ttl" -le 0 ]] && return 1
    now=$(date +%s)
    for ((i=0; i<${#CDP_STATUS_CACHE_KEYS[@]}; i++)); do
        if [[ "${CDP_STATUS_CACHE_KEYS[$i]}" == "$key" ]]; then
            if (( now - CDP_STATUS_CACHE_TIMES[$i] < ttl )); then
                printf '%s' "${CDP_STATUS_CACHE_VALUES[$i]}"
                return 0
            fi
            return 1
        fi
    done
    return 1
}

cdp_status_cache_set() {
    local key="$1" value="$2" ttl="$3" now i
    [[ "$ttl" -le 0 ]] && return 0
    now=$(date +%s)
    for ((i=0; i<${#CDP_STATUS_CACHE_KEYS[@]}; i++)); do
        if [[ "${CDP_STATUS_CACHE_KEYS[$i]}" == "$key" ]]; then
            CDP_STATUS_CACHE_TIMES[$i]="$now"
            CDP_STATUS_CACHE_VALUES[$i]="$value"
            return 0
        fi
    done
    CDP_STATUS_CACHE_KEYS+=("$key")
    CDP_STATUS_CACHE_TIMES+=("$now")
    CDP_STATUS_CACHE_VALUES+=("$value")
}

# cdp shell domain: Status.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

cdp_status_git_command() {
    local timeout_seconds="$1"
    shift
    local git_command="${CDP_STATUS_GIT_COMMAND:-git}"
    local timeout_exit=0
    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout_seconds" "$git_command" "$@" || timeout_exit=$?
        [[ "$timeout_exit" -eq 143 ]] && return 124
        return "$timeout_exit"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$timeout_seconds" "$git_command" "$@" || timeout_exit=$?
        [[ "$timeout_exit" -eq 143 ]] && return 124
        return "$timeout_exit"
    else
        "$git_command" "$@" &
        local command_pid=$!
        (sleep "$timeout_seconds"; kill -TERM "$command_pid" 2>/dev/null || true) &
        local timer_pid=$!
        local exit_code=0
        wait "$command_pid" || exit_code=$?
        if [[ "$exit_code" -eq 143 ]]; then
            kill -TERM "$timer_pid" 2>/dev/null || true
            wait "$timer_pid" 2>/dev/null || true
            return 124
        fi
        if kill -TERM "$timer_pid" 2>/dev/null; then
            wait "$timer_pid" 2>/dev/null || true
            return "$exit_code"
        fi
        wait "$timer_pid" 2>/dev/null || true
        return 124
    fi
}

cdp_status_collect_record() {
    local repository_path="$1"
    local timeout_seconds="$2"
    local porcelain
    local exit_code
    local line
    local oid=""
    local branch=""
    local remote=""
    local upstream=""
    local dirty=0
    local untracked=0
    local ahead=0
    local behind=0
    local last_commit=""

    if [[ ! -d "$repository_path" ]]; then
        printf 'missing\034-\034\034\0340\0340\0340\0340\034\n'
        return 0
    fi
    if porcelain=$(cdp_status_git_command "$timeout_seconds" -C "$repository_path" status --porcelain=v2 --branch --untracked-files=all 2>/dev/null); then
        exit_code=0
    else
        exit_code=$?
    fi
    if [[ $exit_code -ne 0 ]]; then
        if [[ $exit_code -eq 124 ]]; then
            printf 'timed-out\034-\034\034\0340\0340\0340\0340\034\n'
        else
            printf 'not-git\034-\034\034\0340\0340\0340\0340\034\n'
        fi
        return 0
    fi

    while IFS= read -r line; do
        case "$line" in
            '# branch.oid '*) oid="${line#\# branch.oid }" ;;
            '# branch.head '*) branch="${line#\# branch.head }" ;;
            '# branch.upstream '*)
                upstream="${line#\# branch.upstream }"
                [[ "$upstream" == */* ]] && remote="${upstream%%/*}"
                ;;
            '# branch.ab '*)
                ahead="${line#*+}"
                ahead="${ahead%% *}"
                behind="${line##*-}"
                ;;
            '? '*) untracked=$((untracked + 1)) ;;
            1\ *|2\ *|u\ *) dirty=$((dirty + 1)) ;;
        esac
    done <<< "$porcelain"

    if [[ "$branch" == "(detached)" || -z "$branch" ]]; then
        branch="${oid:0:7}"
        [[ "$oid" == "(initial)" ]] && branch=""
    fi
    if [[ "$oid" != "" && "$oid" != "(initial)" ]]; then
        last_commit=$(cdp_status_git_command "$timeout_seconds" -C "$repository_path" log -1 --format='%cr' 2>/dev/null || true)
    fi
    printf 'git\034%s\034%s\034%s\034%s\034%s\034%s\034%s\034%s\n' \
        "$branch" "$remote" "$upstream" "$dirty" "$untracked" "$ahead" "$behind" "$last_commit"
}

cdp-status() {
    local config_path=""
    local dirty_only=false
    local tag_filter=""
    local do_fix=false
    local do_push=false
    local dry_run=false
    local assume_yes=false
    local refresh=false
    local jobs=0
    local json_mode=false
    local no_color=false
    local requested_json=false
    local requested_arg
    for requested_arg in "$@"; do
        [[ "$requested_arg" == --json ]] && requested_json=true
    done
    json_mode=$requested_json

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dirty|-d) dirty_only=true ;;
            --fix)      do_fix=true ;;
            --push)     do_push=true ;;
            --json)     json_mode=true ;;
            --no-color) no_color=true ;;
            --dry-run)  dry_run=true ;;
            --yes)      assume_yes=true ;;
            --refresh)  refresh=true ;;
            --jobs|--concurrency)
                [[ -z "${2:-}" ]] && { cdp_status_fail "$json_mode" 'missing value after --jobs.'; return $?; }
                [[ "$2" =~ ^[0-9]+$ ]] && jobs="$2" || jobs=0
                (( jobs >= 1 && jobs <= 16 )) || { cdp_status_fail "$json_mode" 'status jobs must be between 1 and 16.'; return $?; }
                shift
                ;;
            --config)
                [[ -z "${2:-}" ]] && { cdp_status_fail "$json_mode" 'missing value after --config.'; return $?; }
                [[ -n "$config_path" ]] && { cdp_status_fail "$json_mode" 'config path specified more than once.'; return $?; }
                config_path="$2"
                shift
                ;;
            @*)
                [[ -n "$tag_filter" ]] && { cdp_status_fail "$json_mode" 'only one status tag filter is allowed.'; return $?; }
                tag_filter="$1"
                ;;
            -*)
                cdp_status_fail "$json_mode" "unknown status option: $1"
                return $?
                ;;
            *)
                [[ -n "$config_path" ]] && { cdp_status_fail "$json_mode" 'config path specified more than once.'; return $?; }
                config_path="$1"
                ;;
        esac
        shift
    done

    if $do_fix && $do_push; then
        cdp_status_fail "$json_mode" '--fix and --push cannot be used together.'; return $?
    fi
    if $dirty_only && { $do_fix || $do_push; }; then
        cdp_status_fail "$json_mode" '--dirty cannot be combined with status actions.'; return $?
    fi
    if $json_mode && $no_color; then
        cdp_status_fail "$json_mode" '--json and --no-color cannot be used together.'; return $?
    fi
    if $json_mode && { $do_fix || $do_push; }; then
        cdp_status_fail "$json_mode" '--json is only valid for read-only status.'; return $?
    fi
    if $no_color && { $do_fix || $do_push; }; then
        cdp_status_fail false '--no-color is only valid for read-only status.'; return $?
    fi
    if $dry_run && $assume_yes; then
        cdp_status_fail "$json_mode" '--dry-run and --yes cannot be used together.'; return $?
    fi
    if { $dry_run || $assume_yes; } && ! { $do_fix || $do_push; }; then
        cdp_status_fail "$json_mode" '--dry-run and --yes require --fix or --push.'; return $?
    fi

    if ! command -v jq &> /dev/null; then
        cdp_status_fail "$json_mode" "'jq' command not found."; return $?
    fi

    if ! command -v git &> /dev/null; then
        cdp_status_fail "$json_mode" "'git' command not found."; return $?
    fi

    if [[ -z "$config_path" ]]; then
        config_path=$(get_default_config)
    fi

    if [[ ! -f "$config_path" ]]; then
        cdp_status_fail "$json_mode" "Configuration file not found at: $config_path"; return $?
    fi

    local active_path_profile
    if ! active_path_profile=$(cdp_current_path_profile); then
        cdp_status_fail "$json_mode" "Invalid CDP_PATH_PROFILE."; return $?
    fi

    local expected_fingerprint=""
    if $do_fix; then
        expected_fingerprint=$(cdp_json_fingerprint "$config_path")
    fi

    local jq_filter='.[] | select(.enabled == true)'
    if [[ -n "$tag_filter" ]]; then
        local tag_query="${tag_filter#@}"
        jq_filter=".[] | select(.enabled == true) | select(((.tags // []) | map(ascii_downcase) | index(\"$(echo "$tag_query" | tr '[:upper:]' '[:lower:]')\")) != null)"
    fi

    local projects
    if ! projects=$(jq -c "$jq_filter" "$config_path" 2>/dev/null); then
        cdp_status_fail "$json_mode" 'Failed to read configuration.'; return $?
    fi

    if [[ -z "$projects" ]]; then
        if $json_mode; then cdp_status_render_empty_json "$dirty_only" "$tag_filter" "$refresh"
        elif $no_color; then printf 'No projects to check.\n'
        else echo -e "${YELLOW}No projects to check.${NC}"; fi
        return 0
    fi

    local total=0
    local attention_count=0
    local missing_count=0
    local explicit_missing_count=0
    local max_name_len=14
    local max_branch_len=12
    local -a names=() raw_paths=() paths=() path_profiles=() path_sources=() path_explicit=() branches=() remotes=() upstreams=() record_kinds=()
    local -a statuses=() status_colors=() syncs=() sync_colors=() last_commits=() needs_attention=()
    local -a dirty_counts=() untracked_counts=() ahead_counts=() behind_counts=()

    while IFS= read -r project_json; do
        project_json="${project_json%$'\r'}"
        local pname
        local ppath
        pname=$(printf '%s' "$project_json" | jq -r '.name // empty')
        [[ -z "$pname" ]] && continue
        if cdp_resolve_project_json "$project_json" "$active_path_profile"; then
            ppath="$CDP_PROJECT_RAW_PATH"
        else
            ppath=$(printf '%s' "$project_json" | jq -r '.rootPath // empty')
        fi
        names+=("$pname")
        raw_paths+=("$ppath")
        paths+=("$CDP_PROJECT_RESOLVED_PATH")
        path_profiles+=("$CDP_PROJECT_PATH_PROFILE")
        path_sources+=("$CDP_PROJECT_PATH_SOURCE")
        path_explicit+=("$CDP_PROJECT_PATH_EXPLICIT")
        local name_len
        name_len=$(cdp_display_width "$pname")
        [[ $name_len -gt $max_name_len ]] && max_name_len=$name_len
        total=$((total + 1))
    done <<< "$projects"

    [[ $jobs -gt 0 ]] || jobs=$(cdp_status_setting CDP_STATUS_CONCURRENCY 4 1 16)
    local timeout_seconds
    timeout_seconds=$(cdp_status_setting CDP_STATUS_TIMEOUT_SECONDS 10 1 60)
    local cache_ttl
    cache_ttl=$(cdp_status_setting CDP_STATUS_CACHE_TTL 0 0 60)
    if $do_fix || $do_push; then refresh=true; fi
    local scan_start_epoch
    scan_start_epoch=$(date +%s)

    local result_dir
    result_dir=$(mktemp -d "${TMPDIR:-/tmp}/cdp-status.XXXXXX")
    local batch_start=0
    while (( batch_start < total )); do
        local batch_end=$((batch_start + jobs))
        (( batch_end > total )) && batch_end=$total
        local -a pids=()
        local i
        for ((i=batch_start; i<batch_end; i++)); do
            local cached_record=""
            if [[ -z "${paths[$i]}" ]]; then
                printf 'invalid-profile\034-\034\034\0340\0340\0340\0340\034\n' > "$result_dir/$i.record"
            elif cached_record=$(cdp_status_cache_get "${path_profiles[$i]}:${paths[$i]}" "$cache_ttl" "$refresh"); then
                printf '%s\n' "$cached_record" > "$result_dir/$i.record"
            else
                cdp_status_collect_record "${paths[$i]}" "$timeout_seconds" > "$result_dir/$i.record" &
                pids+=("$!")
            fi
        done
        local pid
        if (( ${#pids[@]} > 0 )); then
            for pid in "${pids[@]}"; do wait "$pid" || true; done
        fi
        batch_start=$batch_end
    done

    local proj_scanned=0
    local record_kind branch remote upstream dirty_count untracked_count ahead behind last_commit
    for ((i=0; i<total; i++)); do
        local record=""
        [[ -f "$result_dir/$i.record" ]] && record=$(cat "$result_dir/$i.record")
        [[ -n "$record" ]] || record=$'failed\034-\034\034\0340\0340\0340\0340\034'
        [[ -n "${paths[$i]}" ]] && cdp_status_cache_set "${path_profiles[$i]}:${paths[$i]}" "$record" "$cache_ttl"
        IFS=$'\034' read -r record_kind branch remote upstream dirty_count untracked_count ahead behind last_commit <<< "$record"
        record_kinds+=("$record_kind")
        branches+=("$branch")
        remotes+=("$remote")
        upstreams+=("$upstream")
        last_commits+=("$last_commit")
        dirty_counts+=("$dirty_count")
        untracked_counts+=("$untracked_count")
        ahead_counts+=("$ahead")
        behind_counts+=("$behind")

        local sync_text=""
        local s_color="$GRAY"
        case "$record_kind" in
            missing)
                statuses+=("path missing"); status_colors+=("$RED"); needs_attention+=(true)
                if [[ "${path_explicit[$i]}" == true ]]; then
                    explicit_missing_count=$((explicit_missing_count + 1))
                else
                    missing_count=$((missing_count + 1))
                fi
                ;;
            invalid-profile)
                statuses+=("path profile invalid"); status_colors+=("$RED"); needs_attention+=(true)
                attention_count=$((attention_count + 1))
                ;;
            not-git)
                statuses+=("not a git repo"); status_colors+=("$GRAY"); needs_attention+=(false)
                ;;
            timed-out)
                statuses+=("status timed out"); status_colors+=("$RED"); needs_attention+=(true)
                attention_count=$((attention_count + 1))
                ;;
            git)
                local branch_len
                branch_len=$(cdp_display_width "$branch")
                [[ $branch_len -gt $max_branch_len ]] && max_branch_len=$branch_len
                if [[ $dirty_count -gt 0 && $untracked_count -gt 0 ]]; then
                    statuses+=("x $dirty_count dirty + $untracked_count untracked"); status_colors+=("$RED"); needs_attention+=(true)
                elif [[ $dirty_count -gt 0 ]]; then
                    statuses+=("x $dirty_count dirty"); status_colors+=("$RED"); needs_attention+=(true)
                elif [[ $untracked_count -gt 0 ]]; then
                    statuses+=("! $untracked_count untracked"); status_colors+=("$YELLOW"); needs_attention+=(true)
                else
                    statuses+=("+ clean"); status_colors+=("$GREEN"); needs_attention+=(false)
                fi
                [[ $ahead -gt 0 ]] && sync_text="^${ahead}"
                [[ $behind -gt 0 ]] && { [[ -n "$sync_text" ]] && sync_text="$sync_text "; sync_text="${sync_text}v${behind}"; }
                [[ $behind -gt 0 ]] && s_color="$YELLOW"
                [[ $behind -eq 0 && $ahead -gt 0 ]] && s_color="$CYAN"
                if [[ $dirty_count -gt 0 || $untracked_count -gt 0 || $behind -gt 0 ]]; then
                    attention_count=$((attention_count + 1))
                    needs_attention[${#needs_attention[@]}-1]=true
                fi
                ;;
            *)
                statuses+=("status failed"); status_colors+=("$RED"); needs_attention+=(true)
                attention_count=$((attention_count + 1))
                ;;
        esac
        syncs+=("$sync_text")
        sync_colors+=("$s_color")
        proj_scanned=$((proj_scanned + 1))
        $json_mode || printf "\r  Scanning %d/%d (%d workers)... " "$proj_scanned" "$total" "$jobs" >&2
    done
    rm -f "$result_dir"/*.record 2>/dev/null || true
    rmdir "$result_dir" 2>/dev/null || true
    $json_mode || printf "\r                                      \r" >&2

    # --fix: remove path-missing projects (skip table render)
    if $do_fix; then
        if [[ $explicit_missing_count -gt 0 ]]; then
            echo -e "\n${YELLOW}Keeping $explicit_missing_count projects with unavailable explicit profile paths:${NC}"
            for ((i=0; i<total; i++)); do
                if [[ "${statuses[$i]}" == "path missing" && "${path_explicit[$i]}" == true ]]; then
                    echo -e "  ${GRAY}${names[$i]} [${path_profiles[$i]}] -> ${paths[$i]}${NC}"
                fi
            done
        fi
        if [[ $missing_count -eq 0 ]]; then
            echo -e "${GREEN}No path-missing projects to remove.${NC}"
            return
        fi
        echo -e "\n${YELLOW}Removing $missing_count path-missing projects:${NC}"
        for ((i=0; i<total; i++)); do
            if [[ "${statuses[$i]}" == "path missing" && "${path_explicit[$i]}" != true ]]; then
                echo -e "  ${GRAY}x ${names[$i]}  ${raw_paths[$i]}${NC}"
            fi
        done
        if $dry_run; then
            echo -e "\n${GRAY}Dry run: no project entries were removed.${NC}"
            for ((i=0; i<total; i++)); do
                [[ "${statuses[$i]}" == "path missing" && "${path_explicit[$i]}" != true ]] && cdp_action_result status-fix "${names[$i]}" preview false
            done
            return 0
        fi
        if ! $assume_yes; then
            echo -e "\n${RED}Action requires explicit confirmation. Re-run with --yes or preview with --dry-run.${NC}"
            for ((i=0; i<total; i++)); do
                [[ "${statuses[$i]}" == "path missing" && "${path_explicit[$i]}" != true ]] && cdp_action_result status-fix "${names[$i]}" canceled false
            done
            return 1
        fi
        local missing_identities=()
        for ((i=0; i<total; i++)); do
            if [[ "${statuses[$i]}" == "path missing" && "${path_explicit[$i]}" != true ]]; then
                missing_identities+=("$(jq -cn --arg name "${names[$i]}" --arg rootPath "${raw_paths[$i]}" '{name:$name,rootPath:$rootPath}')")
            fi
        done
        local missing_json
        missing_json=$(printf '%s\n' "${missing_identities[@]}" | jq -s '.')
        local new_json
        new_json=$(jq --argjson missing "$missing_json" '[.[] | . as $project | select(
            ($project.enabled != true) or
            (($missing | map(select(.name == $project.name and .rootPath == $project.rootPath)) | length) == 0)
        )]' "$config_path")
        local kept_count
        kept_count=$(printf '%s\n' "$new_json" | jq 'length')
        if ! cdp_write_json_text "$config_path" "$new_json" "$expected_fingerprint"; then
            for ((i=0; i<total; i++)); do
                [[ "${statuses[$i]}" == "path missing" && "${path_explicit[$i]}" != true ]] && cdp_action_result status-fix "${names[$i]}" failed false write-failed
            done
            return 1
        fi
        echo -e "\n${GREEN}Removed $missing_count projects. $kept_count projects remain.${NC}"
        for ((i=0; i<total; i++)); do
            [[ "${statuses[$i]}" == "path missing" && "${path_explicit[$i]}" != true ]] && cdp_action_result status-fix "${names[$i]}" succeeded true
        done
        return 0
    fi

    # --push: push all repos ahead of remote (skip table render)
    if $do_push; then
        local push_count=0
        for ((i=0; i<total; i++)); do
            if [[ -n "${syncs[$i]}" && "${syncs[$i]}" == *"^"* && -d "${paths[$i]}" ]]; then
                push_count=$((push_count + 1))
            fi
        done
        if [[ $push_count -eq 0 ]]; then
            echo -e "${GREEN}No repos ahead of remote.${NC}"
            return 0
        fi

        echo -e "\n${YELLOW}Repositories ahead of remote:${NC}"
        for ((i=0; i<total; i++)); do
            if [[ -n "${syncs[$i]}" && "${syncs[$i]}" == *"^"* && -d "${paths[$i]}" ]]; then
                local upstream_plan="configured upstream"
                [[ -n "${upstreams[$i]}" ]] && upstream_plan="remote=${remotes[$i]}, upstream=${upstreams[$i]}"
                echo -e "  ${GRAY}${names[$i]}  ${paths[$i]}  $upstream_plan${NC}"
            fi
        done
        if $dry_run; then
            echo -e "\n${GRAY}Dry run: no repositories were pushed.${NC}"
            for ((i=0; i<total; i++)); do
                [[ -n "${syncs[$i]}" && "${syncs[$i]}" == *"^"* && -d "${paths[$i]}" ]] && cdp_action_result status-push "${names[$i]}" preview false
            done
            return 0
        fi
        if ! $assume_yes; then
            echo -e "\n${RED}Action requires explicit confirmation. Re-run with --yes or preview with --dry-run.${NC}"
            for ((i=0; i<total; i++)); do
                [[ -n "${syncs[$i]}" && "${syncs[$i]}" == *"^"* && -d "${paths[$i]}" ]] && cdp_action_result status-push "${names[$i]}" canceled false
            done
            return 1
        fi

        local push_failed=false
        echo -e "\n${YELLOW}Pushing repositories:${NC}"
        for ((i=0; i<total; i++)); do
            if [[ -n "${syncs[$i]}" && "${syncs[$i]}" == *"^"* && -d "${paths[$i]}" ]]; then
                printf "  %s... " "${names[$i]}"
                if git -C "${paths[$i]}" push 2>/dev/null; then
                    echo -e "${GREEN}done${NC}"
                    cdp_action_result status-push "${names[$i]}" succeeded true
                else
                    echo -e "${RED}failed${NC}"
                    cdp_action_result status-push "${names[$i]}" failed false git-push-failed
                    push_failed=true
                fi
            fi
        done
        $push_failed && return 1
        return 0
    fi

    [[ $max_name_len -gt 24 ]] && max_name_len=24
    [[ $max_branch_len -gt 20 ]] && max_branch_len=20

    if $json_mode; then
        local scan_end_epoch duration_ms
        scan_end_epoch=$(date +%s)
        duration_ms=$(((scan_end_epoch - scan_start_epoch) * 1000))
        cdp_status_render_json "$duration_ms"
        return $?
    fi
    if $no_color; then
        cdp_status_render_plain "$dirty_only" "$tag_filter"
        return 0
    fi

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

# shellcheck shell=bash

cdp_status_fail() {
    local json_mode="$1"
    shift
    if $json_mode; then
        printf 'Error: %s\n' "$*" >&2
        return 3
    fi
    printf '%bError: %s%b\n' "$RED" "$*" "$NC" >&2
    return 1
}

cdp_status_reasons_json() {
    local kind="$1" i="$2" reasons=""
    [[ "$kind" == missing ]] && reasons="${reasons}path_missing\n"
    [[ "$kind" == invalid-profile ]] && reasons="${reasons}path_profile_invalid\n"
    [[ "$kind" == timed-out ]] && reasons="${reasons}scan_timeout\n"
    [[ "$kind" == failed ]] && reasons="${reasons}scan_failed\n"
    [[ "${dirty_counts[$i]}" -gt 0 ]] && reasons="${reasons}dirty\n"
    [[ "${untracked_counts[$i]}" -gt 0 ]] && reasons="${reasons}untracked\n"
    [[ "${behind_counts[$i]}" -gt 0 ]] && reasons="${reasons}behind\n"
    printf '%b' "$reasons" | jq -R -s 'split("\n") | map(select(length > 0))'
}

cdp_status_project_json() {
    local i="$1" kind="${record_kinds[$1]}" status_code=clean error_code="" error_message=""
    local path_exists=true git_repo=false branch="${branches[$i]}" reasons
    [[ "$kind" == missing ]] && { path_exists=false; status_code=path_missing; }
    [[ "$kind" == invalid-profile ]] && { path_exists=false; status_code=path_profile_invalid; }
    [[ "$kind" == not-git ]] && status_code=not_git
    [[ "$kind" == timed-out ]] && { status_code=scan_timeout; error_code=scan_timeout; error_message='Git status scan timed out.'; }
    [[ "$kind" == failed ]] && { status_code=scan_failed; error_code=scan_failed; error_message='Git status scan failed.'; }
    if [[ "$kind" == git ]]; then
        git_repo=true
        [[ "${dirty_counts[$i]}" -gt 0 || "${untracked_counts[$i]}" -gt 0 ]] && status_code=changed
    fi
    reasons=$(cdp_status_reasons_json "$kind" "$i")
    jq -n --arg name "${names[$i]}" --arg raw "${raw_paths[$i]}" --arg resolved "${paths[$i]}" \
        --arg status "$status_code" --arg branch "$branch" --arg last "${last_commits[$i]}" \
        --arg errorCode "$error_code" --arg errorMessage "$error_message" \
        --argjson pathExists "$path_exists" --argjson gitRepo "$git_repo" \
        --argjson needsAttention "${needs_attention[$i]}" --argjson reasons "$reasons" \
        --argjson dirty "${dirty_counts[$i]}" --argjson untracked "${untracked_counts[$i]}" \
        --argjson ahead "${ahead_counts[$i]}" --argjson behind "${behind_counts[$i]}" \
        '{name:$name,rawPath:$raw,resolvedPath:$resolved,pathExists:$pathExists,status:$status,
          needsAttention:$needsAttention,attentionReasons:$reasons,
          error:(if $errorCode == "" then null else {code:$errorCode,message:$errorMessage} end),
          git:{isRepository:$gitRepo,branch:(if $branch == "" or $branch == "-" then null else $branch end),
               dirtyCount:$dirty,untrackedCount:$untracked,aheadCount:$ahead,behindCount:$behind,
               lastCommitRelative:(if $last == "" then null else $last end)}}'
}

cdp_status_render_json() {
    local duration_ms="$1"
    local jsonl shown=0 attention=0 failures=0 exit_code=0 i projects generated_at document
    if ! jsonl=$(mktemp "${TMPDIR:-/tmp}/cdp-status-json.XXXXXX"); then
        cdp_status_fail true 'Failed to create status JSON workspace.'; return 3
    fi
    for ((i=0; i<total; i++)); do
        $dirty_only && [[ "${needs_attention[$i]}" != true ]] && continue
        if ! cdp_status_project_json "$i" >> "$jsonl"; then
            rm -f "$jsonl"
            cdp_status_fail true 'Failed to serialize status JSON.'; return 3
        fi
        shown=$((shown + 1))
        [[ "${needs_attention[$i]}" == true ]] && attention=$((attention + 1))
        [[ "${record_kinds[$i]}" == timed-out || "${record_kinds[$i]}" == failed ]] && failures=$((failures + 1))
    done
    [[ $attention -gt 0 ]] && exit_code=1
    [[ $failures -gt 0 ]] && exit_code=2
    if ! projects=$(jq -s '.' "$jsonl"); then
        rm -f "$jsonl"
        cdp_status_fail true 'Failed to serialize status JSON.'; return 3
    fi
    rm -f "$jsonl"
    generated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    if ! document=$(jq -n --arg generatedAt "$generated_at" --arg tag "$tag_filter" \
        --argjson durationMs "$duration_ms" --argjson dirtyOnly "$dirty_only" \
        --argjson refresh "$refresh" --argjson total "$total" --argjson shown "$shown" \
        --argjson attention "$attention" --argjson failures "$failures" \
        --argjson exitCode "$exit_code" --argjson projects "$projects" \
        '{schemaVersion:1,generatedAt:$generatedAt,durationMs:$durationMs,
          filters:{dirtyOnly:$dirtyOnly,tag:(if $tag == "" then null else $tag end),refresh:$refresh},
          summary:{total:$total,shown:$shown,attention:$attention,partialFailures:$failures,exitCode:$exitCode},
          projects:$projects}'); then
        cdp_status_fail true 'Failed to serialize status JSON.'; return 3
    fi
    printf '%s\n' "$document"
    return "$exit_code"
}

cdp_status_render_empty_json() {
    local dirty_only="$1" tag_filter="$2" refresh="$3" generated_at
    generated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    jq -n --arg generatedAt "$generated_at" --arg tag "$tag_filter" \
        --argjson dirtyOnly "$dirty_only" --argjson refresh "$refresh" \
        '{schemaVersion:1,generatedAt:$generatedAt,durationMs:0,
          filters:{dirtyOnly:$dirtyOnly,tag:(if $tag == "" then null else $tag end),refresh:$refresh},
          summary:{total:0,shown:0,attention:0,partialFailures:0,exitCode:0},projects:[]}'
}

cdp_status_render_plain() {
    local dirty_only="$1" tag_filter="$2" shown=0 i idx=1 filter_label=""
    $dirty_only && filter_label=' (dirty only)'
    [[ -n "$tag_filter" ]] && filter_label=" ($tag_filter)"
    for ((i=0; i<total; i++)); do
        $dirty_only && [[ "${needs_attention[$i]}" != true ]] && continue
        shown=$((shown + 1))
    done
    printf '\ncdp project status (%d projects%s)\n' "$shown" "$filter_label"
    printf '%.0s-' {1..110}; printf '\n'
    printf "  %-4s %-${max_name_len}s %-${max_branch_len}s %-24s %-10s %s\n" '#' Project Branch Status Sync 'Last Commit'
    printf '%.0s-' {1..110}; printf '\n'
    for ((i=0; i<total; i++)); do
        $dirty_only && [[ "${needs_attention[$i]}" != true ]] && continue
        local display_name display_branch
        display_name=$(cdp_limit_text "${names[$i]}" "$max_name_len")
        display_branch=$(cdp_limit_text "${branches[$i]}" "$max_branch_len")
        printf "  %02d   %s %s %-24s %-10s %s\n" "$idx" \
            "$(cdp_pad_text "$display_name" "$max_name_len")" \
            "$(cdp_pad_text "$display_branch" "$max_branch_len")" \
            "${statuses[$i]}" "${syncs[$i]}" "${last_commits[$i]}"
        idx=$((idx + 1))
    done
    printf '%.0s-' {1..110}; printf '\n'
    local summary=()
    [[ $attention_count -gt 0 ]] && summary+=("$attention_count repos need attention")
    [[ $missing_count -gt 0 ]] && summary+=("$missing_count path missing")
    if [[ ${#summary[@]} -eq 0 ]]; then printf 'All projects clean.\n'
    else local joined; joined=$(printf ' | %s' "${summary[@]}"); printf '%s\n' "${joined:3}"; fi
}

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
                local project_json
                local planned_path=""
                project_json=$(cdp_project_json_by_name "$config_path" "$proj_name")
                if [[ -n "$project_json" ]] && cdp_resolve_project_json "$project_json"; then
                    planned_path="$CDP_PROJECT_RESOLVED_PATH"
                fi
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
    local existing_json=""
    local existing=""
    existing_json=$(cdp_find_project_by_local_path_json "$config_json" "$project_path" || true)
    [[ -n "$existing_json" ]] && existing=$(printf '%s' "$existing_json" | jq -r '.name')

    if [[ -n "$existing" ]]; then
        echo -e "${YELLOW}Project already exists: $existing${NC}"
        echo -e "${GRAY}Path: $project_path${NC}"
        cdp_action_result add-project "$name" skipped false
        return 0
    fi

    # Add new project
    local new_project
    local new_json
    new_project=$(cdp_new_project_json "$name" "$project_path") || return 1
    new_json=$(jq --argjson project "$new_project" '. += [$project]' <<< "$config_json") || return 1
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
    local unavailable_explicit_count=0
    while IFS= read -r project_json; do
        [[ -z "$project_json" ]] && continue
        local name
        name=$(printf '%s' "$project_json" | jq -r '.name')
        if ! cdp_resolve_project_json "$project_json"; then
            echo -e "${RED}Error: Project '$name' has an invalid $CDP_PROJECT_PATH_SOURCE: $CDP_PROJECT_PATH_ERROR_MESSAGE${NC}"
            return 1
        fi
        if [[ ! -d "$CDP_PROJECT_RESOLVED_PATH" ]]; then
            if [[ "$CDP_PROJECT_PATH_EXPLICIT" == true ]]; then
                unavailable_explicit_count=$((unavailable_explicit_count + 1))
            else
                repaired_json=$(printf '%s\n' "$repaired_json" | jq --arg path "$CDP_PROJECT_RAW_PATH" 'map(if .rootPath == $path then .enabled = false else . end)')
                missing_count=$((missing_count + 1))
            fi
        fi
    done < <(printf '%s\n' "$repaired_json" | jq -c '.[] | select(.enabled == true)')

    if jq -e --argjson repaired "$repaired_json" '. == $repaired' "$config_path" >/dev/null 2>&1; then
        echo -e "${GREEN}No project configuration repairs are needed.${NC}"
        [[ $unavailable_explicit_count -gt 0 ]] && echo -e "${YELLOW}  Kept $unavailable_explicit_count unavailable explicit profile paths unchanged.${NC}"
        cdp_action_result repair-config "$config_path" skipped false
        return 0
    fi

    echo -e "${YELLOW}Repair plan:${NC} $config_path"
    echo -e "${GRAY}  DisabledMissingPaths: $missing_count${NC}"
    echo -e "${GRAY}  UnavailableExplicitPaths: $unavailable_explicit_count (kept unchanged)${NC}"
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
    echo -e "${GRAY}  UnavailableExplicitPaths: $unavailable_explicit_count (kept unchanged)${NC}"
    cdp_action_result repair-config "$config_path" succeeded true
}

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
            matches=""
            while IFS= read -r project_json; do
                if cdp_resolve_project_json "$project_json" && [[ "$CDP_PROJECT_RESOLVED_PATH" == "$PWD" ]]; then
                    matches="${matches}$(printf '%s' "$project_json" | jq -r '.name')"$'\n'
                fi
            done < <(printf '%s\n' "$config_json" | jq -c '.[]')
            matches="${matches%$'\n'}"
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

# cdp shell domain: Completion.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

# Export functions for bash/zsh
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f cdp
    export -f cdp_about
    export -f cdp-ls
    export -f cdp-add
    export -f cdp-rm
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

    local subcommands="status doctor about recent pin unpin alias unalias tag untag clean init scan workspace hook add remove config"
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
        local subcommands=(status doctor about recent pin unpin alias unalias tag untag clean init scan workspace hook add remove config)
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
