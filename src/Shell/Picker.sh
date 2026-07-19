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
