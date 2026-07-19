<#
.SYNOPSIS
    Verifies that release metadata mirrors the module manifest version.

.DESCRIPTION
    Treats cdp.psd1 as the canonical version source and fails when runtime headers,
    tests, Scoop metadata, changelog, progress, or release notes drift from it.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'

function Get-CdpMetadataText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath
    )

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        throw "Required metadata file not found: $LiteralPath"
    }

    Get-Content -LiteralPath $LiteralPath -Raw -Encoding UTF8
}

function Get-CdpMatchedVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $match = [regex]::Match($Content, $Pattern)
    if (-not $match.Success) {
        return '<missing>'
    }

    $match.Groups['version'].Value
}

function New-CdpMetadataCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Actual,

        [Parameter(Mandatory = $true)]
        [string]$Expected
    )

    [PSCustomObject]@{
        Name = $Name
        Actual = $Actual
        Expected = $Expected
        Passed = $Actual -eq $Expected
    }
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$manifestPath = Join-Path $root 'cdp.psd1'
$manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
$version = $manifest.Version.ToString()
$checks = @()

$moduleText = Get-CdpMetadataText -LiteralPath (Join-Path $root 'src\cdp.psm1')
$shellText = Get-CdpMetadataText -LiteralPath (Join-Path $root 'src\cdp.sh')
$installerText = Get-CdpMetadataText -LiteralPath (Join-Path $root 'install-wsl.sh')
$testText = Get-CdpMetadataText -LiteralPath (Join-Path $root 'tests\cdp.Tests.ps1')
$changelogText = Get-CdpMetadataText -LiteralPath (Join-Path $root 'CHANGELOG.md')
$progressText = Get-CdpMetadataText -LiteralPath (Join-Path $root 'PROGRESS.md')
$scoopText = Get-CdpMetadataText -LiteralPath (Join-Path $root 'scoop\cdp.json')
$scoop = $scoopText | ConvertFrom-Json

$checks += New-CdpMetadataCheck -Name 'manifest.releaseNotes' -Actual (Get-CdpMatchedVersion -Content $manifest.ReleaseNotes -Pattern '(?m)^v(?<version>\d+\.\d+\.\d+)\s+-') -Expected $version
$checks += New-CdpMetadataCheck -Name 'powershell.header' -Actual (Get-CdpMatchedVersion -Content $moduleText -Pattern '(?m)^\s*Version:\s*(?<version>\d+\.\d+\.\d+)\s*$') -Expected $version
$checks += New-CdpMetadataCheck -Name 'shell.header' -Actual (Get-CdpMatchedVersion -Content $shellText -Pattern '(?m)^# Version:\s*(?<version>\d+\.\d+\.\d+)\s*$') -Expected $version
$checks += New-CdpMetadataCheck -Name 'shell.runtime' -Actual (Get-CdpMatchedVersion -Content $shellText -Pattern '(?m)^CDP_VERSION="(?<version>\d+\.\d+\.\d+)"\s*$') -Expected $version
$checks += New-CdpMetadataCheck -Name 'shell.installer.version' -Actual (Get-CdpMatchedVersion -Content $installerText -Pattern '(?m)^CDP_INSTALL_VERSION="(?<version>\d+\.\d+\.\d+)"\s*$') -Expected $version
$checks += New-CdpMetadataCheck -Name 'shell.installer.ref' -Actual (Get-CdpMatchedVersion -Content $installerText -Pattern '(?m)^CDP_INSTALL_REF="\$\{CDP_INSTALL_REF:-v(?<version>\d+\.\d+\.\d+)\}"\s*$') -Expected $version
$declaredScriptHash = ([regex]::Match($installerText, '(?m)^CDP_SCRIPT_SHA256="(?<hash>[0-9a-fA-F]{64})"\s*$')).Groups['hash'].Value.ToLowerInvariant()
$actualScriptHash = (Get-FileHash -LiteralPath (Join-Path $root 'src\cdp.sh') -Algorithm SHA256).Hash.ToLowerInvariant()
$checks += New-CdpMetadataCheck -Name 'shell.installer.sha256' -Actual $declaredScriptHash -Expected $actualScriptHash
$checks += New-CdpMetadataCheck -Name 'tests.manifest' -Actual (Get-CdpMatchedVersion -Content $testText -Pattern '(?m)^\s*\$manifest\.Version\.ToString\(\)\s*\|\s*Should\s+-Be\s+''(?<version>\d+\.\d+\.\d+)''\s*$') -Expected $version
$checks += New-CdpMetadataCheck -Name 'tests.about' -Actual (Get-CdpMatchedVersion -Content $testText -Pattern '(?m)^\s*\$about\.Version\s*\|\s*Should\s+-Be\s+''(?<version>\d+\.\d+\.\d+)''\s*$') -Expected $version
$checks += New-CdpMetadataCheck -Name 'changelog.latest' -Actual (Get-CdpMatchedVersion -Content $changelogText -Pattern '(?m)^##\s+(?<version>\d+\.\d+\.\d+)\s*$') -Expected $version
$checks += New-CdpMetadataCheck -Name 'progress.target' -Actual (Get-CdpMatchedVersion -Content $progressText -Pattern '(?m)^Current release target:\s*v(?<version>\d+\.\d+\.\d+)\.?\s*$') -Expected $version
$checks += New-CdpMetadataCheck -Name 'scoop.version' -Actual ([string]$scoop.version) -Expected $version
$checks += New-CdpMetadataCheck -Name 'scoop.url' -Actual ([string]$scoop.url) -Expected "https://github.com/GoldenZqqq/cdp/releases/download/v$version/cdp-$version.tar.gz"
$checks += New-CdpMetadataCheck -Name 'scoop.extract_dir' -Actual ([string]$scoop.extract_dir) -Expected "cdp-$version"
$checks += New-CdpMetadataCheck -Name 'scoop.autoupdate.url' -Actual ([string]$scoop.autoupdate.url) -Expected 'https://github.com/GoldenZqqq/cdp/releases/download/v$version/cdp-$version.tar.gz'
$checks += New-CdpMetadataCheck -Name 'scoop.autoupdate.extract_dir' -Actual ([string]$scoop.autoupdate.extract_dir) -Expected 'cdp-$version'
$checks += New-CdpMetadataCheck -Name 'scoop.depends' -Actual ([string]$scoop.depends) -Expected 'fzf'
$checks += New-CdpMetadataCheck -Name 'scoop.installer' -Actual (@($scoop.installer.script) -join [Environment]::NewLine) -Expected '& "$dir\Install.ps1" -Scope CurrentUser -Force -SkipFzf'
$scoopHashState = if ([string]$scoop.hash -match '^[0-9a-fA-F]{64}$') { 'valid' } else { [string]$scoop.hash }
$checks += New-CdpMetadataCheck -Name 'scoop.hash' -Actual $scoopHashState -Expected 'valid'

$checks | Format-Table -Property Name, Actual, Expected, Passed -AutoSize | Out-Host
$failures = @($checks | Where-Object { -not $_.Passed })
if ($failures.Count -gt 0) {
    $messages = @($failures | ForEach-Object { "$($_.Name): expected '$($_.Expected)', got '$($_.Actual)'" })
    $separator = [Environment]::NewLine + ' - '
    throw ('Release metadata mismatch:' + $separator + ($messages -join $separator))
}

Write-Host "Release metadata is consistent for v$version." -ForegroundColor Green
