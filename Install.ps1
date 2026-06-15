<#
.SYNOPSIS
    Installation script for cdp module.

.DESCRIPTION
    This script installs the cdp module to the current user's PowerShell
    modules directory and optionally adds the 'cdp' alias to the PowerShell profile.

.PARAMETER AddToProfile
    If specified, automatically adds Import-Module and alias to PowerShell profile.

.PARAMETER Scope
    Installation scope: 'CurrentUser' (default) or 'AllUsers'.
    AllUsers requires administrator privileges.

.EXAMPLE
    .\Install.ps1
    # Installs module for current user only

.EXAMPLE
    .\Install.ps1 -AddToProfile
    # Installs module and adds to PowerShell profile

.EXAMPLE
    .\Install.ps1 -Scope AllUsers
    # Installs for all users (requires admin)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$AddToProfile,

    [Parameter(Mandatory = $false)]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser'
)

$ErrorActionPreference = 'Stop'

# Module information
$ModuleName = 'cdp'
$ScriptRoot = $PSScriptRoot

function Update-CurrentProcessPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Install-FzfDependency {
    $installers = @(
        [PSCustomObject]@{
            Name = 'winget'
            Command = 'winget'
            Arguments = @('install', 'fzf', '--silent', '--accept-source-agreements', '--accept-package-agreements')
            Manual = 'winget install fzf'
        },
        [PSCustomObject]@{
            Name = 'scoop'
            Command = 'scoop'
            Arguments = @('install', 'fzf')
            Manual = 'scoop install fzf'
        },
        [PSCustomObject]@{
            Name = 'chocolatey'
            Command = 'choco'
            Arguments = @('install', 'fzf', '-y')
            Manual = 'choco install fzf -y'
        }
    )

    foreach ($installer in $installers) {
        if (-not (Get-Command $installer.Command -ErrorAction SilentlyContinue)) {
            continue
        }

        Write-Host "  Using $($installer.Name) to install fzf..." -ForegroundColor Gray
        try {
            $arguments = @($installer.Arguments)
            & $installer.Command @arguments 2>&1 | Out-Null
            Update-CurrentProcessPath

            if (Get-Command fzf -ErrorAction SilentlyContinue) {
                Write-Host "  fzf: Installed successfully!" -ForegroundColor Green
                return $true
            }

            Write-Host "  fzf: Installed, but PATH may require a terminal restart" -ForegroundColor Yellow
            return $true
        } catch {
            Write-Host "  Failed via $($installer.Name). Try manually: $($installer.Manual)" -ForegroundColor Yellow
        }
    }

    Write-Host "  No working package manager found for fzf." -ForegroundColor Red
    Write-Host "  Install one of these, then restart PowerShell and run cdp doctor:" -ForegroundColor Yellow
    Write-Host "    winget install fzf" -ForegroundColor Cyan
    Write-Host "    scoop install fzf" -ForegroundColor Cyan
    Write-Host "    choco install fzf -y" -ForegroundColor Cyan
    Write-Host "    https://github.com/junegunn/fzf/releases" -ForegroundColor Cyan
    return $false
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  cdp Installation Script" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if running as administrator for AllUsers scope
if ($Scope -eq 'AllUsers') {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Error: AllUsers scope requires administrator privileges." -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator or use -Scope CurrentUser" -ForegroundColor Yellow
        exit 1
    }
}

# Determine installation path
if ($Scope -eq 'CurrentUser') {
    $modulePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell\Modules\$ModuleName"
    if (-not (Test-Path (Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell"))) {
        # Fallback to WindowsPowerShell for older versions
        $modulePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "WindowsPowerShell\Modules\$ModuleName"
    }
} else {
    $modulePath = Join-Path $env:ProgramFiles "PowerShell\Modules\$ModuleName"
}

Write-Host "Installation Details:" -ForegroundColor Yellow
Write-Host "  Module Name: $ModuleName" -ForegroundColor Gray
Write-Host "  Scope: $Scope" -ForegroundColor Gray
Write-Host "  Target Path: $modulePath`n" -ForegroundColor Gray

# Check if module already exists
if (Test-Path $modulePath) {
    $response = Read-Host "Module already exists. Overwrite? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "Removing existing module..." -ForegroundColor Yellow
    Remove-Item -Path $modulePath -Recurse -Force
}

# Create module directory
Write-Host "Creating module directory..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $modulePath -Force | Out-Null

# Copy module files
Write-Host "Copying module files..." -ForegroundColor Cyan
Copy-Item -Path (Join-Path $ScriptRoot "cdp.psd1") -Destination $modulePath -Force
Copy-Item -Path (Join-Path $ScriptRoot "src") -Destination $modulePath -Recurse -Force

# Verify installation
Write-Host "Verifying installation..." -ForegroundColor Cyan
$installedModule = Get-Module -ListAvailable -Name $ModuleName
if ($installedModule) {
    Write-Host "`nModule installed successfully!" -ForegroundColor Green
    Write-Host "  Version: $($installedModule.Version)" -ForegroundColor Gray
    Write-Host "  Path: $($installedModule.ModuleBase)" -ForegroundColor Gray
} else {
    Write-Host "`nWarning: Module installed but not detected in module path." -ForegroundColor Yellow
    Write-Host "You may need to restart PowerShell." -ForegroundColor Yellow
}

# Add to profile if requested
if ($AddToProfile) {
    Write-Host "`nConfiguring PowerShell profile..." -ForegroundColor Cyan

    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileContent = @"

# cdp Module - Fast project directory switcher
Import-Module cdp
"@

    # Create profile if it doesn't exist
    if (-not (Test-Path $profilePath)) {
        Write-Host "Creating PowerShell profile..." -ForegroundColor Yellow
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }

    # Check if already added
    $currentContent = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
    if ($currentContent -notmatch 'Import-Module cdp') {
        Add-Content -Path $profilePath -Value $profileContent
        Write-Host "Added to PowerShell profile: $profilePath" -ForegroundColor Green
    } else {
        Write-Host "Module already exists in profile." -ForegroundColor Gray
    }
}

# Check and install fzf
Write-Host "`nChecking dependencies..." -ForegroundColor Cyan
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    Write-Host "  fzf: Already installed" -ForegroundColor Green
} else {
    Write-Host "  fzf: Not found" -ForegroundColor Yellow
    Write-Host "`nInstalling fzf..." -ForegroundColor Cyan
    [void](Install-FzfDependency)
}

# Usage instructions
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Installation Complete!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Usage:" -ForegroundColor Yellow
if ($AddToProfile) {
    Write-Host "  1. Restart PowerShell or run: . `$PROFILE" -ForegroundColor Gray
} else {
    Write-Host "  1. Import the module: Import-Module cdp" -ForegroundColor Gray
    Write-Host "  2. Optional profile setup: rerun .\Install.ps1 -AddToProfile" -ForegroundColor Gray
}
Write-Host "  3. Check setup: cdp doctor" -ForegroundColor Gray
Write-Host "  4. Start switching: cdp`n" -ForegroundColor Gray

Write-Host "For more information, visit:" -ForegroundColor Yellow
Write-Host "  https://github.com/GoldenZqqq/cdp`n" -ForegroundColor Cyan
