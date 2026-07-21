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

function ConvertTo-NuspecXmlText {
    param(
        [AllowNull()]
        [object]$Value
    )

    [System.Security.SecurityElement]::Escape([string]$Value)
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Publishing cdp to PowerShell Gallery" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get module info
$modulePath = Join-Path $PSScriptRoot "cdp.psd1"
$moduleInfo = Test-ModuleManifest -Path $modulePath
Write-Host "Module: $($moduleInfo.Name) v$($moduleInfo.Version)" -ForegroundColor Green
if ($moduleInfo.ReleaseNotes.Length -gt 10600) {
    throw "ReleaseNotes exceeds the PowerShell Gallery 10600-character limit ($($moduleInfo.ReleaseNotes.Length))."
}
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
    Copy-Item -Path "README_EN.md" -Destination $moduleDir -ErrorAction SilentlyContinue
    Copy-Item -Path "README_ZH.md" -Destination $moduleDir -ErrorAction SilentlyContinue
    Copy-Item -Path "install-wsl.sh" -Destination $moduleDir -ErrorAction SilentlyContinue
    Copy-Item -Path "src" -Destination $moduleDir -Recurse -Force

    # Create nuspec file
    Write-Host "Creating NuGet specification..." -ForegroundColor Cyan
    $nuspecPath = Join-Path $moduleDir "cdp.nuspec"
    $authors = ConvertTo-NuspecXmlText $moduleInfo.Author
    $licenseUri = ConvertTo-NuspecXmlText $moduleInfo.LicenseUri
    $projectUri = ConvertTo-NuspecXmlText $moduleInfo.ProjectUri
    $description = ConvertTo-NuspecXmlText $moduleInfo.Description
    $releaseNotes = ConvertTo-NuspecXmlText $moduleInfo.ReleaseNotes
    $copyright = ConvertTo-NuspecXmlText $moduleInfo.Copyright
    $tags = ConvertTo-NuspecXmlText (($moduleInfo.Tags + 'PSModule') -join ' ')

    $nuspecContent = @"
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2011/08/nuspec.xsd">
  <metadata>
    <id>cdp</id>
    <version>$($moduleInfo.Version)</version>
    <authors>$authors</authors>
    <owners>$authors</owners>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <licenseUrl>$licenseUri</licenseUrl>
    <projectUrl>$projectUri</projectUrl>
    <description>$description</description>
    <releaseNotes>$releaseNotes</releaseNotes>
    <copyright>$copyright</copyright>
    <tags>$tags</tags>
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
    $packOutput = @(& $nugetPath pack $nuspecPath -OutputDirectory $moduleDir -NoPackageAnalysis 2>&1)
    $packExitCode = $LASTEXITCODE
    $packOutput | Out-Host
    if ($packExitCode -ne 0) {
        throw "NuGet pack failed with exit code $packExitCode."
    }

    # Find the created package
    $nupkgPath = Join-Path $moduleDir "cdp.$($moduleInfo.Version).nupkg"
    if (-not (Test-Path $nupkgPath)) {
        throw "Failed to create NuGet package"
    }

    Write-Host "Package created successfully!" -ForegroundColor Green

    # Upload to PowerShell Gallery
    Write-Host "`nUploading to PowerShell Gallery..." -ForegroundColor Cyan
    $publishUrl = "https://www.powershellgallery.com/api/v2/package"
    $pushOutput = @(& $nugetPath push $nupkgPath -Source $publishUrl -ApiKey $ApiKey 2>&1)
    $pushExitCode = $LASTEXITCODE
    $pushOutput | Out-Host
    if ($pushExitCode -ne 0) {
        throw "NuGet push failed with exit code $pushExitCode."
    }

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
