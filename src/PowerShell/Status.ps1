# cdp PowerShell domain: Status.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function Get-CdpGitProjectInfo {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Project
    )

    $rootPath = [string]$Project.rootPath
    $info = [PSCustomObject]@{
        Name = [string]$Project.name
        RootPath = $rootPath
        PathExists = $false
        IsGitRepo = $false
        Branch = ""
        Remote = ""
        Upstream = ""
        DirtyCount = 0
        UntrackedCount = 0
        AheadCount = 0
        BehindCount = 0
        LastCommitRelative = ""
        StatusLabel = ""
        NeedsAttention = $false
    }

    if (-not (Test-Path -LiteralPath $rootPath)) {
        $info.StatusLabel = "path missing"
        $info.NeedsAttention = $true
        return $info
    }

    $info.PathExists = $true

    $insideWorkTree = $false
    try {
        $probe = (& git -C $rootPath rev-parse --is-inside-work-tree 2>$null)
        $insideWorkTree = $LASTEXITCODE -eq 0 -and $probe -eq 'true'
    } catch {}
    if (-not $insideWorkTree) {
        $info.StatusLabel = "not a git repo"
        return $info
    }

    $info.IsGitRepo = $true

    try {
        $info.Branch = (& git -C $rootPath branch --show-current 2>$null)
        if ([string]::IsNullOrWhiteSpace($info.Branch)) {
            $info.Branch = (& git -C $rootPath rev-parse --short HEAD 2>$null)
        }
    } catch {}

    try {
        $upstream = (& git -C $rootPath rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($upstream)) {
            $info.Upstream = [string]$upstream
            $separator = $info.Upstream.IndexOf('/')
            if ($separator -gt 0) {
                $info.Remote = $info.Upstream.Substring(0, $separator)
            }
        }
    } catch {}

    try {
        $porcelain = @(& git -C $rootPath status --porcelain 2>$null)
        foreach ($line in $porcelain) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line.Length -ge 2 -and $line.Substring(0, 2) -eq "??") {
                $info.UntrackedCount++
            } else {
                $info.DirtyCount++
            }
        }
    } catch {}

    try {
        $ahead = (& git -C $rootPath rev-list --count "@{u}..HEAD" 2>$null)
        if ($null -ne $ahead) { $info.AheadCount = [int]$ahead }
    } catch {}

    try {
        $behind = (& git -C $rootPath rev-list --count "HEAD..@{u}" 2>$null)
        if ($null -ne $behind) { $info.BehindCount = [int]$behind }
    } catch {}

    try {
        $info.LastCommitRelative = (& git -C $rootPath log -1 --format="%cr" 2>$null)
    } catch {}

    if ($info.DirtyCount -gt 0 -and $info.UntrackedCount -gt 0) {
        $info.StatusLabel = "$($info.DirtyCount) dirty + $($info.UntrackedCount) untracked"
        $info.NeedsAttention = $true
    } elseif ($info.DirtyCount -gt 0) {
        $info.StatusLabel = "$($info.DirtyCount) dirty"
        $info.NeedsAttention = $true
    } elseif ($info.UntrackedCount -gt 0) {
        $info.StatusLabel = "$($info.UntrackedCount) untracked"
        $info.NeedsAttention = $true
    } else {
        $info.StatusLabel = "clean"
    }

    if ($info.BehindCount -gt 0) {
        $info.NeedsAttention = $true
    }

    return $info
}

function Show-CdpProjectStatus {
    <#
    .SYNOPSIS
        Show Git status of all configured projects.

    .DESCRIPTION
        Displays a dashboard view of all enabled projects showing current branch,
        working tree status, ahead/behind counts, and last commit time. Quickly
        answers: which repos have uncommitted changes? Which are behind remote?

    .PARAMETER ConfigPath
        Optional custom path to projects.json file.

    .PARAMETER DirtyOnly
        Only show projects that need attention (dirty, untracked, or behind remote).

    .PARAMETER TagFilter
        Only show projects matching a tag (e.g. '@work').

    .PARAMETER PassThru
        Returns project status objects for scripting.

    .EXAMPLE
        cdp status
        # Shows Git status of all projects

    .EXAMPLE
        cdp status --dirty
        # Only shows projects with uncommitted changes

    .EXAMPLE
        cdp status @work
        # Shows status of projects tagged 'work'
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [Alias('d')]
        [switch]$DirtyOnly,

        [Parameter(Mandatory = $false)]
        [string]$TagFilter,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru,

        [Parameter(Mandatory = $false)]
        [switch]$Fix,

        [Parameter(Mandatory = $false)]
        [switch]$Push
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Error: Configuration file not found at: $ConfigPath" -ForegroundColor Red
        return
    }

    $document = $null
    try {
        if ($Fix) {
            $document = Read-CdpJsonDocument -LiteralPath $ConfigPath
            $enabledProjects = @(@($document.Value) | Where-Object { $_.enabled })
        } else {
            $configData = Get-CdpProjectConfig -ConfigPath $ConfigPath
            $enabledProjects = @($configData.EnabledProjects)
        }
    } catch {
        Write-Host "Error: Failed to read configuration." -ForegroundColor Red
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($TagFilter)) {
        $tagQuery = $TagFilter
        if ($tagQuery.StartsWith('@')) {
            $tagQuery = $tagQuery.Substring(1)
        }
        $comparison = [StringComparison]::OrdinalIgnoreCase
        $enabledProjects = @($enabledProjects | Where-Object {
            @(Get-CdpProjectStringList -Project $_ -PropertyName 'tags') |
                Where-Object { [string]::Equals($_, $tagQuery, $comparison) }
        })
    }

    if ($enabledProjects.Count -eq 0) {
        Write-Host "No projects to check." -ForegroundColor Yellow
        return
    }

    $statusList = @()
    $total = $enabledProjects.Count
    $scanned = 0
    foreach ($project in $enabledProjects) {
        $scanned++
        Write-Host "`r  Scanning $scanned/$total... " -ForegroundColor DarkGray -NoNewline
        $statusList += Get-CdpGitProjectInfo -Project $project
    }
    Write-Host "`r                              `r" -NoNewline

    if ($Fix) {
        $missingProjects = @($statusList | Where-Object { -not $_.PathExists })
        if ($missingProjects.Count -eq 0) {
            Write-Host "`nNo path-missing projects to remove." -ForegroundColor Green
            if ($PassThru) { return @() }
            return
        }
        Write-Host "`nRemoving $($missingProjects.Count) path-missing projects:" -ForegroundColor Yellow
        foreach ($proj in $missingProjects) {
            Write-Host "  x $($proj.Name)" -ForegroundColor DarkGray -NoNewline
            Write-Host "  $($proj.RootPath)" -ForegroundColor DarkGray
        }
        $resolvedConfig = if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) { $ConfigPath } else { Get-DefaultConfigPath }
        if (-not $PSCmdlet.ShouldProcess($resolvedConfig, "Remove $($missingProjects.Count) missing project entries")) {
            if ($PassThru) {
                $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
                return @($missingProjects | ForEach-Object {
                    New-CdpActionResult -Action 'status-fix' -Target ([string]$_.Name) -Status $status -Changed $false -Details $_
                })
            }
            return
        }
        $allProjects = $document.Value
        $missingPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($project in $missingProjects) {
            [void]$missingPaths.Add((Get-CdpComparablePath -Path $project.RootPath))
        }
        $cleaned = @(@($allProjects) | Where-Object {
            $_.enabled -ne $true -or
                -not $missingPaths.Contains((Get-CdpComparablePath -Path ([string]$_.rootPath)))
        })
        try {
            [void](Write-CdpJsonFile -LiteralPath $resolvedConfig -Value @($cleaned) -ExpectedFingerprint $document.Fingerprint)
        } catch {
            $errorMessage = $_.Exception.Message
            Write-Host "`nFailed to remove missing projects: $errorMessage" -ForegroundColor Red
            if ($PassThru) {
                return @($missingProjects | ForEach-Object {
                    New-CdpActionResult -Action 'status-fix' -Target ([string]$_.Name) -Status 'failed' -Changed $false -Error $errorMessage -Details $_
                })
            }
            throw
        }
        Write-Host "`nRemoved $($missingProjects.Count) projects. $($cleaned.Count) projects remain." -ForegroundColor Green
        if ($PassThru) {
            return @($missingProjects | ForEach-Object {
                New-CdpActionResult -Action 'status-fix' -Target ([string]$_.Name) -Status 'succeeded' -Changed $true -Details $_
            })
        }
        return
    }

    if ($Push) {
        $aheadProjects = @($statusList | Where-Object { $_.AheadCount -gt 0 -and $_.IsGitRepo })
        if ($aheadProjects.Count -eq 0) {
            Write-Host "`nNo repos ahead of remote." -ForegroundColor Green
            if ($PassThru) { return @() }
            return
        }
        Write-Host "`nPushing $($aheadProjects.Count) repos ahead of remote:" -ForegroundColor Yellow
        $pushResults = @()
        $pushFailed = $false
        foreach ($proj in $aheadProjects) {
            $upstreamLabel = if ($proj.Upstream) { "remote=$($proj.Remote), upstream=$($proj.Upstream)" } else { 'configured upstream' }
            Write-Host "  $($proj.Name) (^$($proj.AheadCount), $upstreamLabel)" -ForegroundColor Cyan
            if (-not $PSCmdlet.ShouldProcess("$($proj.Name) [$upstreamLabel]", 'Push commits to configured upstream')) {
                $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
                $pushResults += New-CdpActionResult -Action 'status-push' -Target ([string]$proj.Name) -Status $status -Changed $false -Details $proj
                continue
            }
            Write-Host "    running... " -ForegroundColor DarkGray -NoNewline
            try {
                $pushOutput = @(& git -C $proj.RootPath push --porcelain 2>&1)
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "done" -ForegroundColor Green
                    $pushResults += New-CdpActionResult -Action 'status-push' -Target ([string]$proj.Name) -Status 'succeeded' -Changed $true -Details $proj
                } else {
                    $failure = @($pushOutput | Select-Object -Last 1) -join ''
                    Write-Host "failed: $failure" -ForegroundColor Red
                    $pushFailed = $true
                    $pushResults += New-CdpActionResult -Action 'status-push' -Target ([string]$proj.Name) -Status 'failed' -Changed $false -Error $failure -Details $proj
                }
            } catch {
                Write-Host "failed: $($_.Exception.Message)" -ForegroundColor Red
                $pushFailed = $true
                $pushResults += New-CdpActionResult -Action 'status-push' -Target ([string]$proj.Name) -Status 'failed' -Changed $false -Error $_.Exception.Message -Details $proj
            }
        }
        if ($pushFailed -and -not $PassThru) { $global:LASTEXITCODE = 1 }
        if ($PassThru) { return $pushResults }
        return
    }

    if ($PassThru) {
        if ($DirtyOnly) {
            return @($statusList | Where-Object { $_.NeedsAttention })
        }
        return $statusList
    }

    if ($DirtyOnly) {
        $statusList = @($statusList | Where-Object { $_.NeedsAttention })
    }

    $nameWidth = 14
    foreach ($item in $statusList) {
        $nameWidth = [Math]::Max($nameWidth, (Get-CdpDisplayWidth $item.Name))
    }
    $nameWidth = [Math]::Min($nameWidth, 24)

    $branchWidth = 12
    foreach ($item in $statusList) {
        $bw = Get-CdpDisplayWidth $item.Branch
        if ($bw -gt $branchWidth) {
            $branchWidth = [Math]::Min($bw, 20)
        }
    }

    $filterLabel = if ($DirtyOnly) { " (dirty only)" } elseif (-not [string]::IsNullOrWhiteSpace($TagFilter)) { " ($TagFilter)" } else { "" }
    Write-Host "`ncdp project status " -ForegroundColor Cyan -NoNewline
    Write-Host "($($statusList.Count) projects$filterLabel)" -ForegroundColor DarkGray
    Write-Host ("-" * 110) -ForegroundColor DarkGray

    Write-Host ("  {0,-4} " -f "#") -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-$nameWidth} " -f "Project") -ForegroundColor Cyan -NoNewline
    Write-Host ("{0,-$branchWidth} " -f "Branch") -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-24} " -f "Status") -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-10} " -f "Sync") -ForegroundColor DarkGray -NoNewline
    Write-Host "Last Commit" -ForegroundColor DarkGray
    Write-Host ("-" * 110) -ForegroundColor DarkGray

    $index = 1
    foreach ($item in $statusList) {
        $number = "{0:00}" -f $index
        $displayName = Limit-CdpText -Text $item.Name -MaxLength $nameWidth
        $displayBranch = Limit-CdpText -Text $item.Branch -MaxLength $branchWidth

        Write-Host ("  {0,-4} " -f $number) -ForegroundColor DarkGray -NoNewline
        Write-Host "$(Pad-CdpText $displayName $nameWidth) " -ForegroundColor Green -NoNewline

        if (-not $item.IsGitRepo) {
            Write-Host "$(Pad-CdpText '-' $branchWidth) " -ForegroundColor DarkGray -NoNewline
            $labelColor = if ($item.PathExists) { "DarkGray" } else { "Red" }
            Write-Host $item.StatusLabel -ForegroundColor $labelColor
            $index++
            continue
        }

        Write-Host "$(Pad-CdpText $displayBranch $branchWidth) " -ForegroundColor DarkCyan -NoNewline

        $statusIcon = if ($item.DirtyCount -gt 0) { "x" } elseif ($item.UntrackedCount -gt 0) { "!" } else { "+" }
        $statusColor = if ($item.DirtyCount -gt 0) { "Red" } elseif ($item.UntrackedCount -gt 0) { "Yellow" } else { "Green" }
        $statusText = "$statusIcon $($item.StatusLabel)"
        Write-Host ("{0,-24} " -f $statusText) -ForegroundColor $statusColor -NoNewline

        $syncParts = @()
        if ($item.AheadCount -gt 0) { $syncParts += "^$($item.AheadCount)" }
        if ($item.BehindCount -gt 0) { $syncParts += "v$($item.BehindCount)" }
        $syncText = if ($syncParts.Count -gt 0) { $syncParts -join " " } else { "" }
        $syncColor = if ($item.BehindCount -gt 0) { "Yellow" } elseif ($item.AheadCount -gt 0) { "Cyan" } else { "DarkGray" }
        Write-Host ("{0,-10} " -f $syncText) -ForegroundColor $syncColor -NoNewline

        Write-Host $item.LastCommitRelative -ForegroundColor DarkGray
        $index++
    }

    Write-Host ("-" * 110) -ForegroundColor DarkGray

    $attentionCount = @($statusList | Where-Object { $_.NeedsAttention -and $_.IsGitRepo }).Count
    $missingCount = @($statusList | Where-Object { -not $_.PathExists }).Count
    $summaryParts = @()
    if ($attentionCount -gt 0) { $summaryParts += "$attentionCount repos need attention" }
    if ($missingCount -gt 0) { $summaryParts += "$missingCount path missing" }

    if ($summaryParts.Count -gt 0) {
        Write-Host ($summaryParts -join " | ") -ForegroundColor Yellow
    } else {
        Write-Host "All projects clean." -ForegroundColor Green
    }

    if ($summaryParts.Count -gt 0) {
        Write-Host ""
        if ($missingCount -gt 0) {
            Write-Host "  Tip: cdp status --fix   Remove $missingCount path-missing projects" -ForegroundColor DarkGray
        }
        $aheadCount = @($statusList | Where-Object { $_.AheadCount -gt 0 -and $_.IsGitRepo }).Count
        if ($aheadCount -gt 0) {
            Write-Host "  Tip: cdp status --push  Push $aheadCount repos ahead of remote" -ForegroundColor DarkGray
        }
    }
}

function Invoke-CdpStatusInvocation {
    param([object]$Invocation)

    $parameters = @{
        ConfigPath = $Invocation.ConfigPath
        DirtyOnly = $Invocation.DirtyOnly
        TagFilter = $Invocation.TagFilter
        Fix = $Invocation.Fix
        Push = $Invocation.Push
    }
    if ($Invocation.DryRun) { $parameters.WhatIf = $true }
    if ($Invocation.Yes) { $parameters.Confirm = $false }
    Show-CdpProjectStatus @parameters
}
