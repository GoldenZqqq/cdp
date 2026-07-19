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

Register-ArgumentCompleter -CommandName Invoke-Cdp -ParameterName Command -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $subcommands = @(
        'status', 'doctor', 'about', 'recent', 'add', 'remove', 'pin', 'unpin',
        'alias', 'unalias', 'tag', 'untag', 'clean', 'init', 'scan', 'config', 'workspace', 'hook'
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

$workspaceCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    Get-CdpWorkspaceCompletionValues -CommandAst $commandAst -WordToComplete $wordToComplete |
        Where-Object { $_ -like "$wordToComplete*" } |
        Sort-Object -Unique |
        ForEach-Object { New-CdpCompletionResult -Value $_ }
}
Register-ArgumentCompleter -CommandName Invoke-Cdp -ParameterName ConfigPath -ScriptBlock $workspaceCompleter
Register-ArgumentCompleter -CommandName Invoke-Cdp -ParameterName RemainingArgs -ScriptBlock $workspaceCompleter
Remove-Variable -Name workspaceCompleter -ErrorAction SilentlyContinue
