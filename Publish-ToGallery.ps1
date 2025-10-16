<#
.SYNOPSIS
    Publishes ProjSwitch module to PowerShell Gallery.

.DESCRIPTION
    This script packages and publishes the ProjSwitch module to the PowerShell Gallery.
    It performs validation checks before publishing.

.PARAMETER ApiKey
    Your PowerShell Gallery API key. Can also be set via environment variable: $env:PSGALLERY_API_KEY

.PARAMETER WhatIf
    Shows what would happen without actually publishing.

.EXAMPLE
    .\Publish-ToGallery.ps1 -ApiKey "your-api-key"

.EXAMPLE
    $env:PSGALLERY_API_KEY = "your-api-key"
    .\Publish-ToGallery.ps1

.NOTES
    IMPORTANT SECURITY NOTE:
    - NEVER commit your API key to source control
    - Use environment variables or secure key management
    - Revoke and regenerate keys if accidentally exposed
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ProjSwitch - PowerShell Gallery Publisher" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get API Key from parameter or environment variable
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = $env:PSGALLERY_API_KEY
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        Write-Host "Error: API Key not provided." -ForegroundColor Red
        Write-Host "Provide via -ApiKey parameter or set `$env:PSGALLERY_API_KEY" -ForegroundColor Yellow
        Write-Host "`nExample:" -ForegroundColor Cyan
        Write-Host "  `$env:PSGALLERY_API_KEY = 'your-api-key-here'" -ForegroundColor Gray
        Write-Host "  .\Publish-ToGallery.ps1`n" -ForegroundColor Gray
        exit 1
    }
}

# Paths
$scriptRoot = $PSScriptRoot
$manifestPath = Join-Path $scriptRoot "ProjSwitch.psd1"
$modulePath = $scriptRoot

Write-Host "Pre-flight Checks:" -ForegroundColor Yellow

# Check if manifest exists
if (-not (Test-Path $manifestPath)) {
    Write-Host "  ❌ Module manifest not found: $manifestPath" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Module manifest found" -ForegroundColor Green

# Load and validate manifest
try {
    $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    Write-Host "  ✓ Module manifest is valid" -ForegroundColor Green
    Write-Host "    - Name: $($manifest.Name)" -ForegroundColor Gray
    Write-Host "    - Version: $($manifest.Version)" -ForegroundColor Gray
    Write-Host "    - Author: $($manifest.Author)" -ForegroundColor Gray
    Write-Host "    - GUID: $($manifest.Guid)" -ForegroundColor Gray
} catch {
    Write-Host "  ❌ Module manifest validation failed" -ForegroundColor Red
    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
    exit 1
}

# Check required files
$requiredFiles = @(
    "ProjSwitch.psd1",
    "src\ProjSwitch.psm1",
    "LICENSE",
    "README.md"
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $scriptRoot $file
    if (-not (Test-Path $filePath)) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "  ❌ Missing required files:" -ForegroundColor Red
    foreach ($file in $missingFiles) {
        Write-Host "    - $file" -ForegroundColor Gray
    }
    exit 1
}
Write-Host "  ✓ All required files present" -ForegroundColor Green

# Check if module is already published (optional warning)
try {
    $existingModule = Find-Module -Name "ProjSwitch" -ErrorAction SilentlyContinue
    if ($existingModule) {
        Write-Host "`n  ⚠️  Module 'ProjSwitch' already exists on PowerShell Gallery" -ForegroundColor Yellow
        Write-Host "    - Published Version: $($existingModule.Version)" -ForegroundColor Gray
        Write-Host "    - Your Version: $($manifest.Version)" -ForegroundColor Gray

        if ([version]$manifest.Version -le [version]$existingModule.Version) {
            Write-Host "    ❌ Your version must be greater than published version!" -ForegroundColor Red
            Write-Host "    Please update ModuleVersion in ProjSwitch.psd1" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "    ✓ Version check passed (your version is newer)" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠️  Could not check existing module (might be first publish)" -ForegroundColor Yellow
}

# Final confirmation
Write-Host "`nReady to publish:" -ForegroundColor Cyan
Write-Host "  Module: ProjSwitch" -ForegroundColor Gray
Write-Host "  Version: $($manifest.Version)" -ForegroundColor Gray
Write-Host "  Path: $modulePath" -ForegroundColor Gray
Write-Host "  Repository: PSGallery" -ForegroundColor Gray

if ($WhatIfPreference) {
    Write-Host "`n[WhatIf Mode] Would publish to PowerShell Gallery" -ForegroundColor Magenta
    exit 0
}

# Ask for confirmation
$response = Read-Host "`nProceed with publishing? (yes/no)"
if ($response -ne 'yes') {
    Write-Host "Publishing cancelled." -ForegroundColor Yellow
    exit 0
}

# Publish to PowerShell Gallery
Write-Host "`nPublishing to PowerShell Gallery..." -ForegroundColor Cyan
try {
    Publish-Module -Path $modulePath -NuGetApiKey $ApiKey -Repository PSGallery -Verbose
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

    if ($_.Exception.Message -match "api") {
        Write-Host "`nPossible causes:" -ForegroundColor Yellow
        Write-Host "  - Invalid API key" -ForegroundColor Gray
        Write-Host "  - API key expired or revoked" -ForegroundColor Gray
        Write-Host "  - Network connectivity issues" -ForegroundColor Gray
        Write-Host "`nVerify your API key at: https://www.powershellgallery.com/account/apikeys" -ForegroundColor Cyan
    }

    exit 1
}
