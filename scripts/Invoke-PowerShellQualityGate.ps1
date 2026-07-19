[CmdletBinding()]
param(
    [ValidateRange(0, 100)]
    [double]$CoverageThreshold = 60,

    [string]$ReportDirectory,

    [string]$PesterVersion = '5.7.1',

    [string]$ScriptAnalyzerVersion = '1.24.0'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($ReportDirectory)) {
    $ReportDirectory = Join-Path $repoRoot 'artifacts/powershell-quality'
} elseif (-not [IO.Path]::IsPathRooted($ReportDirectory)) {
    $ReportDirectory = Join-Path $repoRoot $ReportDirectory
}
New-Item -ItemType Directory -Path $ReportDirectory -Force | Out-Null

function Import-CdpQualityModule {
    param([string]$Name, [string]$Version)

    $available = Get-Module -ListAvailable -Name $Name |
        Where-Object { $_.Version -eq [Version]$Version } |
        Select-Object -First 1
    if (-not $available) {
        throw "Required quality module is not installed: $Name $Version"
    }
    Import-Module $Name -RequiredVersion $Version -Force
}

function Invoke-CdpPesterGate {
    param([string]$Root, [string]$OutputDirectory, [double]$Threshold)

    Write-Host '==> Pester tests and PowerShell coverage'
    $runtime = if ($PSVersionTable.PSEdition) { $PSVersionTable.PSEdition } else { 'Desktop' }
    $suffix = ('{0}-{1}' -f $runtime, $PSVersionTable.PSVersion.Major).ToLowerInvariant()
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = Join-Path $Root 'tests'
    $configuration.Run.PassThru = $true
    $configuration.Run.Exit = $false
    $configuration.Output.Verbosity = 'Normal'
    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputFormat = 'NUnitXml'
    $configuration.TestResult.OutputPath = Join-Path $OutputDirectory "pester-$suffix.xml"
    $configuration.CodeCoverage.Enabled = $true
    $configuration.CodeCoverage.Path = @(
        (Join-Path $Root 'src/cdp.psm1'),
        (Join-Path $Root 'src/PowerShell/*.ps1')
    )
    $configuration.CodeCoverage.OutputFormat = 'JaCoCo'
    $configuration.CodeCoverage.OutputPath = Join-Path $OutputDirectory "coverage-$suffix.xml"
    $configuration.CodeCoverage.CoveragePercentTarget = $Threshold

    $result = Invoke-Pester -Configuration $configuration
    $coverage = & (Join-Path $PSScriptRoot 'Test-CoverageThreshold.ps1') `
        -CommandsAnalyzed $result.CodeCoverage.CommandsAnalyzedCount `
        -CommandsExecuted $result.CodeCoverage.CommandsExecutedCount `
        -MinimumPercent $Threshold
    if ($result.FailedCount -gt 0) {
        throw "Pester failed: $($result.FailedCount) test(s) failed."
    }
    $coverage
}

function Invoke-CdpScriptAnalyzerGate {
    param([string]$Root)

    Write-Host '==> PSScriptAnalyzer'
    $paths = @(
        (Join-Path $Root 'src'),
        (Join-Path $Root 'scripts'),
        (Join-Path $Root 'Install.ps1'),
        (Join-Path $Root 'Publish-ToGallery.ps1'),
        (Join-Path $Root 'Publish-ToGallery-Alt.ps1')
    )
    $findings = @($paths | ForEach-Object {
        Invoke-ScriptAnalyzer -Path $_ -Recurse -Severity Error
    })
    if ($findings.Count -gt 0) {
        $findings | Format-Table -AutoSize
        throw "PSScriptAnalyzer found $($findings.Count) error-severity issue(s)."
    }
    Write-Host 'PSScriptAnalyzer: no error-severity findings.'
}

Import-CdpQualityModule -Name Pester -Version $PesterVersion
Import-CdpQualityModule -Name PSScriptAnalyzer -Version $ScriptAnalyzerVersion
$coverage = Invoke-CdpPesterGate -Root $repoRoot -OutputDirectory $ReportDirectory `
    -Threshold $CoverageThreshold
Invoke-CdpScriptAnalyzerGate -Root $repoRoot
Write-Host '==> Release metadata'
& (Join-Path $PSScriptRoot 'Test-ReleaseMetadata.ps1') -RepositoryRoot $repoRoot
Write-Host ('PowerShell quality gate passed at {0:N2}% coverage.' -f $coverage.CoveragePercent)
