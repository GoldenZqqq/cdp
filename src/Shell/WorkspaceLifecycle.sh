# cdp shell domain: WorkspaceLifecycle.sh
# shellcheck shell=bash
# Generated runtime fragment; do not source peer fragments.

CDP_WORKSPACE_ACTION=""
CDP_WORKSPACE_NAME=""
CDP_WORKSPACE_CONFIG_PATH=""
CDP_WORKSPACE_OPEN=""
CDP_WORKSPACE_LAYOUT=""
CDP_WORKSPACE_CLEAR_OPEN=false
CDP_WORKSPACE_FIX=false
CDP_WORKSPACE_PROJECTS=()

cdp_workspace_layout_json() {
    case "$1" in
        tabs) jq -cn '{mode:"tabs"}' ;;
        split-horizontal) jq -cn '{mode:"split",direction:"horizontal"}' ;;
        split-vertical) jq -cn '{mode:"split",direction:"vertical"}' ;;
        *) echo "Error: workspace layout must be tabs, split-horizontal, or split-vertical." >&2; return 1 ;;
    esac
}

cdp_workspace_layout_label() {
    local workspace_json="$1"
    jq -er '
        if has("layout") | not then "tabs"
        elif (.layout | type) != "object" then error("invalid")
        elif .layout.mode == "tabs" then "tabs"
        elif .layout.mode == "split" and .layout.direction == "horizontal" then "split-horizontal"
        elif .layout.mode == "split" and .layout.direction == "vertical" then "split-vertical"
        else error("invalid") end
    ' <<< "$workspace_json" 2>/dev/null
}

cdp_workspace_read_json() {
    local workspace_path="$1"
    if [[ ! -f "$workspace_path" ]]; then
        printf '[]\n'
        return 0
    fi
    if ! jq -e 'type == "array"' "$workspace_path" >/dev/null 2>&1; then
        echo "Error: workspace configuration must be a JSON array: $workspace_path" >&2
        return 1
    fi
    cat "$workspace_path"
}

cdp_workspace_parse_args() {
    cdp_parse_safety_options "$@" || return 1
    set -- "${CDP_SAFETY_ARGS[@]}"
    CDP_WORKSPACE_CONFIG_PATH=""
    CDP_WORKSPACE_OPEN=""
    CDP_WORKSPACE_LAYOUT=""
    CDP_WORKSPACE_CLEAR_OPEN=false
    CDP_WORKSPACE_FIX=false
    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config) [[ -n "${2:-}" ]] || { echo 'Error: missing value after --config.' >&2; return 1; }; [[ -z "$CDP_WORKSPACE_CONFIG_PATH" ]] || { echo 'Error: --config specified more than once.' >&2; return 1; }; CDP_WORKSPACE_CONFIG_PATH="$2"; shift 2 ;;
            --open|-o) [[ -n "${2:-}" ]] || { echo 'Error: missing value after --open.' >&2; return 1; }; [[ -z "$CDP_WORKSPACE_OPEN" ]] || { echo 'Error: --open specified more than once.' >&2; return 1; }; CDP_WORKSPACE_OPEN="$2"; shift 2 ;;
            --layout) [[ -n "${2:-}" ]] || { echo 'Error: missing value after --layout.' >&2; return 1; }; [[ -z "$CDP_WORKSPACE_LAYOUT" ]] || { echo 'Error: --layout specified more than once.' >&2; return 1; }; CDP_WORKSPACE_LAYOUT="$2"; shift 2 ;;
            --clear-open) CDP_WORKSPACE_CLEAR_OPEN=true; shift ;;
            --fix) CDP_WORKSPACE_FIX=true; shift ;;
            *) positional+=("$1"); shift ;;
        esac
    done
    cdp_workspace_parse_positionals "${positional[@]}"
}

cdp_workspace_parse_positionals() {
    local action="${1:-}"
    [[ $# -gt 0 ]] && shift
    case "$action" in
        --list|-l) action=list ;;
        --add|-a) action=add ;;
        '') action=usage ;;
        list|show|add|edit|remove|validate|open) ;;
        -*) echo "Error: unknown workspace option: $action" >&2; return 1 ;;
        *) set -- "$action" "$@"; action=open ;;
    esac
    CDP_WORKSPACE_ACTION="$action"
    CDP_WORKSPACE_NAME="${1:-}"
    [[ $# -gt 0 ]] && shift
    CDP_WORKSPACE_PROJECTS=("$@")
    cdp_workspace_validate_parsed_args
}

cdp_workspace_validate_parsed_args() {
    local count="${#CDP_WORKSPACE_PROJECTS[@]}"
    case "$CDP_WORKSPACE_ACTION" in
        usage) [[ -z "$CDP_WORKSPACE_OPEN$CDP_WORKSPACE_LAYOUT" ]] && ! $CDP_WORKSPACE_CLEAR_OPEN && ! $CDP_WORKSPACE_FIX || { echo 'Error: workspace options require an action.' >&2; return 1; } ;;
        list) [[ -z "$CDP_WORKSPACE_NAME" && $count -eq 0 ]] || { echo 'Error: workspace list does not accept arguments.' >&2; return 1; }; cdp_workspace_require_read_only ;;
        show|remove|open) [[ -n "$CDP_WORKSPACE_NAME" && $count -eq 0 ]] || { echo "Error: workspace $CDP_WORKSPACE_ACTION requires one workspace name." >&2; return 1; } ;;
        validate) [[ $count -eq 0 ]] || { echo 'Error: workspace validate accepts at most one workspace name.' >&2; return 1; } ;;
        add) [[ -n "$CDP_WORKSPACE_NAME" && $count -gt 0 ]] || { echo 'Error: workspace add requires a name and at least one project.' >&2; return 1; } ;;
        edit) [[ -n "$CDP_WORKSPACE_NAME" ]] || { echo 'Error: workspace edit requires one workspace name.' >&2; return 1; } ;;
    esac
    cdp_workspace_validate_action_options
}

cdp_workspace_require_read_only() {
    if $CDP_SAFETY_DRY_RUN || $CDP_SAFETY_YES; then echo 'Error: read-only workspace actions do not accept safety options.' >&2; return 1; fi
    [[ -z "$CDP_WORKSPACE_OPEN$CDP_WORKSPACE_LAYOUT" ]] && ! $CDP_WORKSPACE_CLEAR_OPEN && ! $CDP_WORKSPACE_FIX || {
        echo 'Error: read-only workspace actions do not accept update options.' >&2; return 1;
    }
}

cdp_workspace_validate_action_options() {
    if [[ -n "$CDP_WORKSPACE_OPEN" ]] && ! resolve_workspace_launcher "$CDP_WORKSPACE_OPEN" >/dev/null; then return 1; fi
    if [[ -n "$CDP_WORKSPACE_LAYOUT" ]] && ! cdp_workspace_layout_json "$CDP_WORKSPACE_LAYOUT" >/dev/null; then return 1; fi
    if [[ "$CDP_WORKSPACE_ACTION" == show ]]; then cdp_workspace_require_read_only || return 1; fi
    if [[ "$CDP_WORKSPACE_ACTION" == remove ]] && [[ -n "$CDP_WORKSPACE_OPEN$CDP_WORKSPACE_LAYOUT" || "$CDP_WORKSPACE_CLEAR_OPEN" == true || "$CDP_WORKSPACE_FIX" == true ]]; then echo 'Error: workspace remove does not accept update options.' >&2; return 1; fi
    if [[ "$CDP_WORKSPACE_ACTION" == validate ]] && [[ -n "$CDP_WORKSPACE_OPEN$CDP_WORKSPACE_LAYOUT" || "$CDP_WORKSPACE_CLEAR_OPEN" == true ]]; then echo 'Error: workspace validate does not accept launcher or layout options.' >&2; return 1; fi
    if [[ "$CDP_WORKSPACE_ACTION" == validate ]] && { $CDP_SAFETY_DRY_RUN || $CDP_SAFETY_YES; } && ! $CDP_WORKSPACE_FIX; then echo 'Error: workspace validate safety options require --fix.' >&2; return 1; fi
    if [[ "$CDP_WORKSPACE_ACTION" == add ]] && { $CDP_WORKSPACE_CLEAR_OPEN || $CDP_WORKSPACE_FIX; }; then echo 'Error: workspace add does not accept --clear-open or --fix.' >&2; return 1; fi
    if [[ "$CDP_WORKSPACE_ACTION" == edit ]] && [[ -n "$CDP_WORKSPACE_OPEN" ]] && $CDP_WORKSPACE_CLEAR_OPEN; then echo 'Error: workspace --open and --clear-open cannot be used together.' >&2; return 1; fi
    if [[ "$CDP_WORKSPACE_ACTION" == edit && ${#CDP_WORKSPACE_PROJECTS[@]} -eq 0 && -z "$CDP_WORKSPACE_OPEN$CDP_WORKSPACE_LAYOUT" && "$CDP_WORKSPACE_CLEAR_OPEN" == false ]]; then echo 'Error: workspace edit requires projects or an open/layout update.' >&2; return 1; fi
    if [[ "$CDP_WORKSPACE_ACTION" != validate ]] && $CDP_WORKSPACE_FIX; then echo 'Error: --fix is only valid with workspace validate.' >&2; return 1; fi
    if [[ "$CDP_WORKSPACE_ACTION" != edit ]] && $CDP_WORKSPACE_CLEAR_OPEN; then echo 'Error: --clear-open is only valid with workspace edit.' >&2; return 1; fi
    if [[ "$CDP_WORKSPACE_ACTION" != add && "$CDP_WORKSPACE_ACTION" != edit && "$CDP_WORKSPACE_ACTION" != open && -n "$CDP_WORKSPACE_OPEN" ]]; then echo 'Error: --open is not valid for this workspace action.' >&2; return 1; fi
    if [[ "$CDP_WORKSPACE_ACTION" != add && "$CDP_WORKSPACE_ACTION" != edit && -n "$CDP_WORKSPACE_LAYOUT" ]]; then echo 'Error: --layout is only valid with workspace add or edit.' >&2; return 1; fi
}

cdp_workspace_project_references() {
    local projects_json="$1"
    shift
    local references='[]'
    local project_name project_matches project_json reference
    for project_name in "$@"; do
        project_matches=$(jq -c --arg name "$project_name" '[.[] | select(.enabled == true and .name == $name)]' <<< "$projects_json")
        [[ "$(jq 'length' <<< "$project_matches")" -eq 1 ]] || { echo "Error: workspace project '$project_name' must match one enabled project." >&2; return 1; }
        project_json=$(jq -c '.[0]' <<< "$project_matches")
        reference=$(jq -cn --argjson project "$project_json" '{name:$project.name,rootPath:$project.rootPath}')
        references=$(jq -c --argjson reference "$reference" '. + [$reference]' <<< "$references")
    done
    printf '%s\n' "$references"
}

cdp_workspace_reference_result() {
    local reference_json="$1" projects_json="$2" workspace_open="$3" open_override="${4:-}"
    local reference_type configured_name="" raw_path="" reference_status=ok project_matches='[]' project_json="" current_name="" resolved_path="" launcher="" size=null
    reference_type=$(jq -r 'type' <<< "$reference_json")
    if [[ "$reference_type" == string ]]; then configured_name=$(jq -r '.' <<< "$reference_json"); [[ -n "$configured_name" ]] || reference_status=invalid-reference
    elif [[ "$reference_type" == object ]]; then
        configured_name=$(jq -r '.name // empty' <<< "$reference_json"); raw_path=$(jq -r '.rootPath // empty' <<< "$reference_json")
        [[ -n "$configured_name" && -n "$raw_path" && "$(jq -r '.name|type' <<< "$reference_json")" == string && "$(jq -r '.rootPath|type' <<< "$reference_json")" == string ]] || reference_status=invalid-reference
        if [[ "$reference_status" == ok ]] && jq -e 'has("size")' <<< "$reference_json" >/dev/null; then jq -e '.size|type == "number" and . == floor and . >= 10 and . <= 90' <<< "$reference_json" >/dev/null || reference_status=invalid-size; fi
        launcher=$(jq -r '.open // empty' <<< "$reference_json"); if [[ "$reference_status" == ok && -n "$launcher" ]] && ! resolve_workspace_launcher "$launcher" >/dev/null; then reference_status=invalid-launcher; fi
        size=$(jq -c '.size // null' <<< "$reference_json")
    else reference_status=invalid-reference; fi
    if [[ "$reference_type" == string ]]; then project_matches=$(jq -c --arg name "$configured_name" '[.[] | select(.name == $name)]' <<< "$projects_json"); else project_matches=$(jq -c --arg root "$raw_path" '[.[] | select(.rootPath == $root)]' <<< "$projects_json"); fi
    local project_count; project_count=$(jq 'length' <<< "$project_matches")
    if [[ "$reference_status" == ok && $project_count -eq 0 ]]; then reference_status=missing-project; elif [[ "$reference_status" == ok && $project_count -gt 1 ]]; then reference_status=ambiguous-project; fi
    if [[ $project_count -eq 1 ]]; then
        project_json=$(jq -c '.[0]' <<< "$project_matches"); current_name=$(jq -r '.name' <<< "$project_json"); [[ -n "$raw_path" ]] || raw_path=$(jq -r '.rootPath' <<< "$project_json")
        if [[ "$reference_status" == ok && "$(jq -r '.enabled == true' <<< "$project_json")" != true ]]; then reference_status=disabled-project
        elif [[ "$reference_status" == ok && "$reference_type" == string ]]; then reference_status=legacy
        elif [[ "$reference_status" == ok && "$configured_name" != "$current_name" ]]; then reference_status=renamed; fi
        if cdp_resolve_project_json "$project_json"; then
            resolved_path="$CDP_PROJECT_RESOLVED_PATH"
        elif [[ "$reference_status" == ok || "$reference_status" == legacy || "$reference_status" == renamed ]]; then
            reference_status=invalid-path-profile
        fi
        if [[ -n "$resolved_path" && ! -d "$resolved_path" && ( "$reference_status" == ok || "$reference_status" == legacy || "$reference_status" == renamed ) ]]; then reference_status=missing-path; fi
    fi
    [[ -n "$open_override" ]] && launcher="$open_override" || { [[ -n "$launcher" ]] || launcher="$workspace_open"; }
    if [[ -n "$launcher" ]] && ! resolve_workspace_launcher "$launcher" >/dev/null 2>&1 && [[ "$reference_status" == ok || "$reference_status" == legacy || "$reference_status" == renamed ]]; then reference_status=invalid-launcher; fi
    [[ -n "$current_name" ]] || current_name="$configured_name"
    local project_arg=null; [[ -n "$project_json" ]] && project_arg="$project_json"
    jq -cn --argjson reference "$reference_json" --argjson project "$project_arg" --arg configuredName "$configured_name" --arg name "$current_name" --arg rawPath "$raw_path" --arg resolvedPath "$resolved_path" --arg status "$reference_status" --arg launcher "$launcher" --argjson size "$size" '{reference:$reference,project:$project,configuredName:$configuredName,name:$name,rawPath:$rawPath,resolvedPath:$resolvedPath,status:$status,launcher:$launcher,size:$size}'
}

cdp_workspace_build_plan() {
    local workspace_json="$1" projects_json="$2" open_override="${3:-}"
    local workspace_open reference_json result plan='[]'
    workspace_open=$(jq -r '.open // empty' <<< "$workspace_json")
    while IFS= read -r reference_json <&3; do
        [[ -n "$reference_json" ]] || continue
        result=$(cdp_workspace_reference_result "$reference_json" "$projects_json" "$workspace_open" "$open_override") || return 1
        plan=$(jq -c --argjson result "$result" '. + [$result]' <<< "$plan")
    done 3< <(jq -c '.projects[]?' <<< "$workspace_json")
    printf '%s\n' "$plan"
}

cdp_workspace_print_plan() {
    local workspace_name="$1" layout_label="$2" plan="$3" result
    echo "Workspace: $workspace_name"
    echo "Layout: $layout_label"
    while IFS= read -r result <&3; do
        [[ -n "$result" ]] || continue
        jq -r '"  \(.name) [\(.status)] raw=\(.rawPath) resolved=\(.resolvedPath) launcher=\(if .launcher == "" then "-" else .launcher end)"' <<< "$result"
    done 3< <(jq -c '.[]' <<< "$plan")
}

cdp_workspace_validate_display() {
    local workspace_json="$1" projects_json="$2" workspace_name layout_label plan aggregate_status=0
    workspace_name=$(jq -r '.name // empty' <<< "$workspace_json")
    if ! layout_label=$(cdp_workspace_layout_label "$workspace_json"); then echo "  $workspace_name: invalid-layout"; aggregate_status=1; layout_label=invalid; fi
    local workspace_open; workspace_open=$(jq -r '.open // empty' <<< "$workspace_json")
    if [[ -n "$workspace_open" ]] && ! resolve_workspace_launcher "$workspace_open" >/dev/null 2>&1; then echo "  $workspace_name: invalid-launcher"; aggregate_status=1; fi
    if [[ "$(jq -r '(.projects|type) == "array" and (.projects|length) > 0' <<< "$workspace_json")" != true ]]; then echo "  $workspace_name: invalid-reference"; return 1; fi
    plan=$(cdp_workspace_build_plan "$workspace_json" "$projects_json") || return 1
    local result result_status launchable_count
    while IFS= read -r result <&3; do
        result_status=$(jq -r '.status' <<< "$result")
        jq -r '"  \(.name): \(.status)"' <<< "$result"
        case "$result_status" in ok|legacy|renamed) ;; *) aggregate_status=1 ;; esac
    done 3< <(jq -c '.[]' <<< "$plan")
    return "$aggregate_status"
}

cdp_workspace_fix_json() {
    local workspaces_json="$1" projects_json="$2" target_name="$3"
    jq -c --arg target "$target_name" --argjson projects "$projects_json" '
        def fixref:
          if type == "string" then . as $name | [$projects[] | select(.name == $name)] as $m |
            if ($m|length) == 1 then {name:$m[0].name,rootPath:$m[0].rootPath} else . end
          elif type == "object" and (.rootPath|type) == "string" then . as $ref |
            [$projects[] | select(.rootPath == $ref.rootPath)] as $m |
            if ($m|length) == 1 and ($m[0].name != ($ref.name // "")) then .name = $m[0].name else . end
          else . end;
        map(if ($target == "" or .name == $target) and ((.projects|type) == "array") then .projects |= map(fixref) else . end)
    ' <<< "$workspaces_json"
}

cdp_workspace_find() {
    local workspaces_json="$1" workspace_name="$2"
    jq -c --arg name "$workspace_name" '[.[] | select(.name == $name)]' <<< "$workspaces_json"
}

cdp_workspace_action_result_preview() {
    local action="$1" target="$2"
    if $CDP_SAFETY_DRY_RUN; then cdp_action_result "$action" "$target" preview false; return 2; fi
    return 0
}

cdp_workspace_list_action() {
    local workspaces_json="$1"
    if [[ "$(jq 'length' <<< "$workspaces_json")" -eq 0 ]]; then
        echo 'No workspaces defined.'
        echo 'Create one: cdp workspace add <name> <project1> <project2> ...'
        return 0
    fi
    echo 'cdp workspaces'
    jq -r '.[] | "  \(.name)\(if .open then " [\(.open)]" else "" end) -> \(.projects | map(if type == "string" then . else (.name // "<invalid>") end) | join(", "))"' <<< "$workspaces_json"
}

cdp_workspace_show_action() {
    local workspaces_json="$1" projects_json="$2" workspace_name="$3"
    local matches workspace_json layout_label plan result result_status workspace_open show_failed=false
    matches=$(cdp_workspace_find "$workspaces_json" "$workspace_name")
    [[ "$(jq 'length' <<< "$matches")" -eq 1 ]] || { echo "Error: workspace '$workspace_name' not found." >&2; return 1; }
    workspace_json=$(jq -c '.[0]' <<< "$matches")
    if ! layout_label=$(cdp_workspace_layout_label "$workspace_json"); then layout_label=invalid; show_failed=true; fi
    [[ "$(jq -r '(.projects|type) == "array" and (.projects|length) > 0' <<< "$workspace_json")" == true ]] || { echo "Error: workspace '$workspace_name' has invalid project references." >&2; return 1; }
    plan=$(cdp_workspace_build_plan "$workspace_json" "$projects_json") || return 1
    cdp_workspace_print_plan "$workspace_name" "$layout_label" "$plan"
    [[ "$layout_label" != invalid ]] || echo "  $workspace_name [invalid-layout]"
    workspace_open=$(jq -r '.open // empty' <<< "$workspace_json")
    if [[ -n "$workspace_open" ]] && ! resolve_workspace_launcher "$workspace_open" >/dev/null 2>&1; then echo "  $workspace_name [invalid-launcher]"; show_failed=true; fi
    while IFS= read -r result <&3; do
        result_status=$(jq -r '.status' <<< "$result")
        case "$result_status" in ok|legacy|renamed) ;; *) show_failed=true ;; esac
    done 3< <(jq -c '.[]' <<< "$plan")
    $show_failed && return 1
    return 0
}

cdp_workspace_add_action() {
    local workspace_path="$1" workspaces_json="$2" projects_json="$3" workspace_name="$4"
    shift 4
    [[ "$(jq --arg name "$workspace_name" '[.[] | select(.name == $name)] | length' <<< "$workspaces_json")" -eq 0 ]] || { echo "Error: workspace '$workspace_name' already exists." >&2; return 1; }
    local references new_workspace layout_json expected_fingerprint
    references=$(cdp_workspace_project_references "$projects_json" "$@") || return 1
    new_workspace=$(jq -cn --arg name "$workspace_name" --argjson projects "$references" '{name:$name,projects:$projects}')
    if [[ -n "$CDP_WORKSPACE_OPEN" ]]; then new_workspace=$(jq -c --arg open "$CDP_WORKSPACE_OPEN" '.open=$open' <<< "$new_workspace"); fi
    if [[ -n "$CDP_WORKSPACE_LAYOUT" ]]; then layout_json=$(cdp_workspace_layout_json "$CDP_WORKSPACE_LAYOUT") || return 1; new_workspace=$(jq -c --argjson layout "$layout_json" '.layout=$layout' <<< "$new_workspace"); fi
    if cdp_workspace_action_result_preview add-workspace "$workspace_name"; then :; else [[ $? -eq 2 ]] && return 0; return 1; fi
    expected_fingerprint=$(cdp_json_fingerprint "$workspace_path")
    cdp_write_json_text "$workspace_path" "$(jq -c --argjson workspace "$new_workspace" '. + [$workspace]' <<< "$workspaces_json")" "$expected_fingerprint" || return 1
    echo "Workspace '$workspace_name' created with $# projects."
    cdp_action_result add-workspace "$workspace_name" succeeded true
}

cdp_workspace_edit_action() {
    local workspace_path="$1" workspaces_json="$2" projects_json="$3" workspace_name="$4"
    shift 4
    local matches references='' layout_json='' updated expected_fingerprint
    matches=$(cdp_workspace_find "$workspaces_json" "$workspace_name")
    [[ "$(jq 'length' <<< "$matches")" -eq 1 ]] || { echo "Error: workspace '$workspace_name' not found." >&2; return 1; }
    if [[ $# -gt 0 ]]; then references=$(cdp_workspace_project_references "$projects_json" "$@") || return 1; fi
    if [[ -n "$CDP_WORKSPACE_LAYOUT" ]]; then layout_json=$(cdp_workspace_layout_json "$CDP_WORKSPACE_LAYOUT") || return 1; fi
    updated=$(jq -c --arg name "$workspace_name" --arg open "$CDP_WORKSPACE_OPEN" --argjson clearOpen "$CDP_WORKSPACE_CLEAR_OPEN" --argjson replaceProjects "$([[ -n "$references" ]] && printf true || printf false)" --argjson projects "${references:-[]}" --argjson replaceLayout "$([[ -n "$layout_json" ]] && printf true || printf false)" --argjson layout "${layout_json:-null}" '
        map(if .name == $name then
          (if $replaceProjects then .projects=$projects else . end) |
          (if $clearOpen then del(.open) elif $open != "" then .open=$open else . end) |
          (if $replaceLayout then .layout=$layout else . end)
        else . end)
    ' <<< "$workspaces_json") || return 1
    if [[ "$updated" == "$(jq -c . <<< "$workspaces_json")" ]]; then cdp_action_result edit-workspace "$workspace_name" skipped false; return 0; fi
    if cdp_workspace_action_result_preview edit-workspace "$workspace_name"; then :; else [[ $? -eq 2 ]] && return 0; return 1; fi
    expected_fingerprint=$(cdp_json_fingerprint "$workspace_path")
    cdp_write_json_text "$workspace_path" "$updated" "$expected_fingerprint" || return 1
    echo "Workspace '$workspace_name' updated."
    cdp_action_result edit-workspace "$workspace_name" succeeded true
}

cdp_workspace_remove_action() {
    local workspace_path="$1" workspaces_json="$2" workspace_name="$3"
    local matches updated expected_fingerprint
    matches=$(cdp_workspace_find "$workspaces_json" "$workspace_name")
    [[ "$(jq 'length' <<< "$matches")" -eq 1 ]] || { echo "Error: workspace '$workspace_name' not found." >&2; return 1; }
    if cdp_workspace_action_result_preview remove-workspace "$workspace_name"; then :; else [[ $? -eq 2 ]] && return 0; return 1; fi
    updated=$(jq -c --arg name "$workspace_name" 'map(select(.name != $name))' <<< "$workspaces_json")
    expected_fingerprint=$(cdp_json_fingerprint "$workspace_path")
    cdp_write_json_text "$workspace_path" "$updated" "$expected_fingerprint" || return 1
    echo "Workspace '$workspace_name' removed."
    cdp_action_result remove-workspace "$workspace_name" succeeded true
}

cdp_workspace_validate_action() {
    local workspace_path="$1" workspaces_json="$2" projects_json="$3" workspace_name="$4"
    local targets validation_failed=false workspace_json fixed_json expected_fingerprint
    if [[ -n "$workspace_name" ]]; then
        targets=$(cdp_workspace_find "$workspaces_json" "$workspace_name")
        [[ "$(jq 'length' <<< "$targets")" -eq 1 ]] || { echo "Error: workspace '$workspace_name' not found." >&2; return 1; }
    else targets="$workspaces_json"; fi
    while IFS= read -r workspace_json <&3; do
        [[ -n "$workspace_json" ]] || continue
        cdp_workspace_validate_display "$workspace_json" "$projects_json" || validation_failed=true
    done 3< <(jq -c '.[]' <<< "$targets")
    $CDP_WORKSPACE_FIX || { $validation_failed && return 1; return 0; }
    fixed_json=$(cdp_workspace_fix_json "$workspaces_json" "$projects_json" "$workspace_name") || return 1
    if [[ "$fixed_json" == "$(jq -c . <<< "$workspaces_json")" ]]; then cdp_action_result validate-workspace "${workspace_name:-$workspace_path}" skipped false; $validation_failed && return 1; return 0; fi
    if cdp_workspace_action_result_preview validate-workspace "${workspace_name:-$workspace_path}"; then :; else [[ $? -eq 2 ]] && { $validation_failed && return 1; return 0; }; return 1; fi
    expected_fingerprint=$(cdp_json_fingerprint "$workspace_path")
    cdp_write_json_text "$workspace_path" "$fixed_json" "$expected_fingerprint" || return 1
    cdp_action_result validate-workspace "${workspace_name:-$workspace_path}" succeeded true
    $validation_failed && return 1
    return 0
}

cdp_workspace_tmux_item() {
    local result_json="$1" layout_label="$2" session_name="$3" first="$4"
    local row project_name project_path launcher size command_name='' command_arg='' label='' direction=''
    row=$(jq -jr '[.name,.resolvedPath,.launcher,(.size // "")]|join("\u001c")' <<< "$result_json")
    IFS=$'\034' read -r project_name project_path launcher size <<< "$row"
    local launcher_args=()
    if [[ -n "$launcher" ]]; then IFS=$'\034' read -r command_name command_arg label < <(resolve_workspace_launcher "$launcher"); launcher_args=("$command_name"); [[ -n "$command_arg" ]] && launcher_args+=("$command_arg"); fi
    if [[ "$first" == true ]]; then
        if [[ ${#launcher_args[@]} -gt 0 ]]; then tmux new-session -d -s "$session_name" -c "$project_path" -n "$project_name" "${launcher_args[@]}"
        else tmux new-session -d -s "$session_name" -c "$project_path" -n "$project_name"; fi
    elif [[ "$layout_label" == tabs ]]; then
        if [[ ${#launcher_args[@]} -gt 0 ]]; then tmux new-window -t "$session_name" -c "$project_path" -n "$project_name" "${launcher_args[@]}"
        else tmux new-window -t "$session_name" -c "$project_path" -n "$project_name"; fi
    else
        [[ "$layout_label" == split-horizontal ]] && direction=-h || direction=-v
        if [[ -n "$size" && ${#launcher_args[@]} -gt 0 ]]; then tmux split-window -t "$session_name" "$direction" -p "$size" -c "$project_path" "${launcher_args[@]}"
        elif [[ -n "$size" ]]; then tmux split-window -t "$session_name" "$direction" -p "$size" -c "$project_path"
        elif [[ ${#launcher_args[@]} -gt 0 ]]; then tmux split-window -t "$session_name" "$direction" -c "$project_path" "${launcher_args[@]}"
        else tmux split-window -t "$session_name" "$direction" -c "$project_path"; fi
    fi
}

cdp_workspace_launch_action() {
    local workspaces_json="$1" projects_json="$2" workspace_name="$3"
    local matches workspace_json layout_label plan workspace_open workspace_failed=false approval=0
    matches=$(cdp_workspace_find "$workspaces_json" "$workspace_name")
    [[ "$(jq 'length' <<< "$matches")" -eq 1 ]] || { echo "Error: workspace '$workspace_name' not found." >&2; return 1; }
    workspace_json=$(jq -c '.[0]' <<< "$matches")
    layout_label=$(cdp_workspace_layout_label "$workspace_json") || { echo "Error: workspace '$workspace_name' has invalid layout." >&2; return 1; }
    [[ "$(jq -r '(.projects|type) == "array" and (.projects|length) > 0' <<< "$workspace_json")" == true ]] || { echo "Error: workspace '$workspace_name' has invalid project references." >&2; return 1; }
    workspace_open=$(jq -r '.open // empty' <<< "$workspace_json")
    if [[ -n "$workspace_open" ]] && ! resolve_workspace_launcher "$workspace_open" >/dev/null 2>&1; then workspace_failed=true; fi
    plan=$(cdp_workspace_build_plan "$workspace_json" "$projects_json" "$CDP_WORKSPACE_OPEN") || return 1
    cdp_workspace_print_plan "$workspace_name" "$layout_label" "$plan"
    local result result_status
    while IFS= read -r result <&3; do
        result_status=$(jq -r '.status' <<< "$result")
        case "$result_status" in ok|legacy|renamed) ;; *) cdp_action_result launch-workspace-project "$(jq -r '.name' <<< "$result")" failed false "$result_status"; workspace_failed=true ;; esac
    done 3< <(jq -c '.[]' <<< "$plan")
    launchable_count=$(jq '[.[] | select(.status == "ok" or .status == "legacy" or .status == "renamed")] | length' <<< "$plan")
    [[ "$launchable_count" -gt 0 ]] || return 1
    cdp_require_high_risk_approval "workspace '$workspace_name' launch" || approval=$?
    if [[ $approval -eq 2 ]]; then
        while IFS= read -r result <&3; do case "$(jq -r '.status' <<< "$result")" in ok|legacy|renamed) cdp_action_result launch-workspace-project "$(jq -r '.name' <<< "$result")" preview false ;; esac; done 3< <(jq -c '.[]' <<< "$plan")
        $workspace_failed && return 1; return 0
    fi
    [[ $approval -eq 0 ]] || return 1
    if ! command -v tmux >/dev/null 2>&1; then
        while IFS= read -r result <&3; do case "$(jq -r '.status' <<< "$result")" in ok|legacy|renamed) cdp_action_result launch-workspace-project "$(jq -r '.name' <<< "$result")" skipped false tmux-unavailable ;; esac; done 3< <(jq -c '.[]' <<< "$plan")
        $workspace_failed && return 1; return 0
    fi
    local session_name="cdp-$workspace_name" first=true started=false project_name
    while IFS= read -r result <&3; do
        case "$(jq -r '.status' <<< "$result")" in ok|legacy|renamed) ;; *) continue ;; esac
        project_name=$(jq -r '.name' <<< "$result")
        if cdp_workspace_tmux_item "$result" "$layout_label" "$session_name" "$first"; then echo "Opened workspace item: $project_name"; cdp_action_result launch-workspace-project "$project_name" succeeded true; first=false; started=true
        else cdp_action_result launch-workspace-project "$project_name" failed false tmux-launch-failed; workspace_failed=true; fi
    done 3< <(jq -c '.[]' <<< "$plan")
    $started && { tmux attach-session -t "$session_name" 2>/dev/null || tmux switch-client -t "$session_name" 2>/dev/null || true; }
    $workspace_failed && return 1
    return 0
}
