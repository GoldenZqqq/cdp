# cdp shell domain: Status.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

CDP_STATUS_CACHE_KEYS=()
CDP_STATUS_CACHE_TIMES=()
CDP_STATUS_CACHE_VALUES=()

cdp_status_setting() {
    local name="$1"
    local default_value="$2"
    local minimum="$3"
    local maximum="$4"
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
    local key="$1"
    local ttl="$2"
    local refresh="$3"
    local now
    local i
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
    local key="$1"
    local value="$2"
    local ttl="$3"
    local now
    local i
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

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dirty|-d) dirty_only=true ;;
            --fix)      do_fix=true ;;
            --push)     do_push=true ;;
            --dry-run)  dry_run=true ;;
            --yes)      assume_yes=true ;;
            --refresh)  refresh=true ;;
            --jobs|--concurrency)
                [[ -z "${2:-}" ]] && { echo -e "${RED}Error: missing value after --jobs.${NC}"; return 1; }
                [[ "$2" =~ ^[0-9]+$ ]] && jobs="$2" || jobs=0
                (( jobs >= 1 && jobs <= 16 )) || { echo -e "${RED}Error: status jobs must be between 1 and 16.${NC}"; return 1; }
                shift
                ;;
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
    local max_name_len=14
    local max_branch_len=12
    local -a names=() raw_paths=() paths=() branches=() remotes=() upstreams=()
    local -a statuses=() status_colors=() syncs=() sync_colors=() last_commits=() needs_attention=()

    while IFS=$'\t' read -r pname ppath; do
        pname="${pname%$'\r'}"
        ppath="${ppath%$'\r'}"
        [[ -z "$pname" ]] && continue
        names+=("$pname")
        raw_paths+=("$ppath")
        paths+=("$(convert_windows_to_wsl "$ppath")")
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
            if cached_record=$(cdp_status_cache_get "${paths[$i]}" "$cache_ttl" "$refresh"); then
                printf '%s\n' "$cached_record" > "$result_dir/$i.record"
            else
                cdp_status_collect_record "${paths[$i]}" "$timeout_seconds" > "$result_dir/$i.record" &
                pids+=("$!")
            fi
        done
        local pid
        for pid in "${pids[@]}"; do wait "$pid" || true; done
        batch_start=$batch_end
    done

    local proj_scanned=0
    local record_kind branch remote upstream dirty_count untracked_count ahead behind last_commit
    for ((i=0; i<total; i++)); do
        local record=""
        [[ -f "$result_dir/$i.record" ]] && record=$(cat "$result_dir/$i.record")
        [[ -n "$record" ]] || record=$'failed\034-\034\034\0340\0340\0340\0340\034'
        cdp_status_cache_set "${paths[$i]}" "$record" "$cache_ttl"
        IFS=$'\034' read -r record_kind branch remote upstream dirty_count untracked_count ahead behind last_commit <<< "$record"
        branches+=("$branch")
        remotes+=("$remote")
        upstreams+=("$upstream")
        last_commits+=("$last_commit")

        local sync_text=""
        local s_color="$GRAY"
        case "$record_kind" in
            missing)
                statuses+=("path missing"); status_colors+=("$RED"); needs_attention+=(true)
                missing_count=$((missing_count + 1))
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
        printf "\r  Scanning %d/%d (%d workers)... " "$proj_scanned" "$total" "$jobs" >&2
    done
    rm -f "$result_dir"/*.record 2>/dev/null || true
    rmdir "$result_dir" 2>/dev/null || true
    printf "\r                                      \r" >&2

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
