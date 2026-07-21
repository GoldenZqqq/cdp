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
    [[ "${freshness[$i]:-}" == fetch-failed ]] && reasons="${reasons}fetch_failed\n"
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
    [[ "${freshness[$i]:-}" == fetch-failed ]] && { error_code=fetch_failed; error_message="${fetch_messages[$i]:-fetch failed}"; }
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
        --arg upstream "${upstreams[$i]:-}" --arg remoteName "${remote_names[$i]:-}" \
        --arg remoteRef "${remote_refs[$i]:-}" --arg remoteUrl "${remote_urls[$i]:-}" \
        --arg headOid "${head_oids[$i]:-}" --arg freshness "${freshness[$i]:-not-applicable}" \
        '{name:$name,rawPath:$raw,resolvedPath:$resolved,pathExists:$pathExists,status:$status,
          needsAttention:$needsAttention,attentionReasons:$reasons,
          error:(if $errorCode == "" then null else {code:$errorCode,message:$errorMessage} end),
          git:{isRepository:$gitRepo,branch:(if $branch == "" or $branch == "-" then null else $branch end),
               dirtyCount:$dirty,untrackedCount:$untracked,aheadCount:$ahead,behindCount:$behind,
               lastCommitRelative:(if $last == "" then null else $last end),
               upstream:$upstream,remoteName:$remoteName,remoteRef:$remoteRef,remoteUrl:$remoteUrl,
               headOid:$headOid,freshness:$freshness}}'
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
        --argjson fetch "${do_fetch:-false}" \
        '{schemaVersion:1,generatedAt:$generatedAt,durationMs:$durationMs,
          filters:{dirtyOnly:$dirtyOnly,tag:(if $tag == "" then null else $tag end),refresh:$refresh,fetch:$fetch},
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
        --argjson fetch "${do_fetch:-false}" \
        '{schemaVersion:1,generatedAt:$generatedAt,durationMs:0,
          filters:{dirtyOnly:$dirtyOnly,tag:(if $tag == "" then null else $tag end),refresh:$refresh,fetch:$fetch},
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
    printf "  %-4s %-${max_name_len}s %-${max_branch_len}s %-24s %-10s %-15s %s\n" '#' Project Branch Status Sync Source 'Last Commit'
    printf '%.0s-' {1..110}; printf '\n'
    for ((i=0; i<total; i++)); do
        $dirty_only && [[ "${needs_attention[$i]}" != true ]] && continue
        local display_name display_branch
        display_name=$(cdp_limit_text "${names[$i]}" "$max_name_len")
        display_branch=$(cdp_limit_text "${branches[$i]}" "$max_branch_len")
        printf "  %02d   %s %s %-24s %-10s %-15s %s\n" "$idx" \
            "$(cdp_pad_text "$display_name" "$max_name_len")" \
            "$(cdp_pad_text "$display_branch" "$max_branch_len")" \
            "${statuses[$i]}" "${syncs[$i]}" "${freshness[$i]}" "${last_commits[$i]}"
        idx=$((idx + 1))
    done
    printf '%.0s-' {1..110}; printf '\n'
    local summary=()
    [[ $attention_count -gt 0 ]] && summary+=("$attention_count repos need attention")
    [[ $missing_count -gt 0 ]] && summary+=("$missing_count path missing")
    if [[ ${#summary[@]} -eq 0 ]]; then printf 'All projects clean.\n'
    else local joined; joined=$(printf ' | %s' "${summary[@]}"); printf '%s\n' "${joined:3}"; fi
}
