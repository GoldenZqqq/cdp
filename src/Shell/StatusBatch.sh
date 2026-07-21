# cdp shell domain: StatusBatch.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

CDP_STATUS_CACHE_KEYS=()
CDP_STATUS_CACHE_TIMES=()
CDP_STATUS_CACHE_VALUES=()

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

cdp_status_valid_integer() {
    local value="$1" minimum="$2" maximum="$3"
    [[ "$value" =~ ^[0-9]+$ ]] && (( value >= minimum && value <= maximum ))
}

cdp_status_redact_remote_url() {
    local remote_url="$1"
    case "$remote_url" in
        http://*|https://*)
            printf '%s\n' "$remote_url" | sed -E \
                -e 's#^(https?://)[^/@]+@#\1***@#' -e 's#[?#].*$##'
            ;;
        *) printf '%s\n' "$remote_url" ;;
    esac
}

cdp_status_kill_tree() {
    local process_id="$1" child_id children=""
    children=$(ps -eo pid=,ppid= 2>/dev/null | awk -v parent="$process_id" '$2 == parent { print $1 }')
    for child_id in $children; do cdp_status_kill_tree "$child_id"; done
    if [[ "$(uname -s 2>/dev/null || true)" == MINGW* ]] && command -v taskkill.exe >/dev/null 2>&1; then
        local windows_pid=""
        windows_pid=$(ps -W 2>/dev/null | awk -v target="$process_id" '$1 == target { print $4; exit }')
        if [[ "$windows_pid" =~ ^[0-9]+$ ]]; then
            MSYS2_ARG_CONV_EXCL='*' taskkill.exe /PID "$windows_pid" /T /F >/dev/null 2>&1 || true
            return 0
        fi
    fi
    kill -TERM "$process_id" 2>/dev/null || true
    sleep 0.05
    kill -KILL "$process_id" 2>/dev/null || true
}

cdp_status_track_process_tree() {
    local process_id="$1" tracked_id child_id children="" found=false
    for tracked_id in "${CDP_STATUS_TRACKED_PIDS[@]:-}"; do
        [[ "$tracked_id" == "$process_id" ]] && found=true
    done
    $found || CDP_STATUS_TRACKED_PIDS+=("$process_id")
    children=$(ps -eo pid=,ppid= 2>/dev/null | awk -v parent="$process_id" '$2 == parent { print $1 }')
    for child_id in $children; do cdp_status_track_process_tree "$child_id"; done
}

cdp_status_stop_tracked_processes() {
    local tracked_position
    for ((tracked_position=${#CDP_STATUS_TRACKED_PIDS[@]}-1; tracked_position>=0; tracked_position--)); do
        cdp_status_kill_tree "${CDP_STATUS_TRACKED_PIDS[$tracked_position]}"
    done
}

cdp_status_stop_fetch_processes() {
    if [[ -n "${CDP_STATUS_FETCH_GROUP_PID:-}" ]]; then
        kill -TERM -- "-$CDP_STATUS_FETCH_GROUP_PID" 2>/dev/null || true
        sleep 0.1
        kill -KILL -- "-$CDP_STATUS_FETCH_GROUP_PID" 2>/dev/null || true
        return
    fi
    cdp_status_stop_tracked_processes
}

cdp_status_fetch_worker() {
    local project_path="$1" timeout_seconds="$2" result_file="$3"
    local fetch_pid deadline=$((SECONDS + timeout_seconds))
    CDP_STATUS_TRACKED_PIDS=(); CDP_STATUS_FETCH_GROUP_PID=''
    if command -v setsid >/dev/null 2>&1; then
        GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never SSH_ASKPASS_REQUIRE=never \
            setsid git -C "$project_path" fetch --quiet --prune --no-tags --no-recurse-submodules \
            >/dev/null 2>&1 &
        CDP_STATUS_FETCH_GROUP_PID=$!
    else
        GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never SSH_ASKPASS_REQUIRE=never \
            git -C "$project_path" fetch --quiet --prune --no-tags --no-recurse-submodules \
            >/dev/null 2>&1 &
    fi
    fetch_pid=$!
    cdp_status_track_process_tree "$fetch_pid"
    trap 'cdp_status_stop_fetch_processes; exit 130' INT TERM
    while kill -0 "$fetch_pid" 2>/dev/null; do
        cdp_status_track_process_tree "$fetch_pid"
        if (( SECONDS >= deadline )); then
            cdp_status_stop_fetch_processes
            wait "$fetch_pid" 2>/dev/null || true
            printf 'fetch-failed\ttimeout after %s seconds\n' "$timeout_seconds" > "$result_file"
            trap - INT TERM
            return 0
        fi
        sleep 0.1
    done
    if wait "$fetch_pid" 2>/dev/null; then
        printf 'refreshed\tfetch completed\n' > "$result_file"
    else
        local fetch_exit=$?
        printf 'fetch-failed\tfetch failed (exit %s)\n' "$fetch_exit" > "$result_file"
    fi
    trap - INT TERM
}

cdp_status_cancel_fetch_batch() {
    local worker_pid
    for worker_pid in "${CDP_STATUS_FETCH_BATCH_PIDS[@]:-}"; do
        [[ -n "$worker_pid" ]] && cdp_status_kill_tree "$worker_pid"
    done
}

cdp_status_collect_fetch_batch() {
    local position worker_pid project_index result_file fetch_state fetch_message
    for ((position=0; position<${#CDP_STATUS_FETCH_BATCH_PIDS[@]}; position++)); do
        worker_pid="${CDP_STATUS_FETCH_BATCH_PIDS[$position]}"
        project_index="${CDP_STATUS_FETCH_BATCH_INDICES[$position]}"
        result_file="${CDP_STATUS_FETCH_BATCH_FILES[$position]}"
        wait "$worker_pid" 2>/dev/null || true
        if [[ -f "$result_file" ]]; then
            IFS=$'\t' read -r fetch_state fetch_message < "$result_file"
            CDP_STATUS_FETCH_STATES[$project_index]="$fetch_state"
            CDP_STATUS_FETCH_MESSAGES[$project_index]="$fetch_message"
        else
            CDP_STATUS_FETCH_STATES[$project_index]='fetch-failed'
            CDP_STATUS_FETCH_MESSAGES[$project_index]='fetch cancelled'
        fi
    done
    CDP_STATUS_FETCH_BATCH_PIDS=(); CDP_STATUS_FETCH_BATCH_INDICES=(); CDP_STATUS_FETCH_BATCH_FILES=()
}

cdp_status_start_fetch() {
    local project_path="$1" timeout_seconds="$2" result_dir="$3" project_index="$4"
    local result_file="$result_dir/$project_index.result"
    CDP_STATUS_FETCH_STATES[$project_index]='pending'
    cdp_status_fetch_worker "$project_path" "$timeout_seconds" "$result_file" &
    CDP_STATUS_FETCH_BATCH_PIDS+=("$!")
    CDP_STATUS_FETCH_BATCH_INDICES+=("$project_index")
    CDP_STATUS_FETCH_BATCH_FILES+=("$result_file")
}

cdp_status_prepare_fetches() {
    local projects="$1" jobs="$2" timeout_seconds="$3"
    local result_dir project_index=0 pname project_path current_branch remote_name remote_ref
    local old_int old_term
    result_dir=$(mktemp -d "${TMPDIR:-/tmp}/cdp-status-fetch.XXXXXX") || return 1
    CDP_STATUS_FETCH_STATES=(); CDP_STATUS_FETCH_MESSAGES=()
    CDP_STATUS_FETCH_BATCH_PIDS=(); CDP_STATUS_FETCH_BATCH_INDICES=(); CDP_STATUS_FETCH_BATCH_FILES=()
    CDP_STATUS_FETCH_CANCELLED=0
    old_int=$(trap -p INT 2>/dev/null || true); old_term=$(trap -p TERM 2>/dev/null || true)
    trap 'CDP_STATUS_FETCH_CANCELLED=1; cdp_status_cancel_fetch_batch' INT TERM
    while IFS=$'\t' read -r pname project_path <&3; do
        [[ $CDP_STATUS_FETCH_CANCELLED -ne 0 ]] && break
        project_path="${project_path%$'\r'}"
        CDP_STATUS_FETCH_STATES[$project_index]='not-applicable'; CDP_STATUS_FETCH_MESSAGES[$project_index]=''
        if [[ -d "$project_path" ]] && [[ "$(git -C "$project_path" rev-parse --is-inside-work-tree 2>/dev/null || true)" == true ]]; then
            current_branch=$(git -C "$project_path" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
            remote_name=$(git -C "$project_path" config --get "branch.$current_branch.remote" 2>/dev/null || true)
            remote_ref=$(git -C "$project_path" config --get "branch.$current_branch.merge" 2>/dev/null || true)
            if [[ -n "$current_branch" && -n "$remote_name" && -n "$remote_ref" && "$remote_name" != '.' ]]; then
                cdp_status_start_fetch "$project_path" "$timeout_seconds" "$result_dir" "$project_index"
                if [[ $CDP_STATUS_FETCH_CANCELLED -ne 0 ]]; then cdp_status_cancel_fetch_batch; break; fi
                (( ${#CDP_STATUS_FETCH_BATCH_PIDS[@]} >= jobs )) && cdp_status_collect_fetch_batch
            elif [[ -n "$current_branch" && -n "$remote_name" && -n "$remote_ref" ]]; then
                CDP_STATUS_FETCH_STATES[$project_index]='cached'
            else
                CDP_STATUS_FETCH_STATES[$project_index]='no-upstream'
            fi
        fi
        project_index=$((project_index + 1))
    done 3<<< "$projects"
    cdp_status_collect_fetch_batch
    rm -rf -- "$result_dir"
    [[ -n "$old_int" ]] && eval "$old_int" || trap - INT
    [[ -n "$old_term" ]] && eval "$old_term" || trap - TERM
    [[ $CDP_STATUS_FETCH_CANCELLED -eq 0 ]]
}

cdp_status_push_snapshot() {
    local project_path="$1" remote_name="$2" head_oid="$3" remote_ref="$4"
    git -C "$project_path" push --porcelain "$remote_name" "$head_oid:$remote_ref"
}

cdp_status_append_remote_state() {
    local index="$1" kind="$2" remote="$3" upstream="$4" head_oid="$5"
    local do_fetch="$6" do_push="$7" remote_name="$remote" remote_ref="" remote_url=""
    local current_branch="" source=not-applicable
    if [[ "$kind" == git ]]; then
        [[ "$upstream" == */* ]] && remote_ref="refs/heads/${upstream#*/}"
        if $do_fetch || $do_push; then
            current_branch=$(git -C "${paths[$index]}" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
            remote_name=$(git -C "${paths[$index]}" config --get "branch.$current_branch.remote" 2>/dev/null || true)
            remote_ref=$(git -C "${paths[$index]}" config --get "branch.$current_branch.merge" 2>/dev/null || true)
            head_oid=$(git -C "${paths[$index]}" rev-parse HEAD 2>/dev/null || true)
            if [[ -n "$remote_name" && "$remote_name" != '.' ]]; then
                remote_url=$(git -C "${paths[$index]}" remote get-url "$remote_name" 2>/dev/null || true)
                remote_url=$(cdp_status_redact_remote_url "${remote_url%$'\r'}")
            fi
        fi
        if $do_fetch; then source="${CDP_STATUS_FETCH_STATES[$index]:-not-applicable}"
        elif [[ -n "$upstream" ]]; then source=cached
        else source=no-upstream
        fi
    fi
    remote_names+=("$remote_name"); remote_refs+=("$remote_ref"); remote_urls+=("$remote_url")
    head_oids+=("$head_oid"); freshness+=("$source")
    fetch_messages+=("${CDP_STATUS_FETCH_MESSAGES[$index]:-}")
}

cdp_status_push_eligible() {
    local index="$1"
    (( ahead_counts[index] > 0 )) && [[ "${freshness[$index]}" != fetch-failed ]] &&
        [[ -n "${remote_names[$index]}" && "${remote_names[$index]}" != '.' ]] &&
        [[ "${remote_refs[$index]}" == refs/heads/* && -n "${head_oids[$index]}" ]]
}
