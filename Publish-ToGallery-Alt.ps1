<#
.SYNOPSIS
    Alternative publish script using direct NuGet package upload.

.PARAMETER ApiKey
    Your PowerShell Gallery API key.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Publishing cdp to PowerShell Gallery" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get module info
$modulePath = Join-Path $PSScriptRoot "cdp.psd1"
$moduleInfo = Test-ModuleManifest -Path $modulePath
Write-Host "Module: $($moduleInfo.Name) v$($moduleInfo.Version)" -ForegroundColor Green
Write-Host ""

try {
    # Create temporary directory
    $tempDir = Join-Path $env:TEMP "cdp-publish"
    $moduleDir = Join-Path $tempDir "cdp"

    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

    # Copy files
    Write-Host "Preparing module files..." -ForegroundColor Cyan
    Copy-Item -Path "cdp.psd1" -Destination $moduleDir
    Copy-Item -Path "LICENSE" -Destination $moduleDir -ErrorAction SilentlyContinue
    Copy-Item -Path "README.md" -Destination $moduleDir -ErrorAction SilentlyContinue
    Copy-Item -Path "src" -Destination $moduleDir -Recurse -Force

    # Create nuspec file
    Write-Host "Creating NuGet specification..." -ForegroundColor Cyan
    $nuspecPath = Join-Path $moduleDir "cdp.nuspec"

    $nuspecContent = @"
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2011/08/nuspec.xsd">
  <metadata>
    <id>cdp</id>
    <version>$($moduleInfo.Version)</version>
    <authors>$($moduleInfo.Author)</authors>
    <owners>$($moduleInfo.Author)</owners>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <licenseUrl>$($moduleInfo.LicenseUri)</licenseUrl>
    <projectUrl>$($moduleInfo.ProjectUri)</projectUrl>
    <description>$($moduleInfo.Description)</description>
    <releaseNotes>$($moduleInfo.ReleaseNotes)</releaseNotes>
    <copyright>$($moduleInfo.Copyright)</copyright>
    <tags>$($moduleInfo.Tags -join ' ') PSModule</tags>
    <dependencies />
  </metadata>
</package>
"@

    Set-Content -Path $nuspecPath -Value $nuspecContent -Encoding UTF8

    # Download nuget.exe if not present
    Write-Host "Downloading nuget.exe..." -ForegroundColor Cyan
    $nugetPath = Join-Path $tempDir "nuget.exe"
    Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $nugetPath

    # Pack the module
    Write-Host "Creating NuGet package..." -ForegroundColor Cyan
    & $nugetPath pack $nuspecPath -OutputDirectory $moduleDir -NoPackageAnalysis 2>&1 | Out-Host

    # Find the created package
    $nupkgPath = Join-Path $moduleDir "cdp.$($moduleInfo.Version).nupkg"
    if (-not (Test-Path $nupkgPath)) {
        throw "Failed to create NuGet package"
    }

    Write-Host "Package created successfully!" -ForegroundColor Green

    # Upload to PowerShell Gallery
    Write-Host "`nUploading to PowerShell Gallery..." -ForegroundColor Cyan
    $publishUrl = "https://www.powershellgallery.com/api/v2/package"
    & $nugetPath push $nupkgPath -Source $publishUrl -ApiKey $ApiKey 2>&1 | Out-Host

    # Cleanup
    Remove-Item $tempDir -Recurse -Force

    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  Successfully published cdp v$($moduleInfo.Version)!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green

    Write-Host "Users can now install with:" -ForegroundColor Cyan
    Write-Host "  Install-Module -Name cdp -Scope CurrentUser" -ForegroundColor White
    Write-Host ""
    Write-Host "View on PowerShell Gallery:" -ForegroundColor Cyan
    Write-Host "  https://www.powershellgallery.com/packages/cdp/$($moduleInfo.Version)" -ForegroundColor White

} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
    $tempDir = Join-Path $env:TEMP "cdp-publish"
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    exit 1
}
