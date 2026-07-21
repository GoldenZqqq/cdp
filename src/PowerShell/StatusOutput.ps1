# cdp PowerShell domain: StatusOutput.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function Get-CdpStatusCode {
    param([Parameter(Mandatory = $true)][object]$Info)

    if ($Info.StatusLabel -eq 'path profile invalid') { return 'path_profile_invalid' }
    if (-not $Info.PathExists) { return 'path_missing' }
    if ($Info.StatusLabel -eq 'status timed out') { return 'scan_timeout' }
    if ($Info.StatusLabel -eq 'status failed') { return 'scan_failed' }
    if (-not $Info.IsGitRepo) { return 'not_git' }
    if ($Info.DirtyCount -gt 0 -or $Info.UntrackedCount -gt 0) { return 'changed' }
    'clean'
}

function Get-CdpStatusAttentionReasons {
    param([Parameter(Mandatory = $true)][object]$Info)

    $reasons = @()
    if ($Info.StatusLabel -eq 'path profile invalid') { $reasons += 'path_profile_invalid' }
    elseif (-not $Info.PathExists) { $reasons += 'path_missing' }
    if ($Info.StatusLabel -eq 'status timed out') { $reasons += 'scan_timeout' }
    if ($Info.StatusLabel -eq 'status failed') { $reasons += 'scan_failed' }
    if ($Info.DirtyCount -gt 0) { $reasons += 'dirty' }
    if ($Info.UntrackedCount -gt 0) { $reasons += 'untracked' }
    if ($Info.BehindCount -gt 0) { $reasons += 'behind' }
    if ($Info.PSObject.Properties['Freshness'] -and $Info.Freshness -eq 'fetch-failed') { $reasons += 'fetch_failed' }
    @($reasons)
}

function Get-CdpStatusError {
    param([Parameter(Mandatory = $true)][object]$Info)

    if ($Info.StatusLabel -eq 'status timed out') {
        return [PSCustomObject]@{ code = 'scan_timeout'; message = 'Git status scan timed out.' }
    }
    if ($Info.StatusLabel -eq 'status failed') {
        return [PSCustomObject]@{ code = 'scan_failed'; message = 'Git status scan failed.' }
    }
    if ($Info.PSObject.Properties['Freshness'] -and $Info.Freshness -eq 'fetch-failed') {
        return [PSCustomObject]@{ code = 'fetch_failed'; message = [string]$Info.FetchMessage }
    }
    $null
}

function ConvertTo-CdpStatusProject {
    param([Parameter(Mandatory = $true)][object]$Info)

    $branch = if ([string]::IsNullOrWhiteSpace([string]$Info.Branch)) { $null } else { [string]$Info.Branch }
    $lastCommit = if ([string]::IsNullOrWhiteSpace([string]$Info.LastCommitRelative)) { $null } else { [string]$Info.LastCommitRelative }
    $resolvedPath = if ($Info.PSObject.Properties['ResolvedPath']) { [string]$Info.ResolvedPath } else { [string]$Info.RootPath }
    $freshness = if ($Info.PSObject.Properties['Freshness']) { [string]$Info.Freshness } else { 'not-applicable' }
    [PSCustomObject]@{
        name = [string]$Info.Name
        rawPath = [string]$Info.RootPath
        resolvedPath = $resolvedPath
        pathExists = [bool]$Info.PathExists
        status = Get-CdpStatusCode -Info $Info
        needsAttention = [bool]$Info.NeedsAttention
        attentionReasons = @(Get-CdpStatusAttentionReasons -Info $Info)
        error = Get-CdpStatusError -Info $Info
        git = [PSCustomObject]@{
            isRepository = [bool]$Info.IsGitRepo
            branch = $branch
            dirtyCount = [int]$Info.DirtyCount
            untrackedCount = [int]$Info.UntrackedCount
            aheadCount = [int]$Info.AheadCount
            behindCount = [int]$Info.BehindCount
            lastCommitRelative = $lastCommit
            upstream = if ($Info.PSObject.Properties['Upstream']) { [string]$Info.Upstream } else { '' }
            remoteName = if ($Info.PSObject.Properties['RemoteName']) { [string]$Info.RemoteName } else { '' }
            remoteRef = if ($Info.PSObject.Properties['RemoteRef']) { [string]$Info.RemoteRef } else { '' }
            remoteUrl = if ($Info.PSObject.Properties['RemoteUrl']) { [string]$Info.RemoteUrl } else { '' }
            headOid = if ($Info.PSObject.Properties['HeadOid']) { [string]$Info.HeadOid } else { '' }
            freshness = $freshness
            fetchAttempted = [bool]($Info.PSObject.Properties['FetchAttempted'] -and $Info.FetchAttempted)
            fetchSucceeded = if ($Info.PSObject.Properties['FetchSucceeded']) { $Info.FetchSucceeded } else { $null }
            fetchTimedOut = [bool]($Info.PSObject.Properties['FetchTimedOut'] -and $Info.FetchTimedOut)
            fetchMessage = if ($Info.PSObject.Properties['FetchMessage']) { [string]$Info.FetchMessage } else { '' }
        }
    }
}

function Get-CdpStatusJsonExitCode {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Projects)

    if (@($Projects | Where-Object { $null -ne $_.Error }).Count -gt 0) { return 2 }
    if (@($Projects | Where-Object { $_.NeedsAttention }).Count -gt 0) { return 1 }
    0
}

function New-CdpStatusDocument {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$AllStatus,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$VisibleStatus,
        [Parameter(Mandatory = $true)][int]$DurationMs,
        [switch]$DirtyOnly,
        [string]$TagFilter,
        [switch]$Refresh,
        [switch]$Fetch
    )

    $projects = @($VisibleStatus | ForEach-Object { ConvertTo-CdpStatusProject -Info $_ })
    $exitCode = Get-CdpStatusJsonExitCode -Projects $projects
    [PSCustomObject]@{
        schemaVersion = 1
        generatedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        durationMs = $DurationMs
        filters = [PSCustomObject]@{
            dirtyOnly = [bool]$DirtyOnly
            tag = if ([string]::IsNullOrWhiteSpace($TagFilter)) { $null } else { $TagFilter }
            refresh = [bool]$Refresh
            fetch = [bool]$Fetch
        }
        summary = [PSCustomObject]@{
            total = $AllStatus.Count
            shown = $projects.Count
            attention = @($projects | Where-Object { $_.needsAttention }).Count
            partialFailures = @($projects | Where-Object { $null -ne $_.error }).Count
            exitCode = $exitCode
        }
        projects = $projects
    }
}

function Write-CdpStatusJson {
    param([Parameter(Mandatory = $true)][object]$Document)

    try {
        $json = $Document | ConvertTo-Json -Depth 7 -ErrorAction Stop
    } catch {
        [Console]::Error.WriteLine('Error: Failed to serialize status JSON.')
        $global:LASTEXITCODE = 3
        return
    }
    $global:LASTEXITCODE = [int]$Document.Summary.ExitCode
    Write-Output $json
}

function Get-CdpPlainStatusRow {
    param([Parameter(Mandatory = $true)][object]$Info)

    $sync = @()
    if ($Info.AheadCount -gt 0) { $sync += "^$($Info.AheadCount)" }
    if ($Info.BehindCount -gt 0) { $sync += "v$($Info.BehindCount)" }
    [PSCustomObject]@{
        Branch = if ($Info.IsGitRepo) { [string]$Info.Branch } else { '-' }
        Status = if ($Info.IsGitRepo) { [string]$Info.StatusLabel } else { [string]$Info.StatusLabel }
        Sync = $sync -join ' '
        Source = if ($Info.PSObject.Properties['Freshness']) { [string]$Info.Freshness } else { 'not-applicable' }
    }
}

function Write-CdpPlainStatusTable {
    param(
        [Parameter(Mandatory = $true)][object[]]$StatusList,
        [switch]$DirtyOnly,
        [string]$TagFilter
    )

    $nameWidth = 14
    $branchWidth = 12
    foreach ($item in $StatusList) {
        $nameWidth = [Math]::Min(24, [Math]::Max($nameWidth, (Get-CdpDisplayWidth $item.Name)))
        $branchWidth = [Math]::Min(20, [Math]::Max($branchWidth, (Get-CdpDisplayWidth $item.Branch)))
    }
    $filter = if ($DirtyOnly) { ' (dirty only)' } elseif ($TagFilter) { " ($TagFilter)" } else { '' }
    Write-Host ""
    Write-Host "cdp project status ($($StatusList.Count) projects$filter)"
    Write-Host ('-' * 126)
    Write-Host ("  {0,-4} {1,-$nameWidth} {2,-$branchWidth} {3,-24} {4,-10} {5,-15} {6}" -f '#', 'Project', 'Branch', 'Status', 'Sync', 'Source', 'Last Commit')
    Write-Host ('-' * 126)
    $index = 1
    foreach ($item in $StatusList) {
        $row = Get-CdpPlainStatusRow -Info $item
        $name = Pad-CdpText (Limit-CdpText -Text $item.Name -MaxLength $nameWidth) $nameWidth
        $branch = Pad-CdpText (Limit-CdpText -Text $row.Branch -MaxLength $branchWidth) $branchWidth
        Write-Host ("  {0,-4} {1} {2} {3,-24} {4,-10} {5,-15} {6}" -f ("{0:00}" -f $index), $name, $branch, $row.Status, $row.Sync, $row.Source, $item.LastCommitRelative)
        $index++
    }
    Write-Host ('-' * 126)
    $attention = @($StatusList | Where-Object { $_.NeedsAttention -and $_.IsGitRepo }).Count
    $missing = @($StatusList | Where-Object { -not $_.PathExists }).Count
    $parts = @()
    if ($attention -gt 0) { $parts += "$attention repos need attention" }
    if ($missing -gt 0) { $parts += "$missing path missing" }
    if ($parts.Count -gt 0) { Write-Host ($parts -join ' | ') } else { Write-Host 'All projects clean.' }
}

function Write-CdpStatusFatal {
    param([Parameter(Mandatory = $true)][string]$Message, [switch]$Json)

    if ($Json) {
        [Console]::Error.WriteLine("Error: $Message")
        $global:LASTEXITCODE = 3
    } else {
        Write-Host "Error: $Message" -ForegroundColor Red
    }
}
