# cdp PowerShell domain: Parser.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function New-CdpInvocation {
    param([string]$Kind)

    [PSCustomObject]@{
        Kind = $Kind
        Command = $Kind
        ConfigPath = $null
        Query = $null
        Open = $null
        AllowHook = $false
        NoHook = $false
        DirtyOnly = $false
        Fix = $false
        Push = $false
        Json = $false
        NoColor = $false
        Refresh = $false
        ThrottleLimit = 0
        DryRun = $false
        Yes = $false
        TagFilter = $null
        WorkspaceAction = $null
        WorkspaceName = $null
        WorkspaceLayout = $null
        ClearOpen = $false
        Projects = @()
        Name = $null
        Value = $null
        RootPath = $null
        MaxDepth = 4
        Count = 10
        HookAction = $null
    }
}

function Get-CdpInvocationTokens {
    param([string]$Command, [string]$ConfigPath, [string[]]$RemainingArgs)

    $tokens = @()
    if (-not [string]::IsNullOrWhiteSpace($Command)) { $tokens += $Command }
    if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) { $tokens += $ConfigPath }
    if ($null -ne $RemainingArgs) { $tokens += @($RemainingArgs) }
    @($tokens | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Split-CdpCommonOptions {
    param([string[]]$Tokens, [string]$Open)

    $positionals = New-Object 'System.Collections.Generic.List[string]'
    $resolvedOpen = $Open
    $resolvedConfig = $null
    $allowHook = $false
    $noHook = $false
    $dryRun = $false
    $assumeYes = $false
    for ($i = 0; $i -lt $Tokens.Count; $i++) {
        $token = $Tokens[$i]
        if ($token -in @('--open', '-open', '-o')) {
            if ($i + 1 -ge $Tokens.Count) { throw "Missing value after --open." }
            if (-not [string]::IsNullOrWhiteSpace($resolvedOpen)) { throw "The --open option was specified more than once." }
            $resolvedOpen = $Tokens[++$i]
            continue
        }
        if ($token -in @('--config', '-config')) {
            if ($i + 1 -ge $Tokens.Count) { throw "Missing value after --config." }
            if (-not [string]::IsNullOrWhiteSpace($resolvedConfig)) { throw "The --config option was specified more than once." }
            $resolvedConfig = $Tokens[++$i]
            continue
        }
        if ($token -in @('--allow-hook', '-allow-hook')) {
            $allowHook = $true
            continue
        }
        if ($token -in @('--no-hook', '-no-hook')) {
            $noHook = $true
            continue
        }
        if ($token -in @('--dry-run', '-dry-run')) {
            $dryRun = $true
            continue
        }
        if ($token -in @('--yes', '-yes')) {
            $assumeYes = $true
            continue
        }
        $positionals.Add($token)
    }

    if ($allowHook -and $noHook) { throw "The --allow-hook and --no-hook options cannot be used together." }
    if ($dryRun -and $assumeYes) { throw "The --dry-run and --yes options cannot be used together." }

    [PSCustomObject]@{
        Tokens = @($positionals)
        Open = $resolvedOpen
        ConfigPath = $resolvedConfig
        AllowHook = $allowHook
        NoHook = $noHook
        DryRun = $dryRun
        Yes = $assumeYes
    }
}

function Resolve-CdpCommandKind {
    param([string]$Command)

    if ([string]::IsNullOrWhiteSpace($Command)) { return $null }
    switch -Regex ($Command.ToLowerInvariant()) {
        '^(status|st)$' { return 'status' }
        '^(workspace|ws)$' { return 'workspace' }
        '^(hook|hooks)$' { return 'hook' }
        '^(doctor|health|check)$' { return 'doctor' }
        '^(about|version|--version|-v)$' { return 'about' }
        '^(recent|recents|history)$' { return 'recent' }
        '^(pin|pinned|favorite|star)$' { return 'pin' }
        '^(unpin|unfavorite|unstar)$' { return 'unpin' }
        '^(alias|add-alias)$' { return 'alias' }
        '^(unalias|remove-alias)$' { return 'unalias' }
        '^(tag|add-tag)$' { return 'tag' }
        '^(untag|remove-tag)$' { return 'untag' }
        '^(clean|repair|fix)$' { return 'clean' }
        '^(add|add-project)$' { return 'add' }
        '^(remove|rm|delete)$' { return 'remove' }
        '^(init|setup)$' { return 'init' }
        '^(scan|import)$' { return 'scan' }
        '^(config|select-config)$' { return 'config' }
        default { return $null }
    }
}

function ConvertFrom-CdpStatusTokens {
    param([string[]]$Tokens, [string]$ConfigPath, [bool]$DryRun, [bool]$Yes)

    $result = New-CdpInvocation -Kind 'status'
    $result.ConfigPath = $ConfigPath
    $result.DryRun = $DryRun
    $result.Yes = $Yes
    for ($i = 0; $i -lt $Tokens.Count; $i++) {
        $token = $Tokens[$i]
        if ($token -in @('--dirty', '-dirty', '-d')) { $result.DirtyOnly = $true; continue }
        if ($token -in @('--fix', '-fix')) { $result.Fix = $true; continue }
        if ($token -in @('--push', '-push')) { $result.Push = $true; continue }
        if ($token -in @('--json', '-json')) { $result.Json = $true; continue }
        if ($token -in @('--no-color', '-no-color')) { $result.NoColor = $true; continue }
        if ($token -in @('--refresh', '-refresh')) { $result.Refresh = $true; continue }
        if ($token -in @('--jobs', '-jobs', '--concurrency')) {
            if ($i + 1 -ge $Tokens.Count) { throw "Missing value after --jobs." }
            $jobs = 0
            if (-not [int]::TryParse($Tokens[++$i], [ref]$jobs) -or $jobs -lt 1 -or $jobs -gt 16) {
                throw "Status jobs must be an integer between 1 and 16."
            }
            $result.ThrottleLimit = $jobs
            continue
        }
        if ($token -in @('--dry-run', '-dry-run')) { $result.DryRun = $true; continue }
        if ($token -in @('--yes', '-yes')) { $result.Yes = $true; continue }
        if ($token.StartsWith('@')) {
            if ($result.TagFilter) { throw "Only one status tag filter can be specified." }
            $result.TagFilter = $token
            continue
        }
        if ($token.StartsWith('-')) { throw "Unknown status option: $token" }
        if ($result.ConfigPath) { throw "Only one status config path can be specified." }
        $result.ConfigPath = $token
    }
    if ($result.Fix -and $result.Push) { throw "The --fix and --push actions cannot be used together." }
    if ($result.DirtyOnly -and ($result.Fix -or $result.Push)) { throw "The --dirty filter and status actions cannot be used together." }
    if ($result.Json -and $result.NoColor) { throw "The --json and --no-color options cannot be used together." }
    if ($result.Json -and ($result.Fix -or $result.Push)) { throw "The --json option is only valid for read-only status." }
    if ($result.NoColor -and ($result.Fix -or $result.Push)) { throw "The --no-color option is only valid for read-only status." }
    if ($result.DryRun -and $result.Yes) { throw "The --dry-run and --yes options cannot be used together." }
    if (($result.DryRun -or $result.Yes) -and -not ($result.Fix -or $result.Push)) {
        throw "The --dry-run and --yes options require --fix or --push."
    }
    $result
}

function Split-CdpWorkspaceOptions {
    param([string[]]$Tokens)

    $result = [PSCustomObject]@{ Tokens=@(); Layout=$null; ClearOpen=$false; Fix=$false }
    $items = New-Object 'System.Collections.Generic.List[string]'
    for ($i = 0; $i -lt $Tokens.Count; $i++) {
        if ($Tokens[$i] -in @('--layout', '-layout')) {
            if ($i + 1 -ge $Tokens.Count) { throw 'Missing value after --layout.' }
            if ($result.Layout) { throw 'The --layout option was specified more than once.' }
            $result.Layout = $Tokens[++$i]
        } elseif ($Tokens[$i] -in @('--clear-open', '-clear-open')) { $result.ClearOpen = $true }
        elseif ($Tokens[$i] -in @('--fix', '-fix')) { $result.Fix = $true }
        else { $items.Add($Tokens[$i]) }
    }
    $result.Tokens = @($items)
    $result
}

function Set-CdpWorkspaceReadAction {
    param([object]$Result, [string]$Action, [string[]]$Tokens, [string]$Open, [bool]$DryRun, [bool]$Yes)

    if ($Action -eq 'list') {
        if ($DryRun -or $Yes) { throw 'Workspace --list does not accept safety options.' }
        if ($Open) { throw 'The --open option is not valid with workspace --list.' }
        if ($Tokens.Count -ne 1) { throw 'Workspace --list does not accept project arguments.' }
    } else {
        if ($Tokens.Count -ne 2) { throw "Workspace $Action requires one workspace name." }
        if ($Open -or $Result.WorkspaceLayout -or $Result.ClearOpen -or $Result.Fix) { throw "Workspace $Action does not accept update options." }
        if (($DryRun -or $Yes) -and $Action -eq 'show') { throw 'Workspace show does not accept safety options.' }
        $Result.WorkspaceName = $Tokens[1]
    }
    $Result.WorkspaceAction = $Action
    $Result
}

function Set-CdpWorkspaceValidateAction {
    param([object]$Result, [string[]]$Tokens, [string]$Open, [bool]$DryRun, [bool]$Yes)

    if ($Tokens.Count -gt 2) { throw 'Workspace validate accepts at most one workspace name.' }
    if ($Open -or $Result.WorkspaceLayout -or $Result.ClearOpen) { throw 'Workspace validate does not accept launcher or layout options.' }
    if (($DryRun -or $Yes) -and -not $Result.Fix) { throw 'Workspace validate safety options require --fix.' }
    $Result.WorkspaceAction = 'validate'
    if ($Tokens.Count -eq 2) { $Result.WorkspaceName = $Tokens[1] }
    $Result
}

function Set-CdpWorkspaceWriteAction {
    param([object]$Result, [string]$Action, [string[]]$Tokens, [string]$Open)

    if ($Action -eq 'add') {
        if ($Tokens.Count -lt 3) { throw 'Workspace --add requires a name and at least one project.' }
        if ($Result.ClearOpen -or $Result.Fix) { throw 'Workspace add does not accept --clear-open or --fix.' }
    } else {
        if ($Tokens.Count -lt 2) { throw 'Workspace edit requires one workspace name.' }
        if ($Result.Fix) { throw 'Workspace edit does not accept --fix.' }
        if ($Open -and $Result.ClearOpen) { throw 'Workspace --open and --clear-open cannot be used together.' }
    }
    $Result.WorkspaceAction = $Action
    $Result.WorkspaceName = $Tokens[1]
    $Result.Projects = @($Tokens | Select-Object -Skip 2)
    if ($Action -eq 'edit' -and $Result.Projects.Count -eq 0 -and -not $Open -and -not $Result.ClearOpen -and -not $Result.WorkspaceLayout) {
        throw 'Workspace edit requires projects or an open/layout update.'
    }
    $Result
}

function ConvertFrom-CdpWorkspaceTokens {
    param([string[]]$Tokens, [string]$ConfigPath, [string]$Open, [bool]$DryRun, [bool]$Yes)

    $result = New-CdpInvocation -Kind "workspace"
    $result.ConfigPath = $ConfigPath
    $result.Open = $Open
    $result.DryRun = $DryRun
    $result.Yes = $Yes
    $options = Split-CdpWorkspaceOptions -Tokens $Tokens
    $result.WorkspaceLayout = $options.Layout
    $result.ClearOpen = $options.ClearOpen
    $result.Fix = $options.Fix
    $Tokens = @($options.Tokens)
    if ($Tokens.Count -eq 0) {
        if ($DryRun -or $Yes) { throw "Workspace safety options require --add or a workspace name." }
        if ($Open) { throw "The --open option requires a workspace name or --add action." }
        $result.WorkspaceAction = "usage"
        return $result
    }
    $action = $Tokens[0].ToLowerInvariant()
    if ($action -in @("--list", "-l", "list")) { return Set-CdpWorkspaceReadAction $result list $Tokens $Open $DryRun $Yes }
    if ($action -in @("show", "remove")) { return Set-CdpWorkspaceReadAction $result $action $Tokens $Open $DryRun $Yes }
    if ($action -eq "validate") { return Set-CdpWorkspaceValidateAction $result $Tokens $Open $DryRun $Yes }
    if ($action -in @("--add", "-a", "add")) { return Set-CdpWorkspaceWriteAction $result add $Tokens $Open }
    if ($action -eq "edit") { return Set-CdpWorkspaceWriteAction $result edit $Tokens $Open }
    if ($action -eq "open") {
        if ($Tokens.Count -ne 2) { throw "Workspace open requires one workspace name." }
        if ($result.WorkspaceLayout -or $result.ClearOpen -or $result.Fix) { throw "Workspace open does not accept layout/update options." }
        $result.WorkspaceAction = "open"
        $result.WorkspaceName = $Tokens[1]
        return $result
    }
    if ($Tokens.Count -ne 1) { throw "Workspace launch accepts one workspace name." }
    if ($Tokens[0].StartsWith("-")) { throw "Unknown workspace option: $($Tokens[0])" }
    if ($result.WorkspaceLayout -or $result.ClearOpen -or $result.Fix) { throw "Workspace launch does not accept layout/update options." }
    $result.WorkspaceAction = "open"
    $result.WorkspaceName = $Tokens[0]
    $result
}

function Set-CdpTrailingConfigPath {
    param([object]$Result, [string[]]$Arguments, [int]$RequiredCount)

    if ($Arguments.Count -lt $RequiredCount -or $Arguments.Count -gt ($RequiredCount + 1)) {
        throw "Invalid arguments for cdp $($Result.Kind)."
    }
    if ($Arguments.Count -eq ($RequiredCount + 1)) {
        if ($Result.ConfigPath) { throw "The config path was specified more than once." }
        $Result.ConfigPath = $Arguments[-1]
    }
}

function ConvertFrom-CdpManagementTokens {
    param([string]$Kind, [string[]]$Tokens, [string]$ConfigPath, [bool]$DryRun, [bool]$Yes)

    $result = New-CdpInvocation -Kind $Kind
    $result.ConfigPath = $ConfigPath
    $result.DryRun = $DryRun
    $result.Yes = $Yes
    if ($Kind -eq 'doctor') {
        $items = @($Tokens | Where-Object { if ($_ -in @('--fix', '-fix')) { $result.Fix = $true; $false } else { $true } })
        Set-CdpTrailingConfigPath -Result $result -Arguments $items -RequiredCount 0
    } elseif ($Kind -eq 'hook') {
        if ($Tokens.Count -lt 1) { throw "Hook requires list, trust, or revoke." }
        $result.HookAction = $Tokens[0].ToLowerInvariant()
        if ($result.HookAction -notin @('list', 'trust', 'revoke')) { throw "Unknown hook action." }
        if ($result.HookAction -eq 'list') {
            Set-CdpTrailingConfigPath -Result $result -Arguments @($Tokens | Select-Object -Skip 1) -RequiredCount 0
        } else {
            Set-CdpTrailingConfigPath -Result $result -Arguments @($Tokens | Select-Object -Skip 1) -RequiredCount 1
            $result.Name = $Tokens[1]
        }
    } elseif ($Kind -in @('about', 'clean')) {
        Set-CdpTrailingConfigPath -Result $result -Arguments $Tokens -RequiredCount 0
    } elseif ($Kind -eq 'config') {
        if ($Tokens.Count -gt 1) { throw "Config selection accepts one numeric selection." }
        if ($Tokens.Count -eq 1) {
            $selection = 0
            if (-not [int]::TryParse($Tokens[0], [ref]$selection) -or $selection -lt 1) {
                throw "Config selection must be a positive integer."
            }
            $result.Count = $selection
        } else {
            $result.Count = 0
        }
    } elseif ($Kind -eq 'recent') {
        if ($Tokens.Count -gt 1) { throw "Recent count must be a positive integer." }
        if ($Tokens.Count -eq 1) {
            $recentCount = 0
            if (-not [int]::TryParse($Tokens[0], [ref]$recentCount)) { throw "Recent count must be a positive integer." }
            $result.Count = $recentCount
        }
        if ($result.Count -le 0) { throw "Recent count must be a positive integer." }
    } elseif ($Kind -in @('pin', 'unpin', 'remove')) {
        Set-CdpTrailingConfigPath -Result $result -Arguments $Tokens -RequiredCount 1
        $result.Name = $Tokens[0]
    } elseif ($Kind -eq 'add') {
        if ($Tokens.Count -gt 3) { throw "Add accepts a name, path, and optional config path." }
        if ($Tokens.Count -gt 0) { $result.Name = $Tokens[0] }
        if ($Tokens.Count -gt 1) { $result.RootPath = $Tokens[1] }
        if ($Tokens.Count -gt 2) {
            if ($result.ConfigPath) { throw "The config path was specified more than once." }
            $result.ConfigPath = $Tokens[2]
        }
    } elseif ($Kind -in @('alias', 'unalias', 'tag', 'untag')) {
        Set-CdpTrailingConfigPath -Result $result -Arguments $Tokens -RequiredCount 2
        $result.Name = $Tokens[0]
        $result.Value = $Tokens[1]
    } else {
        $result = ConvertFrom-CdpScanTokens -Kind $Kind -Tokens $Tokens -ConfigPath $ConfigPath
    }
    $result.DryRun = $DryRun
    $result.Yes = $Yes
    $isMutation = $Kind -in @('clean', 'add', 'remove', 'pin', 'unpin', 'alias', 'unalias', 'tag', 'untag', 'init', 'scan', 'config')
    if ($Kind -eq 'doctor') { $isMutation = $result.Fix }
    if ($Kind -eq 'hook') { $isMutation = $result.HookAction -in @('trust', 'revoke') }
    if (($DryRun -or $Yes) -and -not $isMutation) {
        throw "Safety options are only valid for mutating commands."
    }
    $result
}

function ConvertFrom-CdpScanTokens {
    param([string]$Kind, [string[]]$Tokens, [string]$ConfigPath)

    $result = New-CdpInvocation -Kind $Kind
    $result.ConfigPath = $ConfigPath
    if ($Tokens.Count -gt 0) { $result.RootPath = $Tokens[0] }
    $depthSet = $false
    foreach ($token in @($Tokens | Select-Object -Skip 1)) {
        $depth = 0
        if ([int]::TryParse($token, [ref]$depth)) {
            if ($depthSet -or $depth -lt 1) { throw "Max depth must be one positive integer." }
            $result.MaxDepth = $depth
            $depthSet = $true
        } elseif (-not $result.ConfigPath) {
            $result.ConfigPath = $token
        } else {
            throw "The config path was specified more than once."
        }
    }
    $result
}

function ConvertFrom-CdpSwitchTokens {
    param([string[]]$Tokens, [string]$Query, [string]$ConfigPath, [string]$Open, [bool]$AllowHook, [bool]$NoHook, [bool]$DryRun, [bool]$Yes)

    if ($DryRun -or $Yes) { throw "Safety options are not valid for project switching." }

    $result = New-CdpInvocation -Kind 'switch'
    $result.Query = $Query
    $result.ConfigPath = $ConfigPath
    $result.Open = $Open
    $result.AllowHook = $AllowHook
    $result.NoHook = $NoHook
    $items = @($Tokens)
    if ([string]::IsNullOrWhiteSpace($result.Query) -and $items.Count -gt 0 -and -not (Test-CdpConfigPathArgument $items[0])) {
        $result.Query = $items[0]
        $items = @($items | Select-Object -Skip 1)
    }
    if ($items.Count -gt 1) { throw "Project switching accepts one query and one config path." }
    if ($items.Count -eq 1) {
        if ($items[0].StartsWith('-')) { throw "Unknown cdp option: $($items[0])" }
        if ($result.ConfigPath) { throw "The config path was specified more than once." }
        $result.ConfigPath = $items[0]
    }
    $result
}

function ConvertFrom-CdpInvokeArguments {
    param([string]$Command, [string]$ConfigPath, [string]$Query, [string]$Open, [string[]]$RemainingArgs)

    $tokens = @(Get-CdpInvocationTokens -Command $Command -ConfigPath $ConfigPath -RemainingArgs $RemainingArgs)
    $common = Split-CdpCommonOptions -Tokens $tokens -Open $Open
    $tokens = @($common.Tokens)
    $kind = if ($tokens.Count -gt 0) { Resolve-CdpCommandKind -Command $tokens[0] } else { $null }
    if ($kind -eq 'hook' -and
        ($tokens.Count -lt 2 -or $tokens[1].ToLowerInvariant() -notin @('list', 'trust', 'revoke'))) {
        $kind = $null
    }
    if ($kind) { $tokens = @($tokens | Select-Object -Skip 1) }

    if ($kind -eq 'status') {
        if ($common.Open) { throw "The --open option is not valid for status." }
        if ($common.AllowHook -or $common.NoHook) { throw "Hook options are only valid for project switching." }
        return ConvertFrom-CdpStatusTokens -Tokens $tokens -ConfigPath $common.ConfigPath -DryRun $common.DryRun -Yes $common.Yes
    }
    if ($kind -eq 'workspace') {
        if ($common.AllowHook -or $common.NoHook) { throw "Hook options are only valid for project switching." }
        return ConvertFrom-CdpWorkspaceTokens -Tokens $tokens -ConfigPath $common.ConfigPath -Open $common.Open -DryRun $common.DryRun -Yes $common.Yes
    }
    if ($kind) {
        if ($common.Open) { throw "The --open option is only valid for project and workspace commands." }
        if ($common.AllowHook -or $common.NoHook) { throw "Hook options are only valid for project switching." }
        return ConvertFrom-CdpManagementTokens -Kind $kind -Tokens $tokens -ConfigPath $common.ConfigPath -DryRun $common.DryRun -Yes $common.Yes
    }
    ConvertFrom-CdpSwitchTokens `
        -Tokens $tokens `
        -Query $Query `
        -ConfigPath $common.ConfigPath `
        -Open $common.Open `
        -AllowHook $common.AllowHook `
        -NoHook $common.NoHook `
        -DryRun $common.DryRun `
        -Yes $common.Yes
}
