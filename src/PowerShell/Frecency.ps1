# cdp PowerShell domain: Frecency.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

$script:CdpFrecencyHistoryLimit = 10000
$script:CdpFrecencyScoreScale = 1000000
$script:CdpSecondsPerDay = 86400
$script:CdpUnixEpochTicks = 621355968000000000

function Test-CdpFrecencyEnabled {
    if ([string]::IsNullOrWhiteSpace($env:CDP_FRECENCY)) { return $true }
    $env:CDP_FRECENCY.Trim().ToLowerInvariant() -notin @('0', 'false', 'off', 'no')
}

function Get-CdpUtcEpoch {
    param([Parameter(Mandatory = $false)][DateTime]$Value = [DateTime]::UtcNow)

    [long][Math]::Floor(
        ($Value.ToUniversalTime().Ticks - $script:CdpUnixEpochTicks) / 10000000
    )
}

function ConvertTo-CdpFrecencyEpoch {
    param([Parameter(Mandatory = $false)][AllowNull()][object]$Value)

    if ($Value -is [DateTimeOffset]) { return Get-CdpUtcEpoch -Value $Value.UtcDateTime }
    if ($Value -is [DateTime]) { return Get-CdpUtcEpoch -Value $Value }
    if ($Value -isnot [string]) { return $null }
    $match = [regex]::Match($Value, '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})')
    if (-not $match.Success) { return $null }

    $timestamp = [DateTime]::MinValue
    $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor
        [Globalization.DateTimeStyles]::AdjustToUniversal
    if (-not [DateTime]::TryParseExact(
        $match.Groups[1].Value,
        "yyyy-MM-dd'T'HH:mm:ss",
        [Globalization.CultureInfo]::InvariantCulture,
        $styles,
        [ref]$timestamp
    )) { return $null }
    Get-CdpUtcEpoch -Value $timestamp
}

function ConvertTo-CdpFrecencyVisits {
    param([Parameter(Mandatory = $false)][AllowNull()][object]$Value)

    if ($null -eq $Value) { return $null }
    $numericTypes = @(
        [TypeCode]::Byte, [TypeCode]::SByte, [TypeCode]::Int16,
        [TypeCode]::UInt16, [TypeCode]::Int32, [TypeCode]::UInt32,
        [TypeCode]::Int64, [TypeCode]::UInt64, [TypeCode]::Single,
        [TypeCode]::Double, [TypeCode]::Decimal
    )
    if ([Type]::GetTypeCode($Value.GetType()) -notin $numericTypes) { return $null }
    $number = [double]$Value
    if ([double]::IsNaN($number) -or [double]::IsInfinity($number) -or
        $number -lt 0 -or [Math]::Floor($number) -ne $number) { return $null }
    [long][Math]::Min(1000, [Math]::Max(1, $number))
}

function Get-CdpFrecencyMetric {
    param(
        [Parameter(Mandatory = $true)][object]$RecentProject,
        [Parameter(Mandatory = $true)][long]$NowEpoch
    )

    $last = ConvertTo-CdpFrecencyEpoch -Value $RecentProject.lastVisitedAt
    $visits = ConvertTo-CdpFrecencyVisits -Value $RecentProject.visitCount
    if ($null -eq $last -or $null -eq $visits) {
        return [PSCustomObject]@{ Last = [long]0; Visits = [long]0; Score = [long]0 }
    }
    $ageSeconds = [Math]::Max([long]0, $NowEpoch - $last)
    $ageDays = [long][Math]::Floor($ageSeconds / $script:CdpSecondsPerDay)
    $score = [long][Math]::Floor(
        ($visits * $script:CdpFrecencyScoreScale) / ($ageDays + 1)
    )
    [PSCustomObject]@{ Last = [long]$last; Visits = [long]$visits; Score = $score }
}

function Get-CdpFrecencyMap {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$RecentProjects,
        [Parameter(Mandatory = $true)][long]$NowEpoch
    )

    $map = New-Object 'System.Collections.Generic.Dictionary[string,object]' `
        ([StringComparer]::Ordinal)
    foreach ($recent in @($RecentProjects | Select-Object -First $script:CdpFrecencyHistoryLimit)) {
        if ($null -eq $recent -or $recent.rootPath -isnot [string]) { continue }
        $rootPath = [string]$recent.rootPath
        $candidate = Get-CdpFrecencyMetric -RecentProject $recent -NowEpoch $NowEpoch
        if (-not $map.ContainsKey($rootPath)) { $map[$rootPath] = $candidate; continue }
        $current = $map[$rootPath]
        if ($candidate.Last -gt $current.Last -or
            ($candidate.Last -eq $current.Last -and $candidate.Visits -gt $current.Visits)) {
            $map[$rootPath] = $candidate
        }
    }
    $map
}

function Sort-CdpProjectsForDisplay {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Projects,
        [Parameter(Mandatory = $false)][AllowNull()][object]$State,
        [Parameter(Mandatory = $false)][long]$NowEpoch = 0
    )

    if ($NowEpoch -le 0) { $NowEpoch = Get-CdpUtcEpoch }
    if (-not $PSBoundParameters.ContainsKey('State')) { $State = Get-CdpState }
    $recentProjects = [object[]]@()
    if ($null -ne $State -and $null -ne $State.PSObject.Properties['recentProjects'] -and
        $State.recentProjects -is [System.Array]) {
        $recentProjects = (ConvertTo-CdpJsonArrayValue -Value $State.recentProjects).Value
    }
    $history = Get-CdpFrecencyMap -RecentProjects $recentProjects -NowEpoch $NowEpoch
    $enabled = Test-CdpFrecencyEnabled
    $ranked = for ($index = 0; $index -lt $Projects.Count; $index++) {
        $project = $Projects[$index]
        $metric = [PSCustomObject]@{ Last = [long]0; Visits = [long]0; Score = [long]0 }
        if ($enabled -and $project.rootPath -is [string] -and $history.ContainsKey($project.rootPath)) {
            $metric = $history[$project.rootPath]
        }
        [PSCustomObject]@{
            Project = $project; Index = $index
            PinRank = if (Test-CdpProjectPinned -Project $project) { 0 } else { 1 }
            Score = $metric.Score; Last = $metric.Last; Visits = $metric.Visits
        }
    }
    @($ranked | Sort-Object -Property `
        @{ Expression = 'PinRank'; Ascending = $true },
        @{ Expression = 'Score'; Descending = $true },
        @{ Expression = 'Last'; Descending = $true },
        @{ Expression = 'Visits'; Descending = $true },
        @{ Expression = 'Index'; Ascending = $true } |
        ForEach-Object { $_.Project })
}
