# cdp shell domain: Frecency.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

cdp_frecency_enabled() {
    case "${CDP_FRECENCY:-}" in
        0|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|[Nn][Oo]) return 1 ;;
        *) return 0 ;;
    esac
}

cdp_frecency_jq_filter() {
    printf '%s\n' '
def parsed_epoch:
    if (type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}")) then
        try (capture("^(?<stamp>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})")
            | .stamp | strptime("%Y-%m-%dT%H:%M:%S") | mktime) catch null
    else null end;
def parsed_visits:
    if (type == "number" and . >= 0 and . == floor) then
        ([1, ., 1000] | sort | .[1])
    else null end;
def metric:
    (.lastVisitedAt | parsed_epoch) as $last |
    (.visitCount | parsed_visits) as $visits |
    if ($last == null or $visits == null) then {last:0, visits:0, score:0}
    else
        (($now - $last) | if . < 0 then 0 else . end | ./86400 | floor) as $age |
        {last:$last, visits:$visits, score:(($visits * 1000000 / ($age + 1)) | floor)}
    end;
((($state[0].recentProjects // []))[:10000]
    | map(select((.rootPath | type) == "string") | {rootPath:.rootPath, metric:metric})
    | reduce .[] as $entry ({};
        if (has($entry.rootPath) | not) then .[$entry.rootPath] = $entry.metric
        elif ($entry.metric.last > .[$entry.rootPath].last or
            ($entry.metric.last == .[$entry.rootPath].last and
                $entry.metric.visits > .[$entry.rootPath].visits)) then
            .[$entry.rootPath] = $entry.metric
        else . end)) as $history
| to_entries
| map(select(.value.enabled == true) |
    (.value.rootPath as $root |
        ($history[$root] // {last:0, visits:0, score:0}) as $metric |
        . + {pinRank:(if .value.pinned == true then 0 else 1 end),
            score:$metric.score, last:$metric.last, visits:$metric.visits}))
| sort_by(.pinRank, -.score, -.last, -.visits, .key)
| .[].value
'
}

cdp_frecency_config_order_json() {
    jq -c '
        to_entries
        | map(select(.value.enabled == true))
        | sort_by(if .value.pinned == true then 0 else 1 end, .key)
        | .[].value
    ' "$1" 2>/dev/null
}

cdp_frecency_ranked_project_json() {
    local config_path="$1"
    local now_epoch="${2:-}"
    local state_path
    local state_input='/dev/null'
    local jq_filter

    [[ -f "$config_path" ]] || return 1
    if ! [[ "$now_epoch" =~ ^[0-9]+$ ]]; then
        if command -v date >/dev/null 2>&1; then now_epoch=$(date -u +%s)
        else cdp_frecency_config_order_json "$config_path"; return; fi
    fi
    state_path=$(cdp_state_path)
    if [[ -f "$state_path" ]] && jq -e '
        type == "object" and (.recentProjects == null or (.recentProjects | type) == "array")
    ' "$state_path" >/dev/null 2>&1; then
        state_input="$state_path"
    fi

    if ! cdp_frecency_enabled; then
        cdp_frecency_config_order_json "$config_path"
        return
    fi

    jq_filter=$(cdp_frecency_jq_filter)
    jq -c --argjson now "$now_epoch" --slurpfile state "$state_input" \
        "$jq_filter" "$config_path" 2>/dev/null
}

sorted_enabled_project_names() {
    cdp_frecency_ranked_project_json "$1" "${2:-}" | jq -r '.name'
}

sorted_enabled_project_rows() {
    cdp_frecency_ranked_project_json "$1" "${2:-}" | jq -r '[.name, ((.pinned == true) | tostring), .rootPath] | @tsv'
}
