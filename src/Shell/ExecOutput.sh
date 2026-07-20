# cdp shell domain: ExecOutput.sh
# shellcheck shell=bash
# Generated runtime fragment; do not source peer fragments.

cdp_exec_json_array() {
    local result='[]' value
    for value in "$@"; do result=$(jq -cn --argjson items "$result" --arg value "$value" '$items + [$value]') || return 1; done
    printf '%s\n' "$result"
}

cdp_exec_selector_json() {
    local value_json
    case "$CDP_EXEC_SELECTOR_KIND" in
        projects) value_json=$(cdp_exec_json_array "${CDP_EXEC_SELECTOR_VALUES[@]}") || return 1 ;;
        tag|workspace) value_json=$(jq -cn --arg value "${CDP_EXEC_SELECTOR_VALUES[0]}" '$value') || return 1 ;;
        all) value_json=null ;;
    esac
    jq -cn --arg kind "$CDP_EXEC_SELECTOR_KIND" --argjson value "$value_json" '{kind:$kind,value:$value}'
}

cdp_exec_unavailable() {
    case "$1" in
        missing_project|ambiguous_project|disabled_project|path_profile_invalid|path_missing) return 0 ;;
        *) return 1 ;;
    esac
}

cdp_exec_exit_code() {
    local item_status
    if $CDP_EXEC_FAIL_FAST; then
        for item_status in "${CDP_EXEC_STATUSES[@]}"; do [[ "$item_status" == canceled ]] && { printf 2; return; }; done
    fi
    for item_status in "${CDP_EXEC_STATUSES[@]}"; do
        if [[ "$item_status" == failed || "$item_status" == timed_out || "$item_status" == canceled ]] || cdp_exec_unavailable "$item_status"; then
            printf 1; return
        fi
    done
    printf 0
}

cdp_exec_result_json() {
    local i="$1" exit_code=null error_value=null
    [[ -n "${CDP_EXEC_EXIT_CODES[$i]}" ]] && exit_code="${CDP_EXEC_EXIT_CODES[$i]}"
    [[ -n "${CDP_EXEC_ERRORS[$i]}" ]] && error_value=$(jq -cn --arg value "${CDP_EXEC_ERRORS[$i]}" '$value')
    jq -n --arg name "${CDP_EXEC_NAMES[$i]}" --arg rawPath "${CDP_EXEC_RAW_PATHS[$i]}" \
        --arg resolvedPath "${CDP_EXEC_PATHS[$i]}" --arg status "${CDP_EXEC_STATUSES[$i]}" \
        --arg stdout "${CDP_EXEC_STDOUT[$i]}" --arg stderr "${CDP_EXEC_STDERR[$i]}" \
        --argjson exitCode "$exit_code" --argjson elapsedMs "${CDP_EXEC_ELAPSED[$i]}" --argjson error "$error_value" \
        '{name:$name,rawPath:$rawPath,resolvedPath:$resolvedPath,status:$status,exitCode:$exitCode,
          elapsedMs:$elapsedMs,stdout:$stdout,stderr:$stderr,error:$error}'
}

cdp_exec_summary_json() {
    local planned=0 succeeded=0 failed=0 timed_out=0 canceled=0 unavailable=0 item_status exit_code
    for item_status in "${CDP_EXEC_STATUSES[@]}"; do
        case "$item_status" in
            planned) planned=$((planned + 1)) ;; succeeded) succeeded=$((succeeded + 1)) ;;
            failed) failed=$((failed + 1)) ;; timed_out) timed_out=$((timed_out + 1)) ;;
            canceled) canceled=$((canceled + 1)) ;;
            *) cdp_exec_unavailable "$item_status" && unavailable=$((unavailable + 1)) ;;
        esac
    done
    exit_code=$(cdp_exec_exit_code)
    jq -cn --argjson total "${#CDP_EXEC_NAMES[@]}" --argjson planned "$planned" --argjson succeeded "$succeeded" \
        --argjson failed "$failed" --argjson timedOut "$timed_out" --argjson canceled "$canceled" \
        --argjson unavailable "$unavailable" --argjson exitCode "$exit_code" \
        '{total:$total,planned:$planned,succeeded:$succeeded,failed:$failed,timedOut:$timedOut,
          canceled:$canceled,unavailable:$unavailable,exitCode:$exitCode}'
}

cdp_exec_document_json() {
    local duration_ms="$1" result_file results selector arguments summary generated_at
    result_file=$(mktemp "${TMPDIR:-/tmp}/cdp-exec-json.XXXXXX") || return 1
    local i
    for ((i=0; i<${#CDP_EXEC_NAMES[@]}; i++)); do
        cdp_exec_result_json "$i" >> "$result_file" || { rm -f "$result_file"; return 1; }
    done
    results=$(jq -s '.' "$result_file") || { rm -f "$result_file"; return 1; }; rm -f "$result_file"
    selector=$(cdp_exec_selector_json) || return 1
    if (( ${#CDP_EXEC_ARGUMENTS[@]} > 0 )); then arguments=$(cdp_exec_json_array "${CDP_EXEC_ARGUMENTS[@]}") || return 1
    else arguments='[]'; fi
    summary=$(cdp_exec_summary_json) || return 1
    generated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    jq -n --arg generatedAt "$generated_at" --arg executable "$CDP_EXEC_COMMAND" \
        --argjson durationMs "$duration_ms" --argjson selector "$selector" --argjson arguments "$arguments" \
        --argjson jobs "$CDP_EXEC_JOBS" --argjson timeoutSeconds "$CDP_EXEC_TIMEOUT" \
        --argjson failFast "$CDP_EXEC_FAIL_FAST" --argjson dryRun "$CDP_EXEC_DRY_RUN" \
        --argjson summary "$summary" --argjson results "$results" \
        '{schemaVersion:1,generatedAt:$generatedAt,durationMs:$durationMs,selector:$selector,
          command:{executable:$executable,arguments:$arguments},
          options:{jobs:$jobs,timeoutSeconds:$timeoutSeconds,failFast:$failFast,dryRun:$dryRun},
          summary:$summary,results:$results}'
}

cdp_exec_print_block() {
    local label="$1" text="$2"
    [[ -n "$text" ]] || return 0
    printf '  %s:\n' "$label"
    while IFS= read -r line; do printf '    %s\n' "$line"; done <<< "$text"
}

cdp_exec_render_human() {
    local i item_status exit_code summary
    printf '\ncdp exec (%d projects)\n' "${#CDP_EXEC_NAMES[@]}"
    printf '%.0s-' {1..88}; printf '\n'
    for ((i=0; i<${#CDP_EXEC_NAMES[@]}; i++)); do
        item_status="${CDP_EXEC_STATUSES[$i]}"
        printf '[%02d] %s  %s\n' "$((i + 1))" "${CDP_EXEC_NAMES[$i]}" "$item_status"
        printf '  raw:      %s\n  resolved: %s\n' "${CDP_EXEC_RAW_PATHS[$i]}" "${CDP_EXEC_PATHS[$i]}"
        if [[ -n "${CDP_EXEC_EXIT_CODES[$i]}" ]]; then printf '  exit: %s  elapsed: %sms\n' "${CDP_EXEC_EXIT_CODES[$i]}" "${CDP_EXEC_ELAPSED[$i]}"
        elif [[ "${CDP_EXEC_ELAPSED[$i]}" -gt 0 ]]; then printf '  elapsed: %sms\n' "${CDP_EXEC_ELAPSED[$i]}"; fi
        cdp_exec_print_block stdout "${CDP_EXEC_STDOUT[$i]}"; cdp_exec_print_block stderr "${CDP_EXEC_STDERR[$i]}"
        [[ -z "${CDP_EXEC_ERRORS[$i]}" ]] || printf '  error: %s\n' "${CDP_EXEC_ERRORS[$i]}"
    done
    printf '%.0s-' {1..88}; printf '\n'
    summary=$(cdp_exec_summary_json) || return 3
    jq -r '"succeeded=\(.succeeded) failed=\(.failed) timed_out=\(.timedOut) canceled=\(.canceled) unavailable=\(.unavailable)"' <<< "$summary"
    exit_code=$(jq -r '.exitCode' <<< "$summary"); return "$exit_code"
}

cdp_exec_render() {
    local duration_ms="$1" document exit_code
    if $CDP_EXEC_JSON; then
        document=$(cdp_exec_document_json "$duration_ms") || { cdp_exec_fail 'failed to serialize exec JSON.'; return 3; }
        printf '%s\n' "$document"
        exit_code=$(jq -r '.summary.exitCode' <<< "$document"); return "$exit_code"
    fi
    cdp_exec_render_human
}
