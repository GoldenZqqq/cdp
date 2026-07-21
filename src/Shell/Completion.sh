# cdp shell domain: Completion.sh
# shellcheck shell=bash
# Generated from the canonical cdp.sh source; do not source peer fragments.

# Export functions for bash/zsh
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f cdp
    export -f cdp_about
    export -f cdp-ls
    export -f cdp-add
    export -f cdp-rm
    export -f cdp-config
    export -f cdp-doctor
    export -f cdp-recent
    export -f cdp-pin
    export -f cdp-unpin
    export -f cdp-clean
    export -f cdp-init
    export -f cdp-alias
    export -f cdp-unalias
    export -f cdp-tag
    export -f cdp-untag
    export -f cdp-scan
fi

cdp_completion_project_names() {
    local config_path
    config_path=$(get_default_config 2>/dev/null)
    [[ -n "$config_path" && -f "$config_path" ]] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    jq -r '.[] | select(.enabled == true) | .name' "$config_path" 2>/dev/null
}

cdp_completion_workspace_names() {
    local config_path workspace_path
    config_path=$(get_default_config 2>/dev/null)
    [[ -n "$config_path" ]] || return 0
    workspace_path="$(dirname "$config_path")/workspaces.json"
    [[ -f "$workspace_path" ]] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    jq -r '.[] | .name' "$workspace_path" 2>/dev/null
}

cdp_completion_tags() {
    local config_path
    config_path=$(get_default_config 2>/dev/null)
    [[ -n "$config_path" && -f "$config_path" ]] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    jq -r '.[] | select(.enabled == true) | (.tags // [])[]' "$config_path" 2>/dev/null |
        sort -u | while IFS= read -r tag; do printf '@%s\n' "$tag"; done
}

_cdp_completions() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local subcommands="status doctor about recent pin unpin alias unalias tag untag clean init scan workspace hook exec add remove config"
    local launchers="code cursor codex claude gemini"
    local layouts="tabs split-horizontal split-vertical"

    if [[ "$prev" == "--open" || "$prev" == "-o" ]]; then
        COMPREPLY=($(compgen -W "$launchers" -- "$cur"))
        return
    fi
    if [[ "$prev" == "--layout" ]]; then
        COMPREPLY=($(compgen -W "$layouts" -- "$cur"))
        return
    fi

    if [[ "${COMP_WORDS[1]}" =~ ^(recent|recents|history)$ ]]; then
        if [[ "$COMP_CWORD" -eq 2 ]]; then COMPREPLY=($(compgen -W 'reset 1 5 10' -- "$cur")); return; fi
        if [[ "${COMP_WORDS[2]}" == reset ]]; then COMPREPLY=($(compgen -W '--dry-run --yes' -- "$cur")); return; fi
    fi

    if [[ $COMP_CWORD -eq 1 ]]; then
        local projects=""
        local config_path
        config_path=$(get_default_config 2>/dev/null)
        if [[ -n "$config_path" && -f "$config_path" ]] && command -v jq &>/dev/null; then
            projects=$(jq -r '.[] | select(.enabled == true) | .name' "$config_path" 2>/dev/null | tr '\r' ' ')
        fi
        COMPREPLY=($(compgen -W "$subcommands $projects" -- "$cur"))
        return
    fi

    if [[ "${COMP_WORDS[1]}" =~ ^(exec|run)$ ]]; then
        local i projects tags workspace_names
        for ((i=2; i<COMP_CWORD; i++)); do [[ "${COMP_WORDS[$i]}" == -- ]] && { COMPREPLY=(); return; }; done
        if [[ "$prev" == --workspace ]]; then workspace_names=$(cdp_completion_workspace_names | tr '\r\n' '  '); COMPREPLY=($(compgen -W "$workspace_names" -- "$cur")); return; fi
        if [[ "$prev" == --jobs ]]; then COMPREPLY=($(compgen -W '1 2 4 8 16' -- "$cur")); return; fi
        if [[ "$prev" == --timeout ]]; then COMPREPLY=($(compgen -W '30 60 300 600' -- "$cur")); return; fi
        projects=$(cdp_completion_project_names | tr '\r\n' '  ')
        tags=$(cdp_completion_tags | tr '\r\n' '  ')
        COMPREPLY=($(compgen -W "--workspace --all --config --jobs --timeout --fail-fast --continue --json --dry-run --yes -- $projects $tags" -- "$cur"))
        return
    fi

    if [[ "${COMP_WORDS[1]}" == status ]]; then
        if [[ "$prev" == --fetch-jobs ]]; then COMPREPLY=($(compgen -W '1 2 4 8 16' -- "$cur")); return; fi
        if [[ "$prev" == --fetch-timeout ]]; then COMPREPLY=($(compgen -W '5 15 30 60' -- "$cur")); return; fi
        COMPREPLY=($(compgen -W '--dirty --fix --push --fetch --fetch-jobs --fetch-timeout --refresh --jobs --json --no-color --config --dry-run --yes' -- "$cur"))
        return
    fi

    if [[ "${COMP_WORDS[1]}" =~ ^(workspace|ws)$ ]]; then
        local workspace_actions="list show add edit remove validate open"
        local workspace_action="${COMP_WORDS[2]:-}"
        local workspace_names projects
        workspace_names=$(cdp_completion_workspace_names | tr '\r\n' '  ')
        projects=$(cdp_completion_project_names | tr '\r\n' '  ')
        if [[ $COMP_CWORD -eq 2 ]]; then COMPREPLY=($(compgen -W "$workspace_actions $workspace_names" -- "$cur")); return; fi
        if [[ "$workspace_action" =~ ^(show|remove|validate|open)$ && $COMP_CWORD -eq 3 ]]; then COMPREPLY=($(compgen -W "$workspace_names" -- "$cur")); return; fi
        if [[ "$workspace_action" =~ ^(add|edit)$ && $COMP_CWORD -ge 4 ]]; then COMPREPLY=($(compgen -W "$projects" -- "$cur")); return; fi
    fi

    if [[ "${COMP_WORDS[1]}" =~ ^(pin|unpin|alias|unalias|tag|untag)$ && $COMP_CWORD -eq 2 ]]; then
        local projects=""
        local config_path
        config_path=$(get_default_config 2>/dev/null)
        if [[ -n "$config_path" && -f "$config_path" ]] && command -v jq &>/dev/null; then
            projects=$(jq -r '.[] | select(.enabled == true) | .name' "$config_path" 2>/dev/null | tr '\r' ' ')
        fi
        COMPREPLY=($(compgen -W "$projects" -- "$cur"))
        return
    fi
}

if [[ -n "${BASH_VERSION:-}" ]]; then
    complete -F _cdp_completions cdp
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    autoload -Uz compinit 2>/dev/null
    _cdp_zsh_complete_words() {
        setopt localoptions noksharrays
        local completion_current="$1"
        shift
        local -a completion_words=("$@")
        local subcommands=(status doctor about recent pin unpin alias unalias tag untag clean init scan workspace hook exec add remove config)
        local launchers=(code cursor codex claude gemini)
        local layouts=(tabs split-horizontal split-vertical)
        local cur="${completion_words[$completion_current]}"
        local prev="${completion_words[$((completion_current-1))]}"

        if [[ "$prev" == "--open" || "$prev" == "-o" ]]; then
            compadd -a launchers
            return
        fi
        if [[ "$prev" == "--layout" ]]; then
            compadd -a layouts
            return
        fi

        if [[ "${completion_words[2]}" =~ ^(recent|recents|history)$ ]]; then
            if [[ $completion_current -eq 3 ]]; then compadd reset 1 5 10; return; fi
            if [[ "${completion_words[3]}" == reset ]]; then compadd -- --dry-run --yes; return; fi
        fi

        if [[ $completion_current -eq 2 ]]; then
            local projects=()
            local config_path
            config_path=$(get_default_config 2>/dev/null)
            if [[ -n "$config_path" && -f "$config_path" ]] && command -v jq &>/dev/null; then
                projects=(${(f)"$(jq -r '.[] | select(.enabled == true) | .name' "$config_path" 2>/dev/null)"})
            fi
            compadd -a subcommands
            compadd -a projects
            return
        fi

        if [[ "${completion_words[2]}" =~ ^(exec|run)$ ]]; then
            local index
            for ((index=3; index<completion_current; index++)); do [[ "${completion_words[$index]}" == -- ]] && return; done
            if [[ "$prev" == --workspace ]]; then local workspace_names=(${(f)"$(cdp_completion_workspace_names)"}); compadd -a workspace_names; return; fi
            if [[ "$prev" == --jobs ]]; then local job_values=(1 2 4 8 16); compadd -a job_values; return; fi
            if [[ "$prev" == --timeout ]]; then local timeout_values=(30 60 300 600); compadd -a timeout_values; return; fi
            local exec_options=(--workspace --all --config --jobs --timeout --fail-fast --continue --json --dry-run --yes --)
            local exec_projects=(${(f)"$(cdp_completion_project_names)"})
            local exec_tags=(${(f)"$(cdp_completion_tags)"})
            compadd -a exec_options; compadd -a exec_projects; compadd -a exec_tags
            return
        fi

        if [[ "${completion_words[2]}" == status ]]; then
            if [[ "$prev" == --fetch-jobs ]]; then local fetch_jobs=(1 2 4 8 16); compadd -a fetch_jobs; return; fi
            if [[ "$prev" == --fetch-timeout ]]; then local fetch_timeouts=(5 15 30 60); compadd -a fetch_timeouts; return; fi
            local status_options=(--dirty --fix --push --fetch --fetch-jobs --fetch-timeout --refresh --jobs --json --no-color --config --dry-run --yes)
            compadd -a status_options
            return
        fi

        if [[ "${completion_words[2]}" =~ ^(workspace|ws)$ ]]; then
            local workspace_actions=(list show add edit remove validate open)
            local workspace_action="${completion_words[3]:-}"
            local workspace_names=()
            local projects=()
            workspace_names=(${(f)"$(cdp_completion_workspace_names)"})
            projects=(${(f)"$(cdp_completion_project_names)"})
            if [[ $completion_current -eq 3 ]]; then compadd -a workspace_actions; compadd -a workspace_names; return; fi
            if [[ "$workspace_action" =~ ^(show|remove|validate|open)$ && $completion_current -eq 4 ]]; then compadd -a workspace_names; return; fi
            if [[ "$workspace_action" =~ ^(add|edit)$ && $completion_current -ge 5 ]]; then compadd -a projects; return; fi
        fi

        if [[ "${completion_words[2]}" =~ ^(pin|unpin|alias|unalias|tag|untag)$ && $completion_current -eq 3 ]]; then
            local projects=()
            local config_path
            config_path=$(get_default_config 2>/dev/null)
            if [[ -n "$config_path" && -f "$config_path" ]] && command -v jq &>/dev/null; then
                projects=(${(f)"$(jq -r '.[] | select(.enabled == true) | .name' "$config_path" 2>/dev/null)"})
            fi
            compadd -a projects
            return
        fi
    }
    _cdp_zsh_completions() {
        setopt localoptions noksharrays
        _cdp_zsh_complete_words "$CURRENT" "${words[@]}"
    }
    compdef _cdp_zsh_completions cdp 2>/dev/null || true
fi
