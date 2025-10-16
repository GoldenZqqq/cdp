<#
.SYNOPSIS
    Alternative publishing method without .NET SDK dependency.

.DESCRIPTION
    This script uses NuGet.exe directly instead of dotnet CLI to avoid .NET Core SDK dependency.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ProjSwitch - Alternative Publisher" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get API Key
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = $env:PSGALLERY_API_KEY
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        Write-Host "Error: API Key not provided." -ForegroundColor Red
        Write-Host "Set: `$env:PSGALLERY_API_KEY = 'your-api-key'" -ForegroundColor Yellow
        exit 1
    }
}

# Paths
$scriptRoot = $PSScriptRoot
$manifestPath = Join-Path $scriptRoot "ProjSwitch.psd1"

# Validate manifest
try {
    $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    Write-Host "✓ Module manifest validated" -ForegroundColor Green
    Write-Host "  Version: $($manifest.Version)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Module manifest validation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check for NuGet.exe
$nugetPath = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\PowerShell\PowerShellGet\NuGet.exe"
if (-not (Test-Path $nugetPath)) {
    Write-Host "Downloading NuGet.exe..." -ForegroundColor Yellow
    $nugetUrl = "https://aka.ms/psget-nugetexe"
    $nugetDir = Split-Path $nugetPath -Parent
    if (-not (Test-Path $nugetDir)) {
        New-Item -ItemType Directory -Path $nugetDir -Force | Out-Null
    }
    Invoke-WebRequest -Uri $nugetUrl -OutFile $nugetPath
    Write-Host "✓ NuGet.exe downloaded" -ForegroundColor Green
}

# Try alternative: Use Publish-PSResource if available (PowerShellGet v3)
if (Get-Command Publish-PSResource -ErrorAction SilentlyContinue) {
    Write-Host "Using Publish-PSResource (PowerShellGet v3)..." -ForegroundColor Cyan

    try {
        Publish-PSResource -Path $scriptRoot -Repository PSGallery -ApiKey $ApiKey -Verbose

        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "  ✅ Successfully Published!" -ForegroundColor Green
        Write-Host "========================================`n" -ForegroundColor Green

        Write-Host "View at: https://www.powershellgallery.com/packages/ProjSwitch/$($manifest.Version)`n" -ForegroundColor Cyan
        exit 0
    } catch {
        Write-Host "❌ Publish-PSResource failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Final fallback message
Write-Host "`n❌ Alternative methods not available" -ForegroundColor Red
Write-Host "`nPlease install .NET SDK to use Publish-Module:" -ForegroundColor Yellow
Write-Host "  1. Visit: https://dotnet.microsoft.com/download" -ForegroundColor Gray
Write-Host "  2. Download .NET 8.0 SDK" -ForegroundColor Gray
Write-Host "  3. Install and restart PowerShell" -ForegroundColor Gray
Write-Host "  4. Run: .\Publish-ToGallery.ps1`n" -ForegroundColor Gray

exit 1
