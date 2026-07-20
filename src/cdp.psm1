<#
.SYNOPSIS
    cdp - A fast project directory switcher for PowerShell.

.DESCRIPTION
    cdp provides a fuzzy-search interface powered by fzf to quickly
    switch between projects. Compatible with Project Manager plugin.

.NOTES
    Name: cdp
    Author: GoldenZqqq
    Version: 2.2.0
    License: MIT
#>

$script:CdpProjectConfigCache = @{}
$script:CdpFzfCommand = $null
$script:CdpStateFingerprint = 'missing'
$script:CdpStateWritable = $true
$script:CdpStatusCache = @{}

$domainRoot = Join-Path $PSScriptRoot 'PowerShell'
$domainFiles = @(
    'Core.ps1',
    'Config.ps1',
    'Paths.ps1',
    'State.ps1',
    'Picker.ps1',
    'Hooks.ps1',
    'Parser.ps1',
    'ProjectMetadata.ps1',
    'Projects.ps1',
    'Scan.ps1',
    'Status.ps1',
    'StatusOutput.ps1',
    'StatusBatch.ps1',
    'WorkspaceLifecycle.ps1',
    'Workspace.ps1',
    'ExecSelection.ps1',
    'ExecOutput.ps1',
    'Exec.ps1',
    'Health.ps1',
    'Commands.ps1',
    'Completion.ps1'
)

foreach ($domainFile in $domainFiles) {
    $domainPath = Join-Path $domainRoot $domainFile
    if (-not (Test-Path -LiteralPath $domainPath -PathType Leaf)) {
        throw "cdp module domain file not found: $domainPath"
    }
    . $domainPath
}

Remove-Variable -Name domainPath, domainFile, domainFiles, domainRoot -ErrorAction SilentlyContinue

# Export module members
Set-Alias -Name cdp -Value Invoke-Cdp
Set-Alias -Name cdp-add -Value Add-Project
Set-Alias -Name cdp-rm -Value Remove-Project
Set-Alias -Name cdp-ls -Value Get-ProjectList
Set-Alias -Name cdp-edit -Value Edit-ProjectConfig
Set-Alias -Name cdp-config -Value Set-ProjectConfig
Set-Alias -Name cdp-doctor -Value Test-ProjectHealth
Set-Alias -Name cdp-scan -Value Import-GitProjects
Set-Alias -Name cdp-recent -Value Get-CdpRecentProjects
Set-Alias -Name cdp-pin -Value Set-ProjectPin
Set-Alias -Name cdp-unpin -Value Clear-ProjectPin
Set-Alias -Name cdp-clean -Value Repair-ProjectConfig
Set-Alias -Name cdp-status -Value Show-CdpProjectStatus
Set-Alias -Name cdp-init -Value Initialize-Cdp
Set-Alias -Name cdp-alias -Value Add-ProjectAlias
Set-Alias -Name cdp-unalias -Value Remove-ProjectAlias
Set-Alias -Name cdp-tag -Value Add-ProjectTag
Set-Alias -Name cdp-untag -Value Remove-ProjectTag

Export-ModuleMember `
    -Function Invoke-Cdp, Switch-Project, Get-ProjectList, Add-Project, Set-ProjectPin, Clear-ProjectPin, Repair-ProjectConfig, Initialize-Cdp, Add-ProjectAlias, Remove-ProjectAlias, Add-ProjectTag, Remove-ProjectTag, Import-GitProjects, Remove-Project, Edit-ProjectConfig, Set-ProjectConfig, Test-ProjectHealth, Show-CdpAbout, Get-CdpRecentProjects, Show-CdpProjectStatus, Invoke-CdpWorkspace `
    -Alias cdp, cdp-add, cdp-rm, cdp-ls, cdp-edit, cdp-config, cdp-doctor, cdp-scan, cdp-recent, cdp-pin, cdp-unpin, cdp-clean, cdp-init, cdp-alias, cdp-unalias, cdp-tag, cdp-untag, cdp-status
