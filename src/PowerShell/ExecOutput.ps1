# cdp PowerShell domain: ExecOutput.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function ConvertTo-CdpExecResultDocument {
    param([Parameter(Mandatory = $true)][object]$Item)

    [PSCustomObject][ordered]@{
        name = [string]$Item.Name
        rawPath = [string]$Item.RawPath
        resolvedPath = [string]$Item.ResolvedPath
        status = [string]$Item.Status
        exitCode = if ($null -eq $Item.ExitCode) { $null } else { [int]$Item.ExitCode }
        elapsedMs = [int]$Item.ElapsedMs
        stdout = [string]$Item.Stdout
        stderr = [string]$Item.Stderr
        error = if ([string]::IsNullOrWhiteSpace([string]$Item.Error)) { $null } else { [string]$Item.Error }
    }
}

function Test-CdpExecUnavailableStatus {
    param([Parameter(Mandatory = $true)][string]$Status)

    $Status -in @(
        'missing_project', 'ambiguous_project', 'disabled_project',
        'path_profile_invalid', 'path_missing'
    )
}

function Get-CdpExecExitCode {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Results, [switch]$FailFast)

    if ($FailFast -and @($Results | Where-Object Status -eq 'canceled').Count -gt 0) { return 2 }
    $failed = @($Results | Where-Object {
        $_.Status -in @('failed', 'timed_out', 'canceled') -or
        (Test-CdpExecUnavailableStatus -Status ([string]$_.Status))
    })
    if ($failed.Count -gt 0) { return 1 }
    0
}

function New-CdpExecSummary {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Results, [switch]$FailFast)

    [PSCustomObject][ordered]@{
        total = $Results.Count
        planned = @($Results | Where-Object Status -eq 'planned').Count
        succeeded = @($Results | Where-Object Status -eq 'succeeded').Count
        failed = @($Results | Where-Object Status -eq 'failed').Count
        timedOut = @($Results | Where-Object Status -eq 'timed_out').Count
        canceled = @($Results | Where-Object Status -eq 'canceled').Count
        unavailable = @($Results | Where-Object { Test-CdpExecUnavailableStatus -Status ([string]$_.Status) }).Count
        exitCode = Get-CdpExecExitCode -Results $Results -FailFast:$FailFast
    }
}

function New-CdpExecDocument {
    param([Parameter(Mandatory = $true)][object]$Plan, [int]$DurationMs)

    $results = @($Plan.Items | ForEach-Object { ConvertTo-CdpExecResultDocument -Item $_ })
    [PSCustomObject][ordered]@{
        schemaVersion = 1
        generatedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        durationMs = $DurationMs
        selector = $Plan.Selector
        command = [PSCustomObject]@{ executable = [string]$Plan.Command; arguments = @($Plan.Arguments) }
        options = [PSCustomObject]@{
            jobs = [int]$Plan.Jobs
            timeoutSeconds = [int]$Plan.TimeoutSeconds
            failFast = [bool]$Plan.FailFast
            dryRun = [bool]$Plan.DryRun
        }
        summary = New-CdpExecSummary -Results $results -FailFast:$Plan.FailFast
        results = $results
    }
}

function Write-CdpExecJson {
    param([Parameter(Mandatory = $true)][object]$Document)

    try { $json = $Document | ConvertTo-Json -Depth 8 -ErrorAction Stop }
    catch {
        [Console]::Error.WriteLine('Error: Failed to serialize exec JSON.')
        $global:LASTEXITCODE = 3
        return
    }
    $global:LASTEXITCODE = [int]$Document.summary.exitCode
    Write-Output $json
}

function Write-CdpExecTextBlock {
    param([string]$Label, [AllowEmptyString()][string]$Text, [ConsoleColor]$Color)

    if ([string]::IsNullOrEmpty($Text)) { return }
    Write-Host "  ${Label}:" -ForegroundColor $Color
    foreach ($line in @($Text -split "`r?`n")) {
        if ($line.Length -gt 0) { Write-Host "    $line" }
    }
}

function Write-CdpExecHuman {
    param([Parameter(Mandatory = $true)][object]$Document)

    Write-Host ''
    Write-Host "cdp exec ($($Document.summary.total) projects)" -ForegroundColor Cyan
    Write-Host ('-' * 88) -ForegroundColor DarkGray
    $index = 1
    foreach ($result in $Document.results) {
        $color = if ($result.status -eq 'succeeded') { 'Green' } elseif ($result.status -eq 'planned') { 'Cyan' } elseif ($result.status -eq 'canceled') { 'Yellow' } else { 'Red' }
        Write-Host ("[{0:00}] {1}  {2}" -f $index, $result.name, $result.status) -ForegroundColor $color
        Write-Host "  raw:      $($result.rawPath)" -ForegroundColor DarkGray
        Write-Host "  resolved: $($result.resolvedPath)" -ForegroundColor DarkGray
        if ($null -ne $result.exitCode) { Write-Host "  exit: $($result.exitCode)  elapsed: $($result.elapsedMs)ms" }
        elseif ($result.elapsedMs -gt 0) { Write-Host "  elapsed: $($result.elapsedMs)ms" }
        Write-CdpExecTextBlock -Label stdout -Text ([string]$result.stdout) -Color Gray
        Write-CdpExecTextBlock -Label stderr -Text ([string]$result.stderr) -Color Yellow
        if ($result.error) { Write-Host "  error: $($result.error)" -ForegroundColor Yellow }
        $index++
    }
    Write-Host ('-' * 88) -ForegroundColor DarkGray
    Write-Host ("succeeded={0} failed={1} timed_out={2} canceled={3} unavailable={4}" -f `
        $Document.summary.succeeded, $Document.summary.failed, $Document.summary.timedOut,
        $Document.summary.canceled, $Document.summary.unavailable)
    $global:LASTEXITCODE = [int]$Document.summary.exitCode
}

function Write-CdpExecResult {
    param([Parameter(Mandatory = $true)][object]$Plan, [int]$DurationMs, [switch]$Json)

    $document = New-CdpExecDocument -Plan $Plan -DurationMs $DurationMs
    if ($Json) { Write-CdpExecJson -Document $document } else { Write-CdpExecHuman -Document $document }
}

function Write-CdpExecFatal {
    param([Parameter(Mandatory = $true)][string]$Message, [switch]$Json)

    if ($Json) { [Console]::Error.WriteLine("Error: $Message") }
    else { Write-Host "Error: $Message" -ForegroundColor Red }
    $global:LASTEXITCODE = 3
}
