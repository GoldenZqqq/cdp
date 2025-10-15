<#
.SYNOPSIS
    ProjSwitch - A fast project directory switcher for PowerShell.

.DESCRIPTION
    ProjSwitch provides a fuzzy-search interface powered by fzf to quickly
    switch between projects managed by Project Manager (VS Code/Cursor extension).

.NOTES
    Name: ProjSwitch
    Author: Your Name
    Version: 1.0.0
    License: MIT
#>

function Switch-Project {
    <#
    .SYNOPSIS
        Switch to a project directory using fzf fuzzy finder.

    .DESCRIPTION
        Provides an interactive terminal menu powered by fzf to quickly navigate
        between enabled projects from Project Manager configuration. Automatically
        updates the Windows Terminal tab title to match the selected project name.

    .PARAMETER ConfigPath
        Optional custom path to projects.json file. If not specified, uses the
        default Cursor/VS Code Project Manager location.

    .EXAMPLE
        Switch-Project
        # Opens fzf menu to select from enabled projects

    .EXAMPLE
        cdp
        # Using the default alias

    .NOTES
        Requires fzf to be installed. Install via: winget install fzf
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    # Check if fzf is installed
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Host "Error: 'fzf' command not found." -ForegroundColor Red
        Write-Host "Please install fzf first: winget install fzf" -ForegroundColor Cyan
        Write-Host "Then restart your terminal." -ForegroundColor Cyan
        return
    }

    # Determine config path
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        # Try Cursor first, then VS Code
        $cursorPath = Join-Path $env:APPDATA "Cursor\User\globalStorage\alefragnani.project-manager\projects.json"
        $vscodePath = Join-Path $env:APPDATA "Code\User\globalStorage\alefragnani.project-manager\projects.json"

        if (Test-Path $cursorPath) {
            $ConfigPath = $cursorPath
        } elseif (Test-Path $vscodePath) {
            $ConfigPath = $vscodePath
        } else {
            Write-Host "Error: Project Manager configuration not found." -ForegroundColor Red
            Write-Host "Searched locations:" -ForegroundColor Yellow
            Write-Host "  - $cursorPath" -ForegroundColor Gray
            Write-Host "  - $vscodePath" -ForegroundColor Gray
            return
        }
    }

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Error: Configuration file not found at: $ConfigPath" -ForegroundColor Red
        return
    }

    # Read and parse JSON
    try {
        $jsonContent = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
        $allProjects = ConvertFrom-Json -InputObject $jsonContent
        $enabledProjects = $allProjects | Where-Object { $_.enabled }
    } catch {
        Write-Host "Error: Failed to read or parse configuration file." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
        return
    }

    if ($null -eq $enabledProjects -or $enabledProjects.Count -eq 0) {
        Write-Host "No enabled projects found in configuration." -ForegroundColor Yellow
        return
    }

    # Set console encoding for fzf interaction
    $originalOutputEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

        # Launch fzf with enhanced options
        $selectedProjectName = $enabledProjects.name | fzf `
            --prompt="Select project: " `
            --height=40% `
            --layout=reverse `
            --border `
            --preview-window=hidden
    }
    finally {
        [Console]::OutputEncoding = $originalOutputEncoding
    }

    # Process selection
    if (-not [string]::IsNullOrWhiteSpace($selectedProjectName)) {
        $selectedProject = $enabledProjects | Where-Object { $_.name -eq $selectedProjectName }

        if ($null -ne $selectedProject -and (Test-Path -Path $selectedProject.rootPath)) {
            Set-Location -Path $selectedProject.rootPath
            Write-Host "Switched to project: $($selectedProject.name)" -ForegroundColor Green

            # Update Windows Terminal tab title
            $newTitle = $selectedProject.name
            Write-Host -NoNewline "$([char]27)]0;$newTitle$([char]7)"
        } else {
            Write-Host "Error: Invalid path for project '$selectedProjectName'." -ForegroundColor Red
        }
    } else {
        Write-Host "Operation cancelled." -ForegroundColor Gray
    }
}

function Get-ProjectList {
    <#
    .SYNOPSIS
        List all enabled projects from Project Manager.

    .DESCRIPTION
        Displays all enabled projects with their names and paths.

    .PARAMETER ConfigPath
        Optional custom path to projects.json file.

    .EXAMPLE
        Get-ProjectList
        # Lists all enabled projects
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    # Determine config path (same logic as Switch-Project)
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $cursorPath = Join-Path $env:APPDATA "Cursor\User\globalStorage\alefragnani.project-manager\projects.json"
        $vscodePath = Join-Path $env:APPDATA "Code\User\globalStorage\alefragnani.project-manager\projects.json"

        if (Test-Path $cursorPath) {
            $ConfigPath = $cursorPath
        } elseif (Test-Path $vscodePath) {
            $ConfigPath = $vscodePath
        } else {
            Write-Host "Error: Project Manager configuration not found." -ForegroundColor Red
            return
        }
    }

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Error: Configuration file not found at: $ConfigPath" -ForegroundColor Red
        return
    }

    try {
        $jsonContent = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
        $allProjects = ConvertFrom-Json -InputObject $jsonContent
        $enabledProjects = $allProjects | Where-Object { $_.enabled }

        if ($null -eq $enabledProjects -or $enabledProjects.Count -eq 0) {
            Write-Host "No enabled projects found." -ForegroundColor Yellow
            return
        }

        Write-Host "`nEnabled Projects:" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray

        foreach ($project in $enabledProjects) {
            Write-Host "  $($project.name)" -ForegroundColor Green
            Write-Host "    Path: $($project.rootPath)" -ForegroundColor Gray
        }

        Write-Host "`nTotal: $($enabledProjects.Count) project(s)" -ForegroundColor Cyan
    } catch {
        Write-Host "Error: Failed to read configuration." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

# Export module members
Export-ModuleMember -Function Switch-Project, Get-ProjectList
