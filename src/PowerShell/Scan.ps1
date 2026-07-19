# cdp PowerShell domain: Scan.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function Initialize-Cdp {
    <#
    .SYNOPSIS
        Initialize cdp for first-time use.

    .DESCRIPTION
        Creates the default cdp config if needed, saves it as the active config,
        checks fzf availability, and optionally scans a root directory for Git
        repositories.
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$RootPath,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 4,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Join-Path (Get-CdpUserHome) ".cdp\projects.json"
    }

    $initDetails = [PSCustomObject]@{
        ConfigPath = $ConfigPath
        FzfFound = $null -ne (Resolve-CdpFzfCommand)
        ScanResult = $null
    }
    if (-not $PSCmdlet.ShouldProcess($ConfigPath, 'Initialize cdp configuration and active selection')) {
        if ($PassThru) {
            $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
            return New-CdpActionResult -Action 'initialize-cdp' -Target $ConfigPath -Status $status -Changed $false -Details $initDetails
        }
        return
    }

    Initialize-ConfigFile -ConfigPath $ConfigPath
    Save-ConfigChoice -ConfigPath $ConfigPath

    $fzfFound = $null -ne (Resolve-CdpFzfCommand)
    Write-CdpBrandHeader
    Write-Host "Config: $ConfigPath" -ForegroundColor Cyan
    Write-Host "Saved active config choice." -ForegroundColor Green
    if ($fzfFound) {
        Write-Host "fzf: found" -ForegroundColor Green
    } else {
        Write-Host "fzf: not found. Install with winget install fzf" -ForegroundColor Yellow
    }

    $scanResult = $null
    if (-not [string]::IsNullOrWhiteSpace($RootPath)) {
        $scanResult = Import-GitProjects -RootPath $RootPath -ConfigPath $ConfigPath -MaxDepth $MaxDepth -PassThru -Confirm:$false
    }

    if ($PassThru) {
        $initDetails.FzfFound = $fzfFound
        $initDetails.ScanResult = $scanResult
        return New-CdpActionResult -Action 'initialize-cdp' -Target $ConfigPath -Status 'succeeded' -Changed $true -Details $initDetails
    }
}

function Get-CdpComparablePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    } catch {
        try {
            return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
        } catch {
            return $Path.TrimEnd('\', '/')
        }
    }
}

function Get-CdpUniqueProjectName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$ExistingNames
    )

    $baseName = Split-Path -Leaf $Path
    if (-not $ExistingNames.Contains($baseName)) {
        return $baseName
    }

    $parentPath = Split-Path -Parent $Path
    $parentName = Split-Path -Leaf $parentPath
    $candidateRoot = if ([string]::IsNullOrWhiteSpace($parentName)) {
        $baseName
    } else {
        "$parentName-$baseName"
    }

    $candidate = $candidateRoot
    $index = 2
    while ($ExistingNames.Contains($candidate)) {
        $candidate = "$candidateRoot-$index"
        $index++
    }

    $candidate
}

function Get-CdpGitRepositoryRoots {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 4
    )

    $resolvedRoot = (Resolve-Path -LiteralPath $RootPath -ErrorAction Stop).Path

    function Search-GitRepository {
        param(
            [string]$Path,
            [int]$Depth
        )

        if (Test-Path -LiteralPath (Join-Path $Path '.git')) {
            [PSCustomObject]@{ Path = $Path }
            return
        }

        if ($Depth -le 0) {
            return
        }

        Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne '.git' } |
            ForEach-Object { Search-GitRepository -Path $_.FullName -Depth ($Depth - 1) }
    }

    @((Search-GitRepository -Path $resolvedRoot -Depth $MaxDepth) |
        Sort-Object -Property Path -Unique)
}

function Import-GitProjects {
    <#
    .SYNOPSIS
        Scan Git repositories and import them into the project list.

    .DESCRIPTION
        Finds directories containing a .git entry under the target root path and
        appends missing repositories to the active cdp configuration.

    .PARAMETER RootPath
        Directory to scan. Defaults to the current directory.

    .PARAMETER ConfigPath
        Optional custom path to projects.json file.

    .PARAMETER MaxDepth
        Maximum directory depth to scan under RootPath. Defaults to 4.

    .PARAMETER PassThru
        Returns a summary object for tests and scripting.

    .EXAMPLE
        cdp-scan E:\Projects
        # Imports Git repositories below E:\Projects
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RootPath,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 4,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        $RootPath = (Get-Location).Path
    }

    $resolvedRoot = Resolve-Path -LiteralPath $RootPath -ErrorAction SilentlyContinue
    if (-not $resolvedRoot) {
        Write-Host "Error: Invalid scan path." -ForegroundColor Red
        return
    }

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    try {
        $document = Read-CdpJsonArrayMutationDocument -LiteralPath $ConfigPath
        $parsedProjects = $document.Value
        $projects = @()
        if ($null -ne $parsedProjects) {
            $projects = @($parsedProjects)
        }
        $repos = @(Get-CdpGitRepositoryRoots -RootPath $resolvedRoot.Path -MaxDepth $MaxDepth)
    } catch {
        Write-Host "Error: Failed to scan or read configuration." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
        return
    }

    $existingPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $existingNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($project in $projects) {
        $resolution = Resolve-CdpProjectPath -Project $project
        if (-not $resolution.ErrorCode -and -not [string]::IsNullOrWhiteSpace($resolution.ResolvedPath)) {
            [void]$existingPaths.Add((Get-CdpComparablePath -Path $resolution.ResolvedPath))
        }
        if (-not [string]::IsNullOrWhiteSpace($project.name)) {
            [void]$existingNames.Add([string]$project.name)
        }
    }

    $addedProjects = @()
    $skippedCount = 0
    foreach ($repo in $repos) {
        $repoPath = (Get-CdpComparablePath -Path $repo.Path)
        if ($existingPaths.Contains($repoPath)) {
            $skippedCount++
            continue
        }

        $name = Get-CdpUniqueProjectName -Path $repoPath -ExistingNames $existingNames
        $newProject = [PSCustomObject]@{
            name = $name
            rootPath = $repoPath
            enabled = $true
            pinned = $false
            aliases = @()
            tags = @()
            paths = New-CdpProjectPathMap -RootPath $repoPath
        }
        $projects += $newProject
        $addedProjects += $newProject
        [void]$existingPaths.Add($repoPath)
        [void]$existingNames.Add($name)
    }

    Write-Host "Git repositories found: $($repos.Count)" -ForegroundColor Cyan
    Write-Host "Projects added: $($addedProjects.Count)" -ForegroundColor Green
    Write-Host "Projects skipped: $skippedCount" -ForegroundColor Yellow
    Write-Host "Config: $ConfigPath" -ForegroundColor Gray

    $details = [PSCustomObject]@{
        RootPath = $resolvedRoot.Path
        ConfigPath = $ConfigPath
        FoundCount = $repos.Count
        AddedCount = $addedProjects.Count
        SkippedCount = $skippedCount
        AddedProjects = $addedProjects
    }
    if ($addedProjects.Count -eq 0) {
        if ($PassThru) {
            return New-CdpActionResult -Action 'scan-import' -Target $resolvedRoot.Path -Status 'skipped' -Changed $false -Details $details
        }
        return
    }

    if (-not $PSCmdlet.ShouldProcess($ConfigPath, "Import $($addedProjects.Count) repositories found under $($resolvedRoot.Path)")) {
        if ($PassThru) {
            $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
            return New-CdpActionResult -Action 'scan-import' -Target $resolvedRoot.Path -Status $status -Changed $false -Details $details
        }
        return
    }

    try {
        [void](Write-CdpJsonFile -LiteralPath $ConfigPath -Value @($projects) -ExpectedFingerprint $document.Fingerprint)
    } catch {
        Write-Host "Error: Failed to import scanned projects." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
        if ($PassThru) {
            return New-CdpActionResult -Action 'scan-import' -Target $resolvedRoot.Path -Status 'failed' -Changed $false -Error $_.Exception.Message -Details $details
        }
        return
    }

    if ($PassThru) {
        return New-CdpActionResult -Action 'scan-import' -Target $resolvedRoot.Path -Status 'succeeded' -Changed $true -Details $details
    }
}
