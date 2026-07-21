# cdp PowerShell domain: State.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function Get-CdpStatePath {
    if (-not [string]::IsNullOrWhiteSpace($env:CDP_STATE_PATH)) {
        return [Environment]::ExpandEnvironmentVariables($env:CDP_STATE_PATH)
    }

    Join-Path (Get-CdpUserHome) ".cdp\state.json"
}

function New-CdpState {
    [PSCustomObject]@{
        recentProjects = @()
    }
}

function Get-CdpState {
    $statePath = Get-CdpStatePath
    if (-not (Test-Path -LiteralPath $statePath)) {
        $script:CdpStateFingerprint = 'missing'
        $script:CdpStateWritable = $true
        return New-CdpState
    }

    try {
        $document = Read-CdpJsonDocument -LiteralPath $statePath
        $state = $document.Value

        if ($null -eq $state -or $state -is [array]) {
            $script:CdpStateFingerprint = $document.Fingerprint
            $script:CdpStateWritable = $false
            return New-CdpState
        }

        if ($state.PSObject.Properties.Name -notcontains 'recentProjects') {
            $state | Add-Member -MemberType NoteProperty -Name recentProjects -Value @()
        }

        if ($null -ne $state.recentProjects -and $state.recentProjects -isnot [System.Array]) {
            $script:CdpStateFingerprint = $document.Fingerprint
            $script:CdpStateWritable = $false
            return New-CdpState
        }

        $state.recentProjects = (ConvertTo-CdpJsonArrayValue -Value $state.recentProjects).Value
        $script:CdpStateFingerprint = $document.Fingerprint
        $script:CdpStateWritable = $true
        return $state
    } catch {
        $script:CdpStateFingerprint = Get-CdpFileFingerprint -LiteralPath $statePath
        $script:CdpStateWritable = $false
        return New-CdpState
    }
}

function Save-CdpState {
    param(
        [Parameter(Mandatory = $true)]
        [object]$State
    )

    $statePath = Get-CdpStatePath
    if (-not $script:CdpStateWritable) {
        throw "Refusing to overwrite an invalid cdp state document: $statePath"
    }
    $script:CdpStateFingerprint = Write-CdpJsonFile `
        -LiteralPath $statePath `
        -Value $State `
        -ExpectedFingerprint $script:CdpStateFingerprint
}

function Add-CdpRecentProject {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Project,

        [Parameter(Mandatory = $false)]
        [int]$MaxCount = 20
    )

    try {
        $name = [string]$Project.name
        $rootPath = [string]$Project.rootPath
        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($rootPath)) {
            return
        }

        $state = Get-CdpState
        $recentProjects = @($state.recentProjects)
        $existing = @($recentProjects | Where-Object {
            [string]::Equals([string]$_.rootPath, $rootPath, [StringComparison]::Ordinal)
        }) | Select-Object -First 1

        $visitCount = 1
        if ($null -ne $existing -and $null -ne $existing.visitCount) {
            $visitCount = [int]$existing.visitCount + 1
        }

        $newEntry = [PSCustomObject]@{
            name = $name
            rootPath = $rootPath
            lastVisitedAt = [DateTimeOffset]::UtcNow.ToString("o")
            visitCount = $visitCount
        }
        if ($Project.PSObject.Properties['paths']) {
            $newEntry | Add-Member -NotePropertyName paths -NotePropertyValue $Project.paths
        }

        $state.recentProjects = @(
            @($recentProjects | Where-Object {
                -not [string]::Equals([string]$_.rootPath, $rootPath, [StringComparison]::Ordinal)
            }) + $newEntry |
                Sort-Object -Property @{
                    Expression = {
                        try {
                            [DateTimeOffset]::Parse([string]$_.lastVisitedAt)
                        } catch {
                            [DateTimeOffset]::MinValue
                        }
                    }
                } -Descending |
                Select-Object -First $MaxCount
        )

        Save-CdpState -State $state
    } catch {
        Write-Verbose "Failed to record recent project: $($_.Exception.Message)"
    }
}

function Get-CdpRecentProjects {
    <#
    .SYNOPSIS
        Show recently visited cdp projects.

    .DESCRIPTION
        Lists projects successfully opened through cdp, ordered by most recent
        visit. Recent state is stored separately from project configuration at
        ~/.cdp/state.json.

    .PARAMETER Count
        Maximum number of recent projects to display. Defaults to 10.

    .PARAMETER PassThru
        Returns recent project objects instead of only writing the table.

    .EXAMPLE
        cdp recent
        # Shows recently visited projects
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [int]$Count = 10,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    if ($Count -le 0) {
        $Count = 10
    }

    $state = Get-CdpState
    $recentProjects = @($state.recentProjects |
        Sort-Object -Property @{
            Expression = {
                try {
                    [DateTimeOffset]::Parse([string]$_.lastVisitedAt)
                } catch {
                    [DateTimeOffset]::MinValue
                }
            }
        } -Descending |
        Select-Object -First $Count)

    if ($PassThru) {
        return $recentProjects
    }

    if ($recentProjects.Count -eq 0) {
        Write-Host "No recent projects yet. Switch with cdp first." -ForegroundColor Yellow
        return
    }

    $nameWidth = 14
    foreach ($project in $recentProjects) {
        $projectName = [string]$project.name
        $nameWidth = [Math]::Max($nameWidth, $projectName.Length)
    }
    $nameWidth = [Math]::Min($nameWidth, 30)

    Write-Host "`ncdp recent " -ForegroundColor Cyan -NoNewline
    Write-Host "($($recentProjects.Count) shown)" -ForegroundColor DarkGray
    Write-Host ("-" * 110) -ForegroundColor DarkGray
    Write-Host ("  {0,-4} " -f "#") -ForegroundColor DarkGray -NoNewline
    Write-Host (("{0,-$nameWidth} " -f "Project")) -ForegroundColor Cyan -NoNewline
    Write-Host ("{0,-24} " -f "Last used") -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-7} " -f "Visits") -ForegroundColor DarkGray -NoNewline
    Write-Host "Path" -ForegroundColor DarkGray
    Write-Host ("-" * 110) -ForegroundColor DarkGray

    $index = 1
    foreach ($project in $recentProjects) {
        $number = "{0:00}" -f $index
        $projectName = Limit-CdpText -Text ([string]$project.name) -MaxLength $nameWidth
        $lastVisited = [string]$project.lastVisitedAt
        $visitCount = if ($null -eq $project.visitCount) { 1 } else { [int]$project.visitCount }

        Write-Host ("  {0,-4} " -f $number) -ForegroundColor DarkGray -NoNewline
        Write-Host (("{0,-$nameWidth} " -f $projectName)) -ForegroundColor Green -NoNewline
        Write-Host ("{0,-24} " -f (Limit-CdpText -Text $lastVisited -MaxLength 24)) -ForegroundColor DarkGray -NoNewline
        Write-Host ("{0,-7} " -f $visitCount) -ForegroundColor Cyan -NoNewline
        $resolution = Resolve-CdpProjectPath -Project $project
        $pathText = if ($resolution.ErrorCode) { "<invalid $($resolution.Source)>" } else { $resolution.ResolvedPath }
        Write-Host $pathText -ForegroundColor DarkGray
        $index++
    }

    Write-Host ("-" * 110) -ForegroundColor DarkGray
    Write-Host "state: $(Get-CdpStatePath)" -ForegroundColor DarkGray
}

function Reset-CdpRecentProjects {
    <#
    .SYNOPSIS
        Clear cdp recent-project history.

    .DESCRIPTION
        Replaces only recentProjects in the cdp state document while preserving
        unknown top-level fields. Invalid state is never overwritten.

    .EXAMPLE
        Reset-CdpRecentProjects -WhatIf
        # Previews clearing recent-project history
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    $statePath = Get-CdpStatePath
    $state = Get-CdpState
    if (-not $script:CdpStateWritable) {
        return New-CdpActionResult -Action 'recent-reset' -Target $statePath `
            -Status 'failed' -Changed $false -Error 'invalid-state'
    }
    $recent = (ConvertTo-CdpJsonArrayValue -Value $state.recentProjects).Value
    if ($recent.Count -eq 0) {
        return New-CdpActionResult -Action 'recent-reset' -Target $statePath `
            -Status 'skipped' -Changed $false
    }
    if (-not $PSCmdlet.ShouldProcess($statePath, 'Clear recent project history')) {
        $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
        return New-CdpActionResult -Action 'recent-reset' -Target $statePath `
            -Status $status -Changed $false
    }
    try {
        $state.recentProjects = [object[]]@()
        Save-CdpState -State $state
        New-CdpActionResult -Action 'recent-reset' -Target $statePath `
            -Status 'succeeded' -Changed $true
    } catch {
        New-CdpActionResult -Action 'recent-reset' -Target $statePath `
            -Status 'failed' -Changed $false -Error $_.Exception.Message
    }
}
