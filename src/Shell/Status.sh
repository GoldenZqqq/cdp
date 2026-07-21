# cdp shell domain: Status.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

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
        printf 'missing\034-\034\034\0340\0340\0340\0340\034\034\n'
        return 0
    fi
    if porcelain=$(cdp_status_git_command "$timeout_seconds" -C "$repository_path" status --porcelain=v2 --branch --untracked-files=all 2>/dev/null); then
        exit_code=0
    else
        exit_code=$?
    fi
    if [[ $exit_code -ne 0 ]]; then
        if [[ $exit_code -eq 124 ]]; then
            printf 'timed-out\034-\034\034\0340\0340\0340\0340\034\034\n'
        else
            printf 'not-git\034-\034\034\0340\0340\0340\0340\034\034\n'
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
    printf 'git\034%s\034%s\034%s\034%s\034%s\034%s\034%s\034%s\034%s\n' \
        "$branch" "$remote" "$upstream" "$dirty" "$untracked" "$ahead" "$behind" "$last_commit" "$oid"
}

cdp-status() {
    local config_path=""
    local dirty_only=false
    local tag_filter=""
    local do_fix=false
    local do_push=false
    local do_fetch=false
    local fetch_jobs=4
    local fetch_timeout=15
    local fetch_tuning=false
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
            --fetch)    do_fetch=true ;;
            --fetch-jobs)
                [[ -z "${2:-}" ]] && { cdp_status_fail "$json_mode" 'missing value after --fetch-jobs.'; return $?; }
                cdp_status_valid_integer "$2" 1 16 || { cdp_status_fail "$json_mode" '--fetch-jobs must be between 1 and 16.'; return $?; }
                fetch_jobs="$2"; fetch_tuning=true; shift
                ;;
            --fetch-timeout)
                [[ -z "${2:-}" ]] && { cdp_status_fail "$json_mode" 'missing value after --fetch-timeout.'; return $?; }
                cdp_status_valid_integer "$2" 1 300 || { cdp_status_fail "$json_mode" '--fetch-timeout must be between 1 and 300.'; return $?; }
                fetch_timeout="$2"; fetch_tuning=true; shift
                ;;
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
    if $do_fetch && $do_fix; then cdp_status_fail "$json_mode" '--fetch and --fix cannot be used together.'; return $?; fi
    if $fetch_tuning && ! $do_fetch; then cdp_status_fail "$json_mode" 'fetch tuning options require --fetch.'; return $?; fi
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
    local -a freshness=() fetch_messages=() remote_urls=() remote_names=() remote_refs=() head_oids=()

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
    if $do_fix || $do_push || $do_fetch; then refresh=true; fi
    if $do_fetch; then
        local fetch_projects="" i
        for ((i=0; i<total; i++)); do fetch_projects+="${names[$i]}"$'\t'"${paths[$i]}"$'\n'; done
        fetch_projects="${fetch_projects%$'\n'}"
        cdp_status_prepare_fetches "$fetch_projects" "$fetch_jobs" "$fetch_timeout" || {
            cdp_status_fail "$json_mode" 'status fetch cancelled.'; return $?;
        }
    fi
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
                printf 'invalid-profile\034-\034\034\0340\0340\0340\0340\034\034\n' > "$result_dir/$i.record"
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
    local record_kind branch remote upstream dirty_count untracked_count ahead behind last_commit head_oid
    for ((i=0; i<total; i++)); do
        local record=""
        [[ -f "$result_dir/$i.record" ]] && record=$(cat "$result_dir/$i.record")
        [[ -n "$record" ]] || record=$'failed\034-\034\034\0340\0340\0340\0340\034\034'
        [[ -n "${paths[$i]}" ]] && cdp_status_cache_set "${path_profiles[$i]}:${paths[$i]}" "$record" "$cache_ttl"
        IFS=$'\034' read -r record_kind branch remote upstream dirty_count untracked_count ahead behind last_commit head_oid <<< "$record"
        record_kinds+=("$record_kind")
        branches+=("$branch")
        remotes+=("$remote")
        upstreams+=("$upstream")
        last_commits+=("$last_commit")
        dirty_counts+=("$dirty_count")
        untracked_counts+=("$untracked_count")
        ahead_counts+=("$ahead")
        behind_counts+=("$behind")
        cdp_status_append_remote_state "$i" "$record_kind" "$remote" "$upstream" "$head_oid" "$do_fetch" "$do_push"

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
                if [[ "${freshness[$i]}" == fetch-failed ]]; then
                    attention_count=$((attention_count + 1)); needs_attention[${#needs_attention[@]}-1]=true
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
    local fetch_failed_count=0
    for ((i=0; i<total; i++)); do [[ "${freshness[$i]}" == fetch-failed ]] && fetch_failed_count=$((fetch_failed_count + 1)); done
    unset CDP_STATUS_FETCH_STATES CDP_STATUS_FETCH_MESSAGES CDP_STATUS_FETCH_BATCH_PIDS
    unset CDP_STATUS_FETCH_BATCH_INDICES CDP_STATUS_FETCH_BATCH_FILES CDP_STATUS_FETCH_CANCELLED

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
            if cdp_status_push_eligible "$i"; then
                push_count=$((push_count + 1))
            fi
        done
        if [[ $push_count -eq 0 ]]; then
            echo -e "${GREEN}No eligible repos ahead of their upstream.${NC}"
            [[ $fetch_failed_count -gt 0 ]] && return 1
            return 0
        fi

        echo -e "\n${YELLOW}Repositories ahead of remote:${NC}"
        for ((i=0; i<total; i++)); do
            if cdp_status_push_eligible "$i"; then
                echo -e "  ${GRAY}${names[$i]} -> ${upstreams[$i]}  ${remote_urls[$i]}  ${head_oids[$i]}:${remote_refs[$i]}${NC}"
            fi
        done
        if $dry_run; then
            echo -e "\n${GRAY}Dry run: no repositories were pushed.${NC}"
            for ((i=0; i<total; i++)); do
                cdp_status_push_eligible "$i" && cdp_action_result status-push "${names[$i]}" preview false
            done
            return 0
        fi
        if ! $assume_yes; then
            echo -e "\n${RED}Action requires explicit confirmation. Re-run with --yes or preview with --dry-run.${NC}"
            for ((i=0; i<total; i++)); do
                cdp_status_push_eligible "$i" && cdp_action_result status-push "${names[$i]}" canceled false
            done
            return 1
        fi

        local push_failed=false
        echo -e "\n${YELLOW}Pushing repositories:${NC}"
        for ((i=0; i<total; i++)); do
            if cdp_status_push_eligible "$i"; then
                printf "  %s... " "${names[$i]}"
                if cdp_status_push_snapshot "${paths[$i]}" "${remote_names[$i]}" "${head_oids[$i]}" "${remote_refs[$i]}" >/dev/null 2>&1; then
                    echo -e "${GREEN}done${NC}"
                    cdp_action_result status-push "${names[$i]}" succeeded true
                else
                    echo -e "${RED}failed${NC}"
                    cdp_action_result status-push "${names[$i]}" failed false git-push-failed
                    push_failed=true
                fi
            fi
        done
        [[ $fetch_failed_count -gt 0 ]] && push_failed=true
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
    printf "  %-4s %-${max_name_len}s %-${max_branch_len}s %-24s %-10s %-15s %s\n" "#" "Project" "Branch" "Status" "Sync" "Source" "Last Commit"
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

        local source_color="$GRAY"
        [[ "${freshness[$i]}" == refreshed ]] && source_color="$GREEN"
        [[ "${freshness[$i]}" == fetch-failed ]] && source_color="$RED"
        printf "  ${GRAY}%-4s${NC} ${GREEN}%s${NC} ${BOLD_CYAN}%s${NC} ${status_colors[$i]}%-24s${NC} ${sync_colors[$i]}%-10s${NC} ${source_color}%-15s${NC} ${GRAY}%s${NC}\n" \
            "$num" "$(cdp_pad_text "$display_name" "$max_name_len")" "$(cdp_pad_text "$display_branch" "$max_branch_len")" "${statuses[$i]}" "${syncs[$i]}" "${freshness[$i]}" "${last_commits[$i]}"

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
    if [[ $fetch_failed_count -gt 0 ]]; then
        for ((i=0; i<total; i++)); do
            [[ "${freshness[$i]}" == fetch-failed ]] && echo -e "${RED}  Fetch failed: ${names[$i]} (${fetch_messages[$i]})${NC}"
        done
    fi
    [[ $fetch_failed_count -gt 0 ]] && return 1
    return 0
}
