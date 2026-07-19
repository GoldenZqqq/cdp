# cdp PowerShell domain: StatusBatch.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function Get-CdpStatusIntegerSetting {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$Default,
        [Parameter(Mandatory = $true)][int]$Minimum,
        [Parameter(Mandatory = $true)][int]$Maximum
    )

    $parsed = 0
    $raw = [Environment]::GetEnvironmentVariable($Name)
    if (-not [int]::TryParse($raw, [ref]$parsed)) { $parsed = $Default }
    [Math]::Max($Minimum, [Math]::Min($Maximum, $parsed))
}

function Resolve-CdpStatusThrottleLimit {
    param([int]$Value = 0)

    if ($Value -gt 0) { return [Math]::Max(1, [Math]::Min(16, $Value)) }
    $default = [Math]::Max(1, [Math]::Min(4, [Environment]::ProcessorCount))
    Get-CdpStatusIntegerSetting -Name 'CDP_STATUS_CONCURRENCY' -Default $default -Minimum 1 -Maximum 16
}

function Get-CdpStatusCacheKey {
    param([Parameter(Mandatory = $true)][object]$Project)

    $name = ([string]$Project.name).ToUpperInvariant()
    $path = Get-CdpComparablePath -Path ([string]$Project.rootPath)
    "$name`0$path"
}

function Get-CdpCachedGitProjectInfo {
    param(
        [Parameter(Mandatory = $true)][object]$Project,
        [Parameter(Mandatory = $true)][int]$TtlSeconds,
        [switch]$Refresh
    )

    $key = Get-CdpStatusCacheKey -Project $Project
    if ($Refresh) { [void]$script:CdpStatusCache.Remove($key); return $null }
    if ($TtlSeconds -le 0) { return $null }
    $entry = $script:CdpStatusCache[$key]
    if (-not $entry) { return $null }
    if (([DateTime]::UtcNow - $entry.CachedAt).TotalSeconds -ge $TtlSeconds) {
        [void]$script:CdpStatusCache.Remove($key)
        return $null
    }
    $entry.Value
}

function Set-CdpCachedGitProjectInfo {
    param(
        [Parameter(Mandatory = $true)][object]$Project,
        [Parameter(Mandatory = $true)][object]$Info,
        [Parameter(Mandatory = $true)][int]$TtlSeconds
    )

    if ($TtlSeconds -le 0) { return }
    $script:CdpStatusCache[(Get-CdpStatusCacheKey -Project $Project)] = [PSCustomObject]@{
        CachedAt = [DateTime]::UtcNow
        Value = $Info
    }
}

function New-CdpFailedGitProjectInfo {
    param(
        [Parameter(Mandatory = $true)][object]$Project,
        [Parameter(Mandatory = $true)][string]$StatusLabel
    )

    $info = New-CdpGitProjectInfo -Project $Project
    $info.PathExists = Test-Path -LiteralPath ([string]$Project.rootPath)
    $info.StatusLabel = $StatusLabel
    $info.NeedsAttention = $true
    $info
}

function Get-CdpStatusWorkerHelperScript {
    @(
        'function New-CdpGitProjectInfo {'
        (Get-Command New-CdpGitProjectInfo).ScriptBlock.ToString()
        '}'
        'function ConvertFrom-CdpGitStatusPorcelainV2 {'
        (Get-Command ConvertFrom-CdpGitStatusPorcelainV2).ScriptBlock.ToString()
        '}'
        'function Set-CdpGitProjectStatusLabel {'
        (Get-Command Set-CdpGitProjectStatusLabel).ScriptBlock.ToString()
        '}'
        'function Get-CdpGitProjectInfo {'
        (Get-Command Get-CdpGitProjectInfo).ScriptBlock.ToString()
        '}'
    ) -join "`n"
}

function Start-CdpStatusWorker {
    param(
        [Parameter(Mandatory = $true)][object]$Project,
        [Parameter(Mandatory = $true)][System.Management.Automation.Runspaces.RunspacePool]$Pool,
        [Parameter(Mandatory = $true)][string]$HelperScript,
        [Parameter(Mandatory = $true)][scriptblock]$CollectorScript
    )

    $pipeline = [PowerShell]::Create()
    $pipeline.RunspacePool = $Pool
    $workerScript = {
        param($Project, $HelperScript, $CollectorText)
        # Helper text is assembled only from trusted module-owned function bodies.
        Invoke-Expression $HelperScript
        & ([scriptblock]::Create($CollectorText)) $Project
    }
    [void]$pipeline.AddScript($workerScript.ToString())
    [void]$pipeline.AddArgument($Project)
    [void]$pipeline.AddArgument($HelperScript)
    [void]$pipeline.AddArgument($CollectorScript.ToString())
    [PSCustomObject]@{
        Project = $Project
        PowerShell = $pipeline
        Async = $pipeline.BeginInvoke()
    }
}

function Complete-CdpStatusWorker {
    param(
        [Parameter(Mandatory = $true)][object]$Task,
        [Parameter(Mandatory = $true)][DateTime]$Deadline,
        [Parameter(Mandatory = $true)][int]$TtlSeconds
    )

    try {
        $remaining = [Math]::Max(0, [int][Math]::Ceiling(($Deadline - [DateTime]::UtcNow).TotalMilliseconds))
        if (-not $Task.Async.AsyncWaitHandle.WaitOne($remaining)) {
            try { $Task.PowerShell.Stop() } catch {}
            $info = New-CdpFailedGitProjectInfo -Project $Task.Project -StatusLabel 'status timed out'
        } else {
            try {
                $values = @($Task.PowerShell.EndInvoke($Task.Async))
                $info = if ($values.Count -gt 0) { $values[-1] } else {
                    New-CdpFailedGitProjectInfo -Project $Task.Project -StatusLabel 'status failed'
                }
            } catch {
                $info = New-CdpFailedGitProjectInfo -Project $Task.Project -StatusLabel 'status failed'
            }
        }
        Set-CdpCachedGitProjectInfo -Project $Task.Project -Info $info -TtlSeconds $TtlSeconds
        $info
    } finally {
        $Task.PowerShell.Dispose()
    }
}

function Get-CdpGitProjectInfoBatch {
    param(
        [Parameter(Mandatory = $true)][object[]]$Projects,
        [int]$ThrottleLimit = 0,
        [int]$TimeoutSeconds = 0,
        [switch]$Refresh,
        [scriptblock]$CollectorScript = { param($Project) Get-CdpGitProjectInfo -Project $Project }
    )

    if ($Projects.Count -eq 0) { return }
    $limit = Resolve-CdpStatusThrottleLimit -Value $ThrottleLimit
    if ($TimeoutSeconds -le 0) {
        $TimeoutSeconds = Get-CdpStatusIntegerSetting -Name 'CDP_STATUS_TIMEOUT_SECONDS' -Default 10 -Minimum 1 -Maximum 60
    }
    $ttl = Get-CdpStatusIntegerSetting -Name 'CDP_STATUS_CACHE_TTL' -Default 0 -Minimum 0 -Maximum 60
    $pool = [RunspaceFactory]::CreateRunspacePool(1, [Math]::Min($limit, $Projects.Count))
    try {
        $pool.Open()
        $helperScript = Get-CdpStatusWorkerHelperScript
        for ($offset = 0; $offset -lt $Projects.Count; $offset += $limit) {
            $tasks = New-Object 'System.Collections.Generic.List[object]'
            $end = [Math]::Min($Projects.Count, $offset + $limit)
            for ($index = $offset; $index -lt $end; $index++) {
                $project = $Projects[$index]
                $cached = Get-CdpCachedGitProjectInfo -Project $project -TtlSeconds $ttl -Refresh:$Refresh
                if ($cached) {
                    $tasks.Add([PSCustomObject]@{ Project = $project; Cached = $cached })
                } else {
                    $tasks.Add((Start-CdpStatusWorker -Project $project -Pool $pool `
                        -HelperScript $helperScript -CollectorScript $CollectorScript))
                }
            }
            $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
            foreach ($task in $tasks) {
                if ($task.Cached) { $task.Cached } else {
                    Complete-CdpStatusWorker -Task $task -Deadline $deadline -TtlSeconds $ttl
                }
            }
        }
    } finally {
        $pool.Dispose()
    }
}
