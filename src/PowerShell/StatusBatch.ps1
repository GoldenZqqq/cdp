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
    $resolution = Resolve-CdpProjectPath -Project $Project
    if ($resolution.ErrorCode) {
        return "$name`0$($resolution.Profile)`0invalid:$($resolution.Source):$($resolution.RawPath)"
    }
    $path = Get-CdpComparablePath -Path ([string]$resolution.ResolvedPath)
    "$name`0$($resolution.Profile)`0$path"
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
    if (-not $info.PathResolutionError) {
        $info.PathExists = Test-Path -LiteralPath ([string]$info.ResolvedPath)
    }
    $info.StatusLabel = $StatusLabel
    $info.NeedsAttention = $true
    $info
}

function Get-CdpStatusWorkerHelperScript {
    @(
        'function New-CdpGitProjectInfo {'
        (Get-Command New-CdpGitProjectInfo).ScriptBlock.ToString()
        '}'
        'function Convert-WindowsPathToWSL {'
        (Get-Command Convert-WindowsPathToWSL).ScriptBlock.ToString()
        '}'
        'function Get-CdpDetectedPathProfile {'
        (Get-Command Get-CdpDetectedPathProfile).ScriptBlock.ToString()
        '}'
        'function Get-CdpCurrentPathProfile {'
        (Get-Command Get-CdpCurrentPathProfile).ScriptBlock.ToString()
        '}'
        'function Get-CdpProjectPathProperty {'
        (Get-Command Get-CdpProjectPathProperty).ScriptBlock.ToString()
        '}'
        'function New-CdpPathResolution {'
        (Get-Command New-CdpPathResolution).ScriptBlock.ToString()
        '}'
        'function Get-CdpInvalidKnownPathProfile {'
        (Get-Command Get-CdpInvalidKnownPathProfile).ScriptBlock.ToString()
        '}'
        'function Resolve-CdpProjectPath {'
        (Get-Command Resolve-CdpProjectPath).ScriptBlock.ToString()
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

function ConvertTo-CdpStatusRemoteDisplayUrl {
    param([string]$RemoteUrl)

    if ($RemoteUrl -notmatch '^https?://') { return $RemoteUrl }
    ($RemoteUrl -replace '([?#]).*$', '') -replace '^(https?://)[^/@]+@', '$1***@'
}

function Update-CdpStatusRemoteIdentity {
    param([Parameter(Mandatory = $true)][object]$Info)

    $path = [string]$Info.ResolvedPath
    $branch = @(& git -C $path symbolic-ref --quiet --short HEAD 2>$null) -join ''
    $Info.HeadOid = @(& git -C $path rev-parse HEAD 2>$null) -join ''
    $Info.RemoteName = ''
    $Info.RemoteRef = ''
    $Info.RemoteUrl = ''
    if (-not $branch) { $Info.Freshness = 'no-upstream'; return }
    $Info.RemoteName = @(& git -C $path config --get "branch.$branch.remote" 2>$null) -join ''
    $Info.RemoteRef = @(& git -C $path config --get "branch.$branch.merge" 2>$null) -join ''
    $Info.Remote = $Info.RemoteName
    if (-not $Info.RemoteName -or -not $Info.RemoteRef) {
        $Info.Freshness = 'no-upstream'
        return
    }
    $Info.Upstream = @(& git -C $path rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null) -join ''
    if (-not $Info.Upstream) { $Info.Upstream = "$($Info.RemoteName)/$($Info.RemoteRef -replace '^refs/heads/', '')" }
    if ($Info.RemoteName -ne '.') {
        $url = @(& git -C $path remote get-url $Info.RemoteName 2>$null) -join ''
        $Info.RemoteUrl = ConvertTo-CdpStatusRemoteDisplayUrl -RemoteUrl $url
    }
    if ($Info.Freshness -in @('not-applicable', 'no-upstream')) { $Info.Freshness = 'cached' }
}

function Update-CdpStatusSyncSnapshot {
    param([Parameter(Mandatory = $true)][object]$Info)

    $Info.AheadCount = 0
    $Info.BehindCount = 0
    $lines = @(& git -C $Info.ResolvedPath status --porcelain=v2 --branch --untracked-files=no 2>$null)
    if ($LASTEXITCODE -eq 0) {
        foreach ($line in $lines) {
            if ($line -match '^# branch\.ab \+(\d+) -(\d+)$') {
                $Info.AheadCount = [int]$matches[1]
                $Info.BehindCount = [int]$matches[2]
            }
        }
    }
    Update-CdpStatusRemoteIdentity -Info $Info
    Set-CdpGitProjectStatusLabel -Info $Info
}

function New-CdpStatusFetchResult {
    param([object]$Status, [string]$Freshness, [bool]$Succeeded,
        [bool]$TimedOut, [string]$Message, [object]$Process)

    [PSCustomObject]@{
        Status=$Status; Freshness=$Freshness; FetchSucceeded=$Succeeded
        FetchTimedOut=$TimedOut; FetchMessage=$Message; Process=$Process
    }
}

function Start-CdpStatusFetchProcess {
    param([Parameter(Mandatory = $true)][object]$Status)

    $gitCommand = Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $gitCommand.Source
    $startInfo.WorkingDirectory = [string]$Status.ResolvedPath
    $startInfo.Arguments = 'fetch --quiet --prune --no-tags --no-recurse-submodules'
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
    $startInfo.EnvironmentVariables['GCM_INTERACTIVE'] = 'Never'
    $startInfo.EnvironmentVariables['SSH_ASKPASS_REQUIRE'] = 'never'
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    [PSCustomObject]@{ Status=$Status; Process=$process; Stopwatch=[Diagnostics.Stopwatch]::StartNew() }
}

function Stop-CdpStatusFetchProcess {
    param([Parameter(Mandatory = $true)][object]$Process)

    if ($Process.HasExited) { return }
    try {
        if ($env:OS -eq 'Windows_NT' -and (Get-Command taskkill.exe -ErrorAction SilentlyContinue)) {
            & taskkill.exe /PID $Process.Id /T /F 2>$null | Out-Null
        } else {
            $pkill = Get-Command pkill -ErrorAction SilentlyContinue
            if ($pkill) { & $pkill.Source -TERM -P $Process.Id 2>$null }
            $Process.Kill()
        }
    } catch { try { $Process.Kill() } catch {} }
    try { [void]$Process.WaitForExit(2000) } catch {}
}

function Complete-CdpStatusFetchProcess {
    param([object]$ActiveFetch, [int]$TimeoutSeconds, [switch]$TimedOut)

    $process = $ActiveFetch.Process
    $ActiveFetch.Stopwatch.Stop()
    if ($TimedOut) {
        Stop-CdpStatusFetchProcess -Process $process
        return New-CdpStatusFetchResult -Status $ActiveFetch.Status -Freshness 'fetch-failed' `
            -Succeeded:$false -TimedOut:$true -Message "timeout after $TimeoutSeconds seconds" -Process $process
    }
    try {
        $process.WaitForExit()
        $success = $process.ExitCode -eq 0
        $message = if ($success) { 'fetch completed' } else { "fetch failed (exit $($process.ExitCode))" }
        New-CdpStatusFetchResult -Status $ActiveFetch.Status `
            -Freshness $(if ($success) { 'refreshed' } else { 'fetch-failed' }) `
            -Succeeded:$success -TimedOut:$false -Message $message -Process $process
    } catch {
        New-CdpStatusFetchResult -Status $ActiveFetch.Status -Freshness 'fetch-failed' `
            -Succeeded:$false -TimedOut:$false -Message 'fetch process failed' -Process $process
    }
}

function Invoke-CdpStatusFetchPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object[]]$StatusList,
        [ValidateRange(1, 16)][int]$Jobs = 4,
        [ValidateRange(1, 300)][int]$TimeoutSeconds = 15)

    $pending = New-Object System.Collections.Queue
    @($StatusList | Where-Object { $_.IsGitRepo -and $_.RemoteName -and $_.RemoteName -ne '.' -and $_.RemoteRef }) |
        ForEach-Object { $pending.Enqueue($_) }
    $active = New-Object System.Collections.ArrayList
    $results = New-Object System.Collections.ArrayList
    try {
        while ($pending.Count -gt 0 -or $active.Count -gt 0) {
            while ($pending.Count -gt 0 -and $active.Count -lt $Jobs) {
                $status = $pending.Dequeue()
                try { [void]$active.Add((Start-CdpStatusFetchProcess -Status $status)) }
                catch { [void]$results.Add((New-CdpStatusFetchResult -Status $status -Freshness 'fetch-failed' -Succeeded:$false -TimedOut:$false -Message 'fetch process failed to start' -Process $null)) }
            }
            $completed = $false
            foreach ($item in @($active)) {
                $timedOut = $item.Stopwatch.Elapsed.TotalSeconds -ge $TimeoutSeconds
                if (-not $item.Process.HasExited -and -not $timedOut) { continue }
                [void]$results.Add((Complete-CdpStatusFetchProcess -ActiveFetch $item -TimeoutSeconds $TimeoutSeconds -TimedOut:$timedOut))
                [void]$active.Remove($item)
                $completed = $true
            }
            if (-not $completed -and $active.Count -gt 0) { Start-Sleep -Milliseconds 25 }
        }
    } finally { foreach ($item in @($active)) { Stop-CdpStatusFetchProcess -Process $item.Process } }
    @($results)
}

function Set-CdpStatusFetchResults {
    param([object[]]$FetchResults)

    $failedCount = 0
    foreach ($result in @($FetchResults)) {
        $status = $result.Status
        $status.FetchAttempted = $true
        $status.FetchSucceeded = $result.FetchSucceeded
        $status.FetchTimedOut = $result.FetchTimedOut
        $status.FetchMessage = $result.FetchMessage
        $status.Freshness = $result.Freshness
        Update-CdpStatusSyncSnapshot -Info $status
        if (-not $result.FetchSucceeded) {
            $status.Freshness = 'fetch-failed'
            $status.NeedsAttention = $true
            $failedCount++
        }
    }
    $failedCount
}

function Write-CdpStatusFetchAggregateError {
    param([int]$FailedCount, [Parameter(Mandatory = $true)][object]$Cmdlet)

    if ($script:CdpDeferStatusFetchError) {
        $script:CdpLastStatusFetchFailedCount = $FailedCount
        return
    }
    if ($FailedCount -le 0) { return }
    $message = "$FailedCount repositories failed to refresh; cached tracking data was retained."
    $exception = New-Object InvalidOperationException $message
    $record = New-Object Management.Automation.ErrorRecord $exception, 'CdpStatusFetchFailed', `
        ([Management.Automation.ErrorCategory]::ConnectionError), $FailedCount
    $Cmdlet.WriteError($record)
}

function Get-CdpStatusPushPlan {
    param([Parameter(Mandatory = $true)][object[]]$StatusList)

    foreach ($project in @($StatusList | Where-Object {
        $_.AheadCount -gt 0 -and $_.IsGitRepo -and $_.Freshness -ne 'fetch-failed' -and
        $_.HeadOid -and $_.RemoteName -and $_.RemoteName -ne '.' -and $_.RemoteRef -like 'refs/heads/*'
    })) {
        [PSCustomObject]@{ Project=$project; Upstream=$project.Upstream; RemoteName=$project.RemoteName
            RemoteRef=$project.RemoteRef; RemoteUrl=$project.RemoteUrl; HeadOid=$project.HeadOid }
    }
}

function Invoke-CdpStatusPushPlan {
    param([object]$Cmdlet, [object[]]$PushPlan, [switch]$PassThru)

    Write-Host "`nGit push plan ($($PushPlan.Count) repositories):" -ForegroundColor Yellow
    foreach ($item in $PushPlan) { Write-Host "  $($item.Project.Name) -> $($item.Upstream)  $($item.RemoteUrl)" -ForegroundColor DarkGray }
    $results = @()
    foreach ($item in $PushPlan) {
        $project = $item.Project
        $details = [PSCustomObject]@{ Upstream=$item.Upstream; RemoteUrl=$item.RemoteUrl
            RemoteRef=$item.RemoteRef; HeadOid=$item.HeadOid; Freshness=$project.Freshness }
        if (-not $Cmdlet.ShouldProcess("$($project.Name) -> $($item.Upstream)", 'Push frozen Git snapshot')) {
            $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
            $results += New-CdpActionResult -Action status-push -Target $project.Name -Status $status -Changed $false -Details $details
            continue
        }
        $previousErrorAction = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $null = @(& git -C $project.ResolvedPath push --porcelain $item.RemoteName `
                "$($item.HeadOid):$($item.RemoteRef)" 2>&1)
            $pushExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorAction
        }
        $success = $pushExitCode -eq 0
        $errorText = if ($success) { '' } else { 'git-push-failed' }
        if ($success) { Write-Host 'done' -ForegroundColor Green }
        else { Write-Host "failed: $errorText" -ForegroundColor Red }
        $results += New-CdpActionResult -Action status-push -Target $project.Name `
            -Status $(if ($success) { 'succeeded' } else { 'failed' }) -Changed:$success -Error $errorText -Details $details
    }
    if (@($results | Where-Object Status -eq 'failed').Count -gt 0) { $global:LASTEXITCODE = 1 }
    if ($PassThru) { $results }
}
