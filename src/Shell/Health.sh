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
