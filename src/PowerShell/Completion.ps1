# PowerShell argument completion registrations for Invoke-Cdp.
function New-CdpCompletionResult {
    param([string]$Value)

    [System.Management.Automation.CompletionResult]::new($Value, $Value, 'ParameterValue', $Value)
}

function Get-CdpWorkspaceCompletionValues {
    param([object]$CommandAst, [string]$WordToComplete)

    $tokens = @($CommandAst.CommandElements | ForEach-Object { $_.Extent.Text.Trim("'`"") })
    $workspaceIndex = [Array]::IndexOf($tokens, 'workspace')
    if ($workspaceIndex -lt 0) { $workspaceIndex = [Array]::IndexOf($tokens, 'ws') }
    if ($workspaceIndex -lt 0) { return @() }
    $arguments = @($tokens | Select-Object -Skip ($workspaceIndex + 1))
    $actions = @('list', 'show', 'add', 'edit', 'remove', 'validate', 'open')
    $previous = if ($arguments.Count -gt 1) { $arguments[-2] } else { '' }
    if ($previous -in @('--open', '-open', '-o')) { return @('code','cursor','codex','claude','gemini') }
    if ($previous -in @('--layout', '-layout')) { return @('tabs','split-horizontal','split-vertical') }
    if ($arguments.Count -le 1) { return $actions + @(Get-CdpWorkspaceCompletionNames) }
    $action = $arguments[0].ToLowerInvariant()
    if ($action -in @('show','remove','validate','open') -and $arguments.Count -le 2) {
        return @(Get-CdpWorkspaceCompletionNames)
    }
    if ($action -in @('add','edit') -and $arguments.Count -ge 2) {
        return @(Get-CdpProjectCompletionNames)
    }
    @()
}

function Get-CdpProjectCompletionNames {
    try {
        $configPath = Get-DefaultConfigPath
        if (-not (Test-Path -LiteralPath $configPath)) { return @() }
        @((Get-CdpProjectConfig -ConfigPath $configPath).EnabledProjects | ForEach-Object { [string]$_.name })
    } catch { @() }
}

function Get-CdpWorkspaceCompletionNames {
    try {
        $path = Get-CdpWorkspacesPath -ConfigPath (Get-DefaultConfigPath)
        if (-not (Test-Path -LiteralPath $path)) { return @() }
        @((Read-CdpWorkspaceDocument -Path $path).Value | ForEach-Object { [string]$_.name })
    } catch { @() }
}

function Get-CdpTagCompletionValues {
    try {
        $configPath = Get-DefaultConfigPath
        if (-not (Test-Path -LiteralPath $configPath)) { return @() }
        @((Get-CdpProjectConfig -ConfigPath $configPath).EnabledProjects | ForEach-Object {
            @(Get-CdpProjectStringList -Project $_ -PropertyName tags)
        } | Sort-Object -Unique | ForEach-Object { "@$_" })
    } catch { @() }
}

function Get-CdpExecCompletionValues {
    param([object]$CommandAst, [string]$WordToComplete)

    $tokens = @($CommandAst.CommandElements | ForEach-Object { $_.Extent.Text.Trim("'`"") })
    $execIndex = [Array]::IndexOf($tokens, 'exec')
    if ($execIndex -lt 0) { $execIndex = [Array]::IndexOf($tokens, 'run') }
    if ($execIndex -lt 0) { return @() }
    $arguments = @($tokens | Select-Object -Skip ($execIndex + 1))
    if ([Array]::IndexOf($arguments, '--') -ge 0) { return @() }
    $previous = if ($arguments.Count -gt 1) { $arguments[-2] } else { '' }
    if ($previous -eq '--workspace') { return @(Get-CdpWorkspaceCompletionNames) }
    if ($previous -eq '--jobs') { return @('1','2','4','8','16') }
    if ($previous -eq '--timeout') { return @('30','60','300','600') }
    $options = @('--workspace','--all','--config','--jobs','--timeout','--fail-fast','--continue','--json','--dry-run','--yes','--')
    $options + @(Get-CdpProjectCompletionNames) + @(Get-CdpTagCompletionValues)
}

function Get-CdpRecentCompletionValues {
    param([object]$CommandAst, [string]$WordToComplete)

    $tokens = @($CommandAst.CommandElements | ForEach-Object { $_.Extent.Text.Trim("'`"") })
    $recentIndex = [Array]::IndexOf($tokens, 'recent')
    if ($recentIndex -lt 0) { return @() }
    $arguments = @($tokens | Select-Object -Skip ($recentIndex + 1))
    if ($arguments.Count -le 1) { return @('reset', '1', '5', '10') }
    if ($arguments[0] -eq 'reset') { return @('--dry-run', '--yes') }
    @()
}

Register-ArgumentCompleter -CommandName Invoke-Cdp -ParameterName Command -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $subcommands = @(
        'status', 'doctor', 'about', 'recent', 'add', 'remove', 'pin', 'unpin',
        'alias', 'unalias', 'tag', 'untag', 'clean', 'init', 'scan', 'config', 'workspace', 'hook', 'exec'
    )

    $completions = @($subcommands | Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) })

    try {
        $configPath = Get-DefaultConfigPath
        if (Test-Path -LiteralPath $configPath) {
            $configData = Get-CdpProjectConfig -ConfigPath $configPath
            $completions += @($configData.EnabledProjects | ForEach-Object {
                $name = [string]$_.name
                if ($name -like "$wordToComplete*") {
                    [System.Management.Automation.CompletionResult]::new($name, $name, 'ParameterValue', $name)
                }
            } | Where-Object { $null -ne $_ })
        }
    } catch {}

    return $completions
}

Register-ArgumentCompleter -CommandName Invoke-Cdp -ParameterName Open -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    @('code', 'cursor', 'codex', 'claude', 'gemini') | Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

$argumentCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $values = @(Get-CdpExecCompletionValues -CommandAst $commandAst -WordToComplete $wordToComplete)
    if ($values.Count -eq 0) {
        $values = @(Get-CdpRecentCompletionValues -CommandAst $commandAst -WordToComplete $wordToComplete)
    }
    if ($values.Count -eq 0) {
        $values = @(Get-CdpWorkspaceCompletionValues -CommandAst $commandAst -WordToComplete $wordToComplete)
    }
    $values |
        Where-Object { $_ -like "$wordToComplete*" } |
        Sort-Object -Unique |
        ForEach-Object { New-CdpCompletionResult -Value $_ }
}
Register-ArgumentCompleter -CommandName Invoke-Cdp -ParameterName ConfigPath -ScriptBlock $argumentCompleter
Register-ArgumentCompleter -CommandName Invoke-Cdp -ParameterName RemainingArgs -ScriptBlock $argumentCompleter
Remove-Variable -Name argumentCompleter -ErrorAction SilentlyContinue
