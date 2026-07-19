# cdp shell domain: Status.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

cdp-status() {
    local config_path=""
    local dirty_only=false
    local tag_filter=""
    local do_fix=false
    local do_push=false
    local dry_run=false
    local assume_yes=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dirty|-d) dirty_only=true ;;
            --fix)      do_fix=true ;;
            --push)     do_push=true ;;
            --dry-run)  dry_run=true ;;
            --yes)      assume_yes=true ;;
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
    if $dry_run && $assume_yes; then
        echo -e "${RED}Error: --dry-run and --yes cannot be used together.${NC}"
        return 1
    fi
    if { $dry_run || $assume_yes; } && ! { $do_fix || $do_push; }; then
        echo -e "${RED}Error: --dry-run and --yes require --fix or --push.${NC}"
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
    local -a names=() raw_paths=() paths=() branches=() remotes=() upstreams=() statuses=() status_colors=() syncs=() sync_colors=() last_commits=() needs_attention=()
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
            remotes+=("")
            upstreams+=("")
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
            remotes+=("")
            upstreams+=("")
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
        local upstream=""
        local remote=""
        upstream=$(git -C "$ppath" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
        [[ "$upstream" == */* ]] && remote="${upstream%%/*}"
        remotes+=("$remote")
        upstreams+=("$upstream")
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
        if $dry_run; then
            echo -e "\n${GRAY}Dry run: no project entries were removed.${NC}"
            for ((i=0; i<total; i++)); do
                [[ "${statuses[$i]}" == "path missing" ]] && cdp_action_result status-fix "${names[$i]}" preview false
            done
            return 0
        fi
        if ! $assume_yes; then
            echo -e "\n${RED}Action requires explicit confirmation. Re-run with --yes or preview with --dry-run.${NC}"
            for ((i=0; i<total; i++)); do
                [[ "${statuses[$i]}" == "path missing" ]] && cdp_action_result status-fix "${names[$i]}" canceled false
            done
            return 1
        fi
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
        if ! cdp_write_json_text "$config_path" "$new_json" "$expected_fingerprint"; then
            for ((i=0; i<total; i++)); do
                [[ "${statuses[$i]}" == "path missing" ]] && cdp_action_result status-fix "${names[$i]}" failed false write-failed
            done
            return 1
        fi
        echo -e "\n${GREEN}Removed $missing_count projects. $kept_count projects remain.${NC}"
        for ((i=0; i<total; i++)); do
            [[ "${statuses[$i]}" == "path missing" ]] && cdp_action_result status-fix "${names[$i]}" succeeded true
        done
        return
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
