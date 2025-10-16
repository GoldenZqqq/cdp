<#
.SYNOPSIS
    Publish cdp module to PowerShell Gallery.

.DESCRIPTION
    This script publishes the cdp module to PowerShell Gallery.
    Requires a valid API key from https://www.powershellgallery.com/account/apikeys

.PARAMETER ApiKey
    Your PowerShell Gallery API key.

.PARAMETER WhatIf
    Test the publish process without actually publishing.

.EXAMPLE
    .\Publish-ToGallery.ps1 -ApiKey "your-api-key-here"

.EXAMPLE
    .\Publish-ToGallery.ps1 -ApiKey "your-api-key-here" -WhatIf
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Publishing cdp to PowerShell Gallery" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get module info
$modulePath = Join-Path $PSScriptRoot "cdp.psd1"
if (-not (Test-Path $modulePath)) {
    Write-Host "Error: Module manifest not found at $modulePath" -ForegroundColor Red
    exit 1
}

$moduleInfo = Test-ModuleManifest -Path $modulePath
Write-Host "Module: $($moduleInfo.Name)" -ForegroundColor Green
Write-Host "Version: $($moduleInfo.Version)" -ForegroundColor Green
Write-Host "Author: $($moduleInfo.Author)" -ForegroundColor Green
Write-Host "Description: $($moduleInfo.Description)" -ForegroundColor Gray
Write-Host ""

# Verify required fields
$requiredFields = @{
    'Author' = $moduleInfo.Author
    'Description' = $moduleInfo.Description
    'ProjectUri' = $moduleInfo.ProjectUri
    'LicenseUri' = $moduleInfo.LicenseUri
}

$missingFields = @()
foreach ($field in $requiredFields.Keys) {
    if ([string]::IsNullOrWhiteSpace($requiredFields[$field])) {
        $missingFields += $field
    }
}

if ($missingFields.Count -gt 0) {
    Write-Host "Error: Missing required fields in module manifest:" -ForegroundColor Red
    $missingFields | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host "`nPlease update cdp.psd1 with these fields." -ForegroundColor Yellow
    exit 1
}

# Check if module already exists
Write-Host "Checking if module exists on PowerShell Gallery..." -ForegroundColor Cyan
try {
    $existingModule = Find-Module -Name cdp -ErrorAction SilentlyContinue
    if ($existingModule) {
        Write-Host "Found existing version: $($existingModule.Version)" -ForegroundColor Yellow

        if ($moduleInfo.Version -le $existingModule.Version) {
            Write-Host "`nError: Module version must be greater than existing version." -ForegroundColor Red
            Write-Host "  Current version on Gallery: $($existingModule.Version)" -ForegroundColor Yellow
            Write-Host "  Your version: $($moduleInfo.Version)" -ForegroundColor Yellow
            Write-Host "`nPlease increment the version in cdp.psd1" -ForegroundColor Cyan
            exit 1
        }
    } else {
        Write-Host "This is a new module (first publish)" -ForegroundColor Green
    }
} catch {
    Write-Host "Could not check existing module (this is OK for first publish)" -ForegroundColor Gray
}

# Confirm publish
Write-Host "`nReady to publish:" -ForegroundColor Yellow
Write-Host "  Module: cdp v$($moduleInfo.Version)" -ForegroundColor White
Write-Host "  To: PowerShell Gallery" -ForegroundColor White

if ($WhatIf) {
    Write-Host "`n[WhatIf] Would publish module to PowerShell Gallery" -ForegroundColor Yellow
    exit 0
}

$confirm = Read-Host "`nContinue? (y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Publish cancelled." -ForegroundColor Yellow
    exit 0
}

# Publish module
try {
    Write-Host "`nPublishing module..." -ForegroundColor Cyan

    $publishParams = @{
        Path = $PSScriptRoot
        NuGetApiKey = $ApiKey
        Repository = 'PSGallery'
        Verbose = $true
    }

    Publish-Module @publishParams

    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  Module published successfully!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green

    Write-Host "Users can now install with:" -ForegroundColor Cyan
    Write-Host "  Install-Module -Name cdp -Scope CurrentUser" -ForegroundColor White
    Write-Host ""
    Write-Host "View on PowerShell Gallery:" -ForegroundColor Cyan
    Write-Host "  https://www.powershellgallery.com/packages/cdp" -ForegroundColor White
    Write-Host ""
    Write-Host "Note: It may take a few minutes to appear in search results." -ForegroundColor Gray

} catch {
    Write-Host "`nError: Failed to publish module" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}
