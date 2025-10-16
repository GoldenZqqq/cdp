<#
.SYNOPSIS
    Publishes ProjSwitch using PowerShellGet v3 (PSResourceGet).

.DESCRIPTION
    This script uses the new Publish-PSResource command which doesn't require .NET Core 2.0.

.PARAMETER ApiKey
    Your PowerShell Gallery API key.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ProjSwitch - PowerShellGet v3 Publisher" -ForegroundColor Cyan
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

# Check if PSResourceGet is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.PSResourceGet)) {
    Write-Host "Installing PowerShellGet v3 (PSResourceGet)..." -ForegroundColor Yellow
    try {
        Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force -AllowClobber -Scope CurrentUser
        Write-Host "✓ PSResourceGet installed" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to install PSResourceGet: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nPlease install manually:" -ForegroundColor Yellow
        Write-Host "  Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force" -ForegroundColor Gray
        exit 1
    }
}

Import-Module Microsoft.PowerShell.PSResourceGet -Force

# Validate manifest
$manifestPath = Join-Path $PSScriptRoot "ProjSwitch.psd1"
try {
    $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    Write-Host "✓ Module manifest validated" -ForegroundColor Green
    Write-Host "  Name: $($manifest.Name)" -ForegroundColor Gray
    Write-Host "  Version: $($manifest.Version)" -ForegroundColor Gray
    Write-Host "  Author: $($manifest.Author)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Module manifest validation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check required files
$requiredFiles = @("ProjSwitch.psd1", "src\ProjSwitch.psm1", "LICENSE", "README.md")
$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (-not (Test-Path (Join-Path $PSScriptRoot $file))) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "❌ Missing required files:" -ForegroundColor Red
    $missingFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    exit 1
}
Write-Host "✓ All required files present" -ForegroundColor Green

# Confirmation
Write-Host "`nReady to publish:" -ForegroundColor Cyan
Write-Host "  Module: $($manifest.Name)" -ForegroundColor Gray
Write-Host "  Version: $($manifest.Version)" -ForegroundColor Gray
Write-Host "  Repository: PSGallery" -ForegroundColor Gray

$response = Read-Host "`nProceed with publishing? (yes/no)"
if ($response -ne 'yes') {
    Write-Host "Publishing cancelled." -ForegroundColor Yellow
    exit 0
}

# Publish using PSResourceGet
Write-Host "`nPublishing to PowerShell Gallery..." -ForegroundColor Cyan
try {
    Publish-PSResource -Path $PSScriptRoot -Repository PSGallery -ApiKey $ApiKey -Verbose

    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  ✅ Successfully Published!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green

    Write-Host "Your module is now available on PowerShell Gallery!" -ForegroundColor Cyan
    Write-Host "View at: https://www.powershellgallery.com/packages/ProjSwitch/$($manifest.Version)`n" -ForegroundColor Cyan

    Write-Host "Users can now install with:" -ForegroundColor Yellow
    Write-Host "  Install-Module -Name ProjSwitch -Scope CurrentUser" -ForegroundColor Gray
    Write-Host "  Import-Module ProjSwitch`n" -ForegroundColor Gray

    Write-Host "Note: It may take a few minutes for the module to appear in search results." -ForegroundColor Yellow

} catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "  ❌ Publishing Failed" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Gray

    if ($_.Exception.Message -match "api|key") {
        Write-Host "`nPossible causes:" -ForegroundColor Yellow
        Write-Host "  - Invalid API key" -ForegroundColor Gray
        Write-Host "  - API key expired or revoked" -ForegroundColor Gray
        Write-Host "`nVerify your API key at: https://www.powershellgallery.com/account/apikeys" -ForegroundColor Cyan
    }

    exit 1
}
