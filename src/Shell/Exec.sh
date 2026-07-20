# cdp shell domain: Exec.sh
# shellcheck shell=bash
# Generated runtime fragment; do not source peer fragments.

CDP_EXEC_RESULT_DIR=""

cdp_exec_now_ms() {
    local value
    value=$(date +%s%3N 2>/dev/null || true)
    if [[ "$value" =~ ^[0-9]+$ && ${#value} -ge 13 ]]; then printf '%s\n' "$value"
    else value=$(date +%s); printf '%s000\n' "$value"; fi
}

cdp_exec_write_worker_failure() {
    local index="$1" message="$2" elapsed="${3:-0}"
    printf failed > "$CDP_EXEC_RESULT_DIR/$index.status"
    printf '%s' "$message" > "$CDP_EXEC_RESULT_DIR/$index.error"
    printf '%s' "$elapsed" > "$CDP_EXEC_RESULT_DIR/$index.elapsed"
    : > "$CDP_EXEC_RESULT_DIR/$index.exit"
}

cdp_exec_worker() {
    local index="$1" start end elapsed child_pid exit_code=0 deadline now timed_out=false
    start=$(cdp_exec_now_ms)
    if ! cd -- "${CDP_EXEC_PATHS[$index]}"; then
        cdp_exec_write_worker_failure "$index" 'Failed to enter resolved project path.'
        return 0
    fi
    if (( ${#CDP_EXEC_ARGUMENTS[@]} > 0 )); then
        "$CDP_EXEC_EXECUTABLE" "${CDP_EXEC_ARGUMENTS[@]}" </dev/null \
            > "$CDP_EXEC_RESULT_DIR/$index.stdout" 2> "$CDP_EXEC_RESULT_DIR/$index.stderr" &
    else
        "$CDP_EXEC_EXECUTABLE" </dev/null > "$CDP_EXEC_RESULT_DIR/$index.stdout" \
            2> "$CDP_EXEC_RESULT_DIR/$index.stderr" &
    fi
    child_pid=$!
    deadline=$((start + (CDP_EXEC_TIMEOUT * 1000)))
    while kill -0 "$child_pid" 2>/dev/null; do
        now=$(cdp_exec_now_ms)
        if (( now >= deadline )); then
            timed_out=true; kill -TERM "$child_pid" 2>/dev/null || true
            sleep 0.1; kill -KILL "$child_pid" 2>/dev/null || true
            break
        fi
        sleep 0.1
    done
    if wait "$child_pid" 2>/dev/null; then exit_code=0; else exit_code=$?; fi
    end=$(cdp_exec_now_ms); elapsed=$((end - start)); (( elapsed < 0 )) && elapsed=0
    printf '%s' "$elapsed" > "$CDP_EXEC_RESULT_DIR/$index.elapsed"
    if $timed_out; then
        printf timed_out > "$CDP_EXEC_RESULT_DIR/$index.status"; : > "$CDP_EXEC_RESULT_DIR/$index.exit"
        printf 'Command timed out.' > "$CDP_EXEC_RESULT_DIR/$index.error"
    elif [[ "$exit_code" -eq 0 ]]; then
        printf succeeded > "$CDP_EXEC_RESULT_DIR/$index.status"; printf 0 > "$CDP_EXEC_RESULT_DIR/$index.exit"; : > "$CDP_EXEC_RESULT_DIR/$index.error"
    else
        printf failed > "$CDP_EXEC_RESULT_DIR/$index.status"; printf '%s' "$exit_code" > "$CDP_EXEC_RESULT_DIR/$index.exit"
        printf 'Command exited with code %s.' "$exit_code" > "$CDP_EXEC_RESULT_DIR/$index.error"
    fi
}

cdp_exec_load_worker_result() {
    local index="$1"
    CDP_EXEC_STATUSES[$index]=$(cat "$CDP_EXEC_RESULT_DIR/$index.status" 2>/dev/null || printf failed)
    CDP_EXEC_EXIT_CODES[$index]=$(cat "$CDP_EXEC_RESULT_DIR/$index.exit" 2>/dev/null || true)
    CDP_EXEC_ELAPSED[$index]=$(cat "$CDP_EXEC_RESULT_DIR/$index.elapsed" 2>/dev/null || printf 0)
    CDP_EXEC_STDOUT[$index]=$(cat "$CDP_EXEC_RESULT_DIR/$index.stdout" 2>/dev/null || true)
    CDP_EXEC_STDERR[$index]=$(cat "$CDP_EXEC_RESULT_DIR/$index.stderr" 2>/dev/null || true)
    CDP_EXEC_ERRORS[$index]=$(cat "$CDP_EXEC_RESULT_DIR/$index.error" 2>/dev/null || true)
}

cdp_exec_preflight_fail_fast() {
    local failure_seen=false i
    for ((i=0; i<${#CDP_EXEC_STATUSES[@]}; i++)); do
        if $failure_seen && [[ "${CDP_EXEC_STATUSES[$i]}" == planned ]]; then
            CDP_EXEC_STATUSES[$i]=canceled; CDP_EXEC_ERRORS[$i]='Canceled by fail-fast before execution.'
        elif [[ "${CDP_EXEC_STATUSES[$i]}" != planned ]]; then failure_seen=true; fi
    done
}

cdp_exec_cancel_future() {
    local i
    for ((i=0; i<${#CDP_EXEC_STATUSES[@]}; i++)); do
        if [[ "${CDP_EXEC_STATUSES[$i]}" == planned ]]; then
            CDP_EXEC_STATUSES[$i]=canceled; CDP_EXEC_ERRORS[$i]='Canceled by fail-fast after an earlier failure.'
        fi
    done
}

cdp_exec_batch_failed() {
    local index
    for index in "$@"; do
        [[ "${CDP_EXEC_STATUSES[$index]}" == failed || "${CDP_EXEC_STATUSES[$index]}" == timed_out ]] && return 0
    done
    return 1
}

cdp_exec_run_batches() {
    local runnable=() batch=() pids=() i offset end index pid
    $CDP_EXEC_FAIL_FAST && cdp_exec_preflight_fail_fast
    for ((i=0; i<${#CDP_EXEC_STATUSES[@]}; i++)); do [[ "${CDP_EXEC_STATUSES[$i]}" == planned ]] && runnable+=("$i"); done
    [[ ${#runnable[@]} -gt 0 ]] || return 0
    CDP_EXEC_RESULT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/cdp-exec.XXXXXX") || { cdp_exec_fail 'failed to create exec workspace.'; return 3; }
    for ((offset=0; offset<${#runnable[@]}; offset+=CDP_EXEC_JOBS)); do
        end=$((offset + CDP_EXEC_JOBS)); (( end > ${#runnable[@]} )) && end=${#runnable[@]}
        batch=(); pids=()
        for ((i=offset; i<end; i++)); do
            index="${runnable[$i]}"; batch+=("$index"); cdp_exec_worker "$index" 2>/dev/null & pids+=("$!")
        done
        for pid in "${pids[@]}"; do wait "$pid" || true; done
        for index in "${batch[@]}"; do cdp_exec_load_worker_result "$index"; done
        if $CDP_EXEC_FAIL_FAST && cdp_exec_batch_failed "${batch[@]}"; then cdp_exec_cancel_future; break; fi
    done
}

cdp_exec_cleanup() {
    if [[ -n "$CDP_EXEC_RESULT_DIR" && -d "$CDP_EXEC_RESULT_DIR" ]]; then rm -rf -- "$CDP_EXEC_RESULT_DIR"; fi
    CDP_EXEC_RESULT_DIR=""
}

cdp-exec() {
    local started finished duration result=0
    started=$(cdp_exec_now_ms)
    cdp_exec_parse "$@" || return 3
    cdp_exec_build_plan || return 3
    if ! $CDP_EXEC_DRY_RUN && ! $CDP_EXEC_YES; then
        cdp_exec_fail 'exec requires --yes or --dry-run.'; return 3
    fi
    if ! $CDP_EXEC_DRY_RUN; then
        if cdp_exec_run_batches; then :; else result=$?; cdp_exec_cleanup; return "$result"; fi
    fi
    finished=$(cdp_exec_now_ms); duration=$((finished - started)); (( duration < 0 )) && duration=0
    if cdp_exec_render "$duration"; then result=0; else result=$?; fi
    cdp_exec_cleanup
    return "$result"
}
