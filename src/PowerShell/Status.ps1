# cdp PowerShell domain: Status.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function New-CdpGitProjectInfo {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Project
    )
    $resolution = Resolve-CdpProjectPath -Project $Project

    [PSCustomObject]@{
        Name = [string]$Project.name
        RootPath = $resolution.RawPath
        ResolvedPath = $resolution.ResolvedPath
        PathProfile = $resolution.Profile
        PathSource = $resolution.Source
        IsExplicitPath = $resolution.IsExplicit
        PathResolutionError = $resolution.ErrorCode
        PathExists = $false
        IsGitRepo = $false
        Branch = ""
        Remote = ""
        Upstream = ""
        RemoteName = ""
        RemoteRef = ""
        RemoteUrl = ""
        HeadOid = ""
        Freshness = 'not-applicable'
        FetchAttempted = $false
        FetchSucceeded = $null
        FetchTimedOut = $false
        FetchMessage = ""
        DirtyCount = 0
        UntrackedCount = 0
        AheadCount = 0
        BehindCount = 0
        LastCommitRelative = ""
        StatusLabel = ""
        NeedsAttention = $false
    }
}

function ConvertFrom-CdpGitStatusPorcelainV2 {
    param(
        [Parameter(Mandatory = $true)][string[]]$Lines,
        [Parameter(Mandatory = $true)][object]$Info
    )

    $oid = ''
    $head = ''
    foreach ($line in $Lines) {
        if ($line -match '^# branch\.oid (.+)$') { $oid = $matches[1]; continue }
        if ($line -match '^# branch\.head (.+)$') { $head = $matches[1]; continue }
        if ($line -match '^# branch\.upstream (.+)$') {
            $Info.Upstream = $matches[1]
            $separator = $Info.Upstream.IndexOf('/')
            if ($separator -gt 0) {
                $Info.Remote = $Info.Upstream.Substring(0, $separator)
                $Info.RemoteName = $Info.Remote
                $Info.RemoteRef = 'refs/heads/' + $Info.Upstream.Substring($separator + 1)
            }
            continue
        }
        if ($line -match '^# branch\.ab \+(\d+) -(\d+)$') {
            $Info.AheadCount = [int]$matches[1]
            $Info.BehindCount = [int]$matches[2]
            continue
        }
        if ($line.StartsWith('? ')) { $Info.UntrackedCount++; continue }
        if ($line -match '^(1|2|u) ') { $Info.DirtyCount++ }
    }

    if (-not [string]::IsNullOrWhiteSpace($head) -and $head -ne '(detached)') {
        $Info.Branch = $head
    } elseif ($oid -notin @('', '(initial)')) {
        $Info.Branch = $oid.Substring(0, [Math]::Min(7, $oid.Length))
    }
    $oid
}

function Set-CdpGitProjectStatusLabel {
    param([Parameter(Mandatory = $true)][object]$Info)

    if ($Info.DirtyCount -gt 0 -and $Info.UntrackedCount -gt 0) {
        $Info.StatusLabel = "$($Info.DirtyCount) dirty + $($Info.UntrackedCount) untracked"
    } elseif ($Info.DirtyCount -gt 0) {
        $Info.StatusLabel = "$($Info.DirtyCount) dirty"
    } elseif ($Info.UntrackedCount -gt 0) {
        $Info.StatusLabel = "$($Info.UntrackedCount) untracked"
    } else {
        $Info.StatusLabel = 'clean'
    }
    $Info.NeedsAttention = $Info.DirtyCount -gt 0 -or
        $Info.UntrackedCount -gt 0 -or $Info.BehindCount -gt 0 -or
        $Info.Freshness -eq 'fetch-failed'
}

function Get-CdpGitProjectInfo {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Project
    )

    $info = New-CdpGitProjectInfo -Project $Project
    $rootPath = [string]$info.ResolvedPath

    if ($info.PathResolutionError) {
        $info.StatusLabel = 'path profile invalid'
        $info.NeedsAttention = $true
        return $info
    }

    if (-not (Test-Path -LiteralPath $rootPath)) {
        $info.StatusLabel = "path missing"
        $info.NeedsAttention = $true
        return $info
    }

    $info.PathExists = $true

    try {
        $porcelain = @(& git -C $rootPath status --porcelain=v2 --branch --untracked-files=all 2>$null)
        $statusExitCode = $LASTEXITCODE
    } catch {
        $statusExitCode = 1
        $porcelain = @()
    }
    if ($statusExitCode -ne 0) {
        $info.StatusLabel = "not a git repo"
        return $info
    }

    $info.IsGitRepo = $true

    $oid = ConvertFrom-CdpGitStatusPorcelainV2 -Lines $porcelain -Info $info
    $info.HeadOid = $oid
    $info.Freshness = if ($info.Upstream) { 'cached' } else { 'no-upstream' }

    if ($oid -notin @('', '(initial)')) { try {
        $info.LastCommitRelative = (& git -C $rootPath log -1 --format="%cr" 2>$null)
    } catch {} }

    Set-CdpGitProjectStatusLabel -Info $info
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

    .PARAMETER Json
        Writes one schema-versioned JSON document for automation.

    .PARAMETER NoColor
        Writes the human-readable table without color styling.

    .EXAMPLE
        cdp status
        # Shows Git status of all projects

    .EXAMPLE
        cdp status --dirty
        # Only shows projects with uncommitted changes

    .EXAMPLE
        cdp status @work
        # Shows status of projects tagged 'work'

    .EXAMPLE
        cdp status --json
        # Emits status schema version 1 and automation exit codes
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
        [switch]$Push,

        [Parameter(Mandatory = $false)]
        [switch]$Refresh,

        [Parameter(Mandatory = $false)]
        [switch]$Fetch,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 16)]
        [int]$FetchJobs = 4,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 300)]
        [int]$FetchTimeoutSeconds = 15,

        [Parameter(Mandatory = $false)]
        [int]$ThrottleLimit = 0,

        [Parameter(Mandatory = $false)]
        [switch]$Json,

        [Parameter(Mandatory = $false)]
        [switch]$NoColor
    )

    if ($Json -and $NoColor) { Write-CdpStatusFatal -Message 'The -Json and -NoColor options cannot be used together.' -Json; return }
    if ($Json -and ($Fix -or $Push)) { Write-CdpStatusFatal -Message 'The -Json option is only valid for read-only status.' -Json; return }
    if ($NoColor -and ($Fix -or $Push)) { Write-CdpStatusFatal -Message 'The -NoColor option is only valid for read-only status.'; return }
    if ($Json -and $PassThru) { Write-CdpStatusFatal -Message 'The -Json and -PassThru options cannot be used together.' -Json; return }
    if ($NoColor -and $PassThru) { Write-CdpStatusFatal -Message 'The -NoColor and -PassThru options cannot be used together.'; return }
    if ($Fetch -and $Fix) { Write-CdpStatusFatal -Message 'The -Fetch and -Fix options cannot be used together.' -Json:$Json; return }
    if (-not $Fetch -and ($PSBoundParameters.ContainsKey('FetchJobs') -or
        $PSBoundParameters.ContainsKey('FetchTimeoutSeconds'))) {
        Write-CdpStatusFatal -Message 'FetchJobs and FetchTimeoutSeconds require Fetch.' -Json:$Json
        return
    }

    try { [void](Get-CdpCurrentPathProfile) } catch {
        Write-CdpStatusFatal -Message $_.Exception.Message -Json:$Json
        return
    }

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    if (-not (Test-Path $ConfigPath)) {
        Write-CdpStatusFatal -Message "Configuration file not found at: $ConfigPath" -Json:$Json
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
        Write-CdpStatusFatal -Message 'Failed to read configuration.' -Json:$Json
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
        if ($Json) {
            $empty = New-CdpStatusDocument -AllStatus @() -VisibleStatus @() -DurationMs 0 -DirtyOnly:$DirtyOnly -TagFilter $TagFilter -Refresh:$Refresh -Fetch:$Fetch
            Write-CdpStatusJson -Document $empty
        } elseif ($NoColor) { Write-Host 'No projects to check.' }
        else { Write-Host "No projects to check." -ForegroundColor Yellow }
        return
    }

    $total = $enabledProjects.Count
    $forceRefresh = $Refresh -or $Fetch -or $Fix -or $Push
    $workerCount = Resolve-CdpStatusThrottleLimit -Value $ThrottleLimit
    $scanWatch = [Diagnostics.Stopwatch]::StartNew()
    if (-not $Json) {
        if ($NoColor) { Write-Host "`r  Scanning $total projects ($workerCount workers)... " -NoNewline }
        else { Write-Host "`r  Scanning $total projects ($workerCount workers)... " -ForegroundColor DarkGray -NoNewline }
    }
    $statusList = @(Get-CdpGitProjectInfoBatch `
        -Projects $enabledProjects `
        -ThrottleLimit $workerCount `
        -Refresh:$forceRefresh `
        -CollectorScript { param($Project) Get-CdpGitProjectInfo -Project $Project })
    $scanWatch.Stop()
    if (-not $Json) { Write-Host "`r                              `r" -NoNewline }

    $fetchFailedCount = 0
    if ($Fetch -or $Push) {
        foreach ($status in $statusList) {
            if ($status.IsGitRepo) { Update-CdpStatusRemoteIdentity -Info $status }
        }
    }
    if ($Fetch) {
        $fetchResults = @(Invoke-CdpStatusFetchPlan -StatusList $statusList `
            -Jobs $FetchJobs -TimeoutSeconds $FetchTimeoutSeconds)
        $fetchFailedCount = Set-CdpStatusFetchResults -FetchResults $fetchResults
        $script:CdpStatusCache = @{}
    }

    if ($Fix) {
        $invalidPathProjects = @($statusList | Where-Object { $_.PathResolutionError })
        $explicitMissingProjects = @($statusList | Where-Object {
            -not $_.PathResolutionError -and -not $_.PathExists -and $_.IsExplicitPath
        })
        $missingProjects = @($statusList | Where-Object {
            -not $_.PathResolutionError -and -not $_.PathExists -and -not $_.IsExplicitPath
        })
        if ($invalidPathProjects.Count -gt 0) {
            Write-Host "`nKeeping $($invalidPathProjects.Count) projects with invalid path profiles:" -ForegroundColor Yellow
            foreach ($project in $invalidPathProjects) {
                Write-Host "  $($project.Name) -> $($project.PathSource)" -ForegroundColor DarkGray
            }
        }
        if ($explicitMissingProjects.Count -gt 0) {
            Write-Host "`nKeeping $($explicitMissingProjects.Count) projects with unavailable explicit profile paths:" -ForegroundColor Yellow
            foreach ($project in $explicitMissingProjects) {
                Write-Host "  $($project.Name) [$($project.PathProfile)] -> $($project.ResolvedPath)" -ForegroundColor DarkGray
            }
        }
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
        $missingIdentities = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($project in $missingProjects) {
            $identity = "$($project.Name)`0$(Get-CdpComparablePath -Path $project.RootPath)"
            [void]$missingIdentities.Add($identity)
        }
        $cleaned = @(@($allProjects) | Where-Object {
            $identity = "$($_.name)`0$(Get-CdpComparablePath -Path ([string]$_.rootPath))"
            $_.enabled -ne $true -or
                -not $missingIdentities.Contains($identity)
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
        $pushPlan = @(Get-CdpStatusPushPlan -StatusList $statusList)
        if ($pushPlan.Count -eq 0) {
            Write-Host "`nNo eligible repos ahead of their upstream." -ForegroundColor Green
            Write-CdpStatusFetchAggregateError -FailedCount $fetchFailedCount -Cmdlet $PSCmdlet
            if ($PassThru) { return @() }
            return
        }
        $pushResults = @(Invoke-CdpStatusPushPlan -Cmdlet $PSCmdlet -PushPlan $pushPlan -PassThru:$PassThru)
        Write-CdpStatusFetchAggregateError -FailedCount $fetchFailedCount -Cmdlet $PSCmdlet
        if ($PassThru) { return $pushResults }
        return
    }

    $visibleStatus = if ($DirtyOnly) { @($statusList | Where-Object { $_.NeedsAttention }) } else { @($statusList) }
    if ($Json) {
        try {
            $document = New-CdpStatusDocument -AllStatus $statusList -VisibleStatus $visibleStatus `
                -DurationMs ([int][Math]::Round($scanWatch.Elapsed.TotalMilliseconds)) `
                -DirtyOnly:$DirtyOnly -TagFilter $TagFilter -Refresh:$Refresh -Fetch:$Fetch
            Write-CdpStatusJson -Document $document
        } catch {
            Write-CdpStatusFatal -Message 'Failed to build status JSON.' -Json
        }
        return
    }
    if ($NoColor) {
        Write-CdpPlainStatusTable -StatusList $visibleStatus -DirtyOnly:$DirtyOnly -TagFilter $TagFilter
        return
    }
    if ($PassThru) {
        Write-CdpStatusFetchAggregateError -FailedCount $fetchFailedCount -Cmdlet $PSCmdlet
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
    Write-Host ("-" * 126) -ForegroundColor DarkGray

    Write-Host ("  {0,-4} " -f "#") -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-$nameWidth} " -f "Project") -ForegroundColor Cyan -NoNewline
    Write-Host ("{0,-$branchWidth} " -f "Branch") -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-24} " -f "Status") -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-10} " -f "Sync") -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-15} " -f "Source") -ForegroundColor DarkGray -NoNewline
    Write-Host "Last Commit" -ForegroundColor DarkGray
    Write-Host ("-" * 126) -ForegroundColor DarkGray

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
            Write-Host ("{0,-24} " -f $item.StatusLabel) -ForegroundColor $labelColor -NoNewline
            Write-Host ("{0,-10} " -f '') -ForegroundColor DarkGray -NoNewline
            Write-Host $item.Freshness -ForegroundColor DarkGray
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

        $sourceColor = if ($item.Freshness -eq 'fetch-failed') { 'Red' } `
            elseif ($item.Freshness -eq 'refreshed') { 'Green' } else { 'DarkGray' }
        Write-Host ("{0,-15} " -f $item.Freshness) -ForegroundColor $sourceColor -NoNewline

        Write-Host $item.LastCommitRelative -ForegroundColor DarkGray
        $index++
    }

    Write-Host ("-" * 126) -ForegroundColor DarkGray

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
    Write-CdpStatusFetchAggregateError -FailedCount $fetchFailedCount -Cmdlet $PSCmdlet
}

function Invoke-CdpStatusInvocation {
    param([object]$Invocation)

    $parameters = @{
        ConfigPath = $Invocation.ConfigPath
        DirtyOnly = $Invocation.DirtyOnly
        TagFilter = $Invocation.TagFilter
        Fix = $Invocation.Fix
        Push = $Invocation.Push
        Refresh = $Invocation.Refresh
        Fetch = $Invocation.Fetch
        ThrottleLimit = $Invocation.ThrottleLimit
        Json = $Invocation.Json
        NoColor = $Invocation.NoColor
    }
    if ($Invocation.Fetch) {
        $parameters.FetchJobs = $Invocation.FetchJobs
        $parameters.FetchTimeoutSeconds = $Invocation.FetchTimeoutSeconds
    }
    if ($Invocation.DryRun) { $parameters.WhatIf = $true }
    if ($Invocation.Yes) { $parameters.Confirm = $false }
    Show-CdpProjectStatus @parameters
}
