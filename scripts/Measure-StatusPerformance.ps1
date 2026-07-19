[CmdletBinding()]
param(
    [ValidateRange(1, 200)]
    [int]$ProjectCount = 50,

    [ValidateRange(1, 20)]
    [int]$Runs = 5,

    [ValidateRange(1, 16)]
    [int]$ThrottleLimit = 4
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "cdp-status-benchmark-$PID-$([Guid]::NewGuid().ToString('N'))"
$projects = New-Object 'System.Collections.Generic.List[object]'

try {
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
    for ($i = 1; $i -le $ProjectCount; $i++) {
        $repository = Join-Path $fixtureRoot "repo-$i"
        & git init -q $repository
        & git -C $repository config user.name cdp-benchmark
        & git -C $repository config user.email cdp@example.invalid
        Set-Content -LiteralPath (Join-Path $repository 'file.txt') -Value $i -Encoding UTF8
        & git -C $repository add file.txt
        & git -C $repository commit -q -m initial
        $projects.Add([PSCustomObject]@{ name = "Repo$i"; rootPath = $repository; enabled = $true })
    }

    $configPath = Join-Path $fixtureRoot 'projects.json'
    $projects | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8
    Import-Module (Join-Path $repoRoot 'cdp.psd1') -Force
    $previousTtl = $env:CDP_STATUS_CACHE_TTL
    $env:CDP_STATUS_CACHE_TTL = '0'
    try {
        $timings = @(1..$Runs | ForEach-Object {
            (Measure-Command {
                Show-CdpProjectStatus `
                    -ConfigPath $configPath `
                    -ThrottleLimit $ThrottleLimit `
                    -Refresh `
                    -PassThru *> $null
            }).TotalSeconds
        } | Sort-Object)
    } finally {
        $env:CDP_STATUS_CACHE_TTL = $previousTtl
    }

    $median = $timings[[Math]::Floor(($timings.Count - 1) / 2)]
    $p95 = $timings[[Math]::Min($timings.Count - 1, [Math]::Ceiling($timings.Count * 0.95) - 1)]
    Write-Host 'cdp status benchmark'
    Write-Host "os: $([Environment]::OSVersion.VersionString); architecture: $([Runtime.InteropServices.RuntimeInformation]::OSArchitecture)"
    Write-Host "PowerShell: $($PSVersionTable.PSVersion); Git: $(& git --version)"
    Write-Host "projects: $ProjectCount; runs: $Runs; workers: $ThrottleLimit; cache ttl: 0"
    Write-Host ('min: {0:N3}s; median: {1:N3}s; p95: {2:N3}s' -f $timings[0], $median, $p95)
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}
