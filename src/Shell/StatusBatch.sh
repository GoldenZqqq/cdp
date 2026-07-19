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
