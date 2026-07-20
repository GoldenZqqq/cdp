# cdp PowerShell domain: Exec.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function New-CdpExecTempDirectory {
    $path = Join-Path ([IO.Path]::GetTempPath()) "cdp-exec-$([Guid]::NewGuid().ToString('N'))"
    [void](New-Item -ItemType Directory -Path $path -ErrorAction Stop)
    $path
}

function Start-CdpExecWorker {
    param(
        [Parameter(Mandatory = $true)][object]$Item,
        [Parameter(Mandatory = $true)][object]$Plan,
        [Parameter(Mandatory = $true)][System.Management.Automation.Runspaces.RunspacePool]$Pool
    )

    $tempDirectory = New-CdpExecTempDirectory
    $stdoutPath = Join-Path $tempDirectory 'stdout.txt'
    $stderrPath = Join-Path $tempDirectory 'stderr.txt'
    $pipeline = [PowerShell]::Create()
    try {
        $pipeline.RunspacePool = $Pool
        $worker = {
            param($WorkingDirectory, $Executable, [string[]]$Arguments, $StdoutPath, $StderrPath)
            $watch = [Diagnostics.Stopwatch]::StartNew()
            try {
                Set-Location -LiteralPath $WorkingDirectory -ErrorAction Stop
                $global:LASTEXITCODE = 0
                $null | & $Executable @Arguments 1> $StdoutPath 2> $StderrPath
                [PSCustomObject]@{ ExitCode=[int]$global:LASTEXITCODE; ElapsedMs=[int]$watch.ElapsedMilliseconds; Error='' }
            } catch {
                [PSCustomObject]@{ ExitCode=$null; ElapsedMs=[int]$watch.ElapsedMilliseconds; Error=$_.Exception.Message }
            } finally { $watch.Stop() }
        }
        [void]$pipeline.AddScript($worker.ToString())
        [void]$pipeline.AddArgument([string]$Item.ResolvedPath)
        [void]$pipeline.AddArgument([string]$Plan.Executable)
        [void]$pipeline.AddArgument([string[]]@($Plan.Arguments))
        [void]$pipeline.AddArgument($stdoutPath)
        [void]$pipeline.AddArgument($stderrPath)
        $startedAt = [DateTime]::UtcNow
        [PSCustomObject]@{
            Item=$Item; PowerShell=$pipeline; Async=$pipeline.BeginInvoke()
            Deadline=$startedAt.AddSeconds($Plan.TimeoutSeconds)
            TempDirectory=$tempDirectory; StdoutPath=$stdoutPath; StderrPath=$stderrPath
        }
    } catch {
        $pipeline.Dispose()
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Read-CdpExecCapture {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    $content = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { return '' }
    ([string]$content).TrimEnd("`r", "`n")
}

function Complete-CdpExecWorker {
    param([Parameter(Mandatory = $true)][object]$Task)

    try {
        $remaining = [Math]::Max(0, [int][Math]::Ceiling(($Task.Deadline - [DateTime]::UtcNow).TotalMilliseconds))
        if (-not $Task.Async.AsyncWaitHandle.WaitOne($remaining)) {
            try { $Task.PowerShell.Stop() } catch {}
            $Task.Item.Status = 'timed_out'
            $Task.Item.Error = 'Command timed out.'
            $Task.Item.ElapsedMs = [int][Math]::Max(0, $Task.PlanTimeoutMs)
        } else {
            $values = @($Task.PowerShell.EndInvoke($Task.Async))
            $workerResult = if ($values.Count -gt 0) { $values[-1] } else { $null }
            Set-CdpExecWorkerResult -Item $Task.Item -WorkerResult $workerResult
        }
        $Task.Item.Stdout = Read-CdpExecCapture -Path $Task.StdoutPath
        $Task.Item.Stderr = Read-CdpExecCapture -Path $Task.StderrPath
        $Task.Item
    } catch {
        $Task.Item.Status = 'failed'
        $Task.Item.Error = $_.Exception.Message
        $Task.Item
    } finally {
        $Task.PowerShell.Dispose()
        Remove-Item -LiteralPath $Task.TempDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Set-CdpExecWorkerResult {
    param([Parameter(Mandatory = $true)][object]$Item, [AllowNull()][object]$WorkerResult)

    if (-not $WorkerResult) {
        $Item.Status = 'failed'
        $Item.Error = 'Exec worker returned no result.'
        return
    }
    $Item.ElapsedMs = [int]$WorkerResult.ElapsedMs
    $Item.ExitCode = if ($null -eq $WorkerResult.ExitCode) { $null } else { [int]$WorkerResult.ExitCode }
    if (-not [string]::IsNullOrWhiteSpace([string]$WorkerResult.Error)) {
        $Item.Status = 'failed'
        $Item.Error = [string]$WorkerResult.Error
    } elseif ($Item.ExitCode -eq 0) {
        $Item.Status = 'succeeded'
    } else {
        $Item.Status = 'failed'
        $Item.Error = "Command exited with code $($Item.ExitCode)."
    }
}

function Set-CdpExecPreflightFailFast {
    param([Parameter(Mandatory = $true)][object[]]$Items)

    $failureSeen = $false
    foreach ($item in $Items) {
        if ($failureSeen -and $item.Status -eq 'planned') {
            $item.Status = 'canceled'
            $item.Error = 'Canceled by fail-fast before execution.'
        } elseif ($item.Status -ne 'planned') {
            $failureSeen = $true
        }
    }
}

function Stop-CdpExecFutureItems {
    param([Parameter(Mandatory = $true)][object[]]$Items)

    foreach ($item in $Items) {
        if ($item.Status -eq 'planned') {
            $item.Status = 'canceled'
            $item.Error = 'Canceled by fail-fast after an earlier failure.'
        }
    }
}

function Invoke-CdpExecWorkers {
    param([Parameter(Mandatory = $true)][object]$Plan)

    if ($Plan.FailFast) { Set-CdpExecPreflightFailFast -Items @($Plan.Items) }
    $runnable = @($Plan.Items | Where-Object Status -eq 'planned')
    if ($runnable.Count -eq 0) { return }
    $pool = [RunspaceFactory]::CreateRunspacePool(1, [Math]::Min($Plan.Jobs, $runnable.Count))
    try {
        $pool.Open()
        for ($offset = 0; $offset -lt $runnable.Count; $offset += $Plan.Jobs) {
            $batch = @($runnable | Select-Object -Skip $offset -First $Plan.Jobs)
            $tasks = @($batch | ForEach-Object {
                $task = Start-CdpExecWorker -Item $_ -Plan $Plan -Pool $pool
                $task | Add-Member -NotePropertyName PlanTimeoutMs -NotePropertyValue ($Plan.TimeoutSeconds * 1000)
                $task
            })
            foreach ($task in $tasks) { [void](Complete-CdpExecWorker -Task $task) }
            if ($Plan.FailFast -and @($batch | Where-Object { $_.Status -in @('failed', 'timed_out') }).Count -gt 0) {
                Stop-CdpExecFutureItems -Items @($Plan.Items)
                break
            }
        }
    } finally { $pool.Dispose() }
}

function Invoke-CdpExecPlan {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param([Parameter(Mandatory = $true)][object]$Plan, [switch]$Json)

    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        if (-not $Plan.DryRun) {
            if ($PSCmdlet.ShouldProcess("$($Plan.Items.Count) projects", 'Execute native command')) {
                Invoke-CdpExecWorkers -Plan $Plan
            } else {
                foreach ($item in @($Plan.Items | Where-Object Status -eq 'planned')) {
                    $item.Status = 'canceled'
                    $item.Error = 'Execution was not approved.'
                }
            }
        }
    } catch {
        $watch.Stop()
        throw
    }
    $watch.Stop()
    Write-CdpExecResult -Plan $Plan -DurationMs ([int]$watch.ElapsedMilliseconds) -Json:$Json
}

function Invoke-CdpExecInvocation {
    param([Parameter(Mandatory = $true)][object]$Invocation)

    try {
        $plan = New-CdpExecPlan -Invocation $Invocation
        $parameters = @{ Plan=$plan; Json=[bool]$Invocation.Json }
        if ($Invocation.Yes) { $parameters.Confirm = $false }
        Invoke-CdpExecPlan @parameters
    } catch {
        Write-CdpExecFatal -Message $_.Exception.Message -Json:$Invocation.Json
    }
}
