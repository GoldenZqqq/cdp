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

    # Get config path
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    # Initialize config file if it doesn't exist and not using Project Manager
    $customConfigPath = Join-Path $env:USERPROFILE ".projswitch\projects.json"
    if ($ConfigPath -eq $customConfigPath) {
        Initialize-ConfigFile -ConfigPath $ConfigPath
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

    # Get config path
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    # Initialize config file if it doesn't exist and not using Project Manager
    $customConfigPath = Join-Path $env:USERPROFILE ".projswitch\projects.json"
    if ($ConfigPath -eq $customConfigPath) {
        Initialize-ConfigFile -ConfigPath $ConfigPath
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

        Write-Host "`nEnabled Projects ($($enabledProjects.Count)):" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Gray
        Write-Host ""

        $index = 1
        foreach ($project in $enabledProjects) {
            $number = "[$index]".PadRight(5)
            Write-Host "  $number" -ForegroundColor Gray -NoNewline
            Write-Host "$($project.name)" -ForegroundColor Green
            Write-Host "         $($project.rootPath)" -ForegroundColor DarkGray
            $index++
        }

        Write-Host ""
        Write-Host "Config file: $ConfigPath" -ForegroundColor DarkGray
    } catch {
        Write-Host "Error: Failed to read configuration." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

# Helper function to get default config path
function Get-DefaultConfigPath {
    # Priority order:
    # 1. Environment variable
    # 2. User's custom config directory
    # 3. Cursor Project Manager
    # 4. VS Code Project Manager

    if (-not [string]::IsNullOrWhiteSpace($env:PROJSWITCH_CONFIG)) {
        return $env:PROJSWITCH_CONFIG
    }

    # Check for custom config directory
    $customConfigPath = Join-Path $env:USERPROFILE ".projswitch\projects.json"
    if (Test-Path $customConfigPath) {
        return $customConfigPath
    }

    # Try Project Manager locations
    $cursorPath = Join-Path $env:APPDATA "Cursor\User\globalStorage\alefragnani.project-manager\projects.json"
    $vscodePath = Join-Path $env:APPDATA "Code\User\globalStorage\alefragnani.project-manager\projects.json"

    if (Test-Path $cursorPath) {
        return $cursorPath
    } elseif (Test-Path $vscodePath) {
        return $vscodePath
    }

    # Return custom config path as default (will be created if needed)
    return $customConfigPath
}

# Helper function to ensure config file exists
function Initialize-ConfigFile {
    param(
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        $configDir = Split-Path -Parent $ConfigPath
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        # Create empty project array
        '[]' | Out-File -FilePath $ConfigPath -Encoding UTF8
        Write-Host "Created new config file at: $ConfigPath" -ForegroundColor Green
    }
}

function Add-Project {
    <#
    .SYNOPSIS
        Add the current directory to the project list.

    .DESCRIPTION
        Quickly adds the current working directory to your project configuration.
        If no name is provided, uses the directory name as the project name.

    .PARAMETER Name
        Optional custom name for the project. If not specified, uses the directory name.

    .PARAMETER Path
        Optional path to add. If not specified, uses the current directory.

    .PARAMETER ConfigPath
        Optional custom path to projects.json file.

    .EXAMPLE
        Add-Project
        # Adds current directory with folder name as project name

    .EXAMPLE
        Add-Project -Name "My Awesome Project"
        # Adds current directory with custom name

    .EXAMPLE
        Add-Project -Path "E:\Projects\MyApp" -Name "MyApp"
        # Adds specific path with custom name
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    # Determine path to add
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Get-Location
    }

    # Resolve to absolute path
    $Path = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $Path) {
        Write-Host "Error: Invalid path." -ForegroundColor Red
        return
    }

    # Determine project name
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = Split-Path -Leaf $Path
    }

    # Get config path
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    # Initialize config file if needed
    Initialize-ConfigFile -ConfigPath $ConfigPath

    # Read existing projects
    try {
        $jsonContent = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
        $projects = ConvertFrom-Json -InputObject $jsonContent

        # Check if project already exists
        $existingProject = $projects | Where-Object { $_.rootPath -eq $Path }
        if ($existingProject) {
            Write-Host "Project already exists: $($existingProject.name)" -ForegroundColor Yellow
            Write-Host "Path: $($existingProject.rootPath)" -ForegroundColor Gray
            return
        }

        # Add new project
        $newProject = [PSCustomObject]@{
            name = $Name
            rootPath = $Path.Path
            enabled = $true
        }

        $projects = @($projects) + $newProject

        # Save updated config
        $projects | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigPath -Encoding UTF8

        Write-Host "Project added successfully!" -ForegroundColor Green
        Write-Host "  Name: $Name" -ForegroundColor Cyan
        Write-Host "  Path: $($Path.Path)" -ForegroundColor Gray
        Write-Host "  Config: $ConfigPath" -ForegroundColor Gray

    } catch {
        Write-Host "Error: Failed to add project." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

function Remove-Project {
    <#
    .SYNOPSIS
        Remove a project from the configuration.

    .DESCRIPTION
        Removes a project by name from your project configuration.

    .PARAMETER Name
        Name of the project to remove. Supports fuzzy matching.

    .PARAMETER ConfigPath
        Optional custom path to projects.json file.

    .EXAMPLE
        Remove-Project -Name "MyProject"
        # Removes project named "MyProject"

    .EXAMPLE
        Remove-Project
        # Opens interactive fzf menu to select project to remove
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    # Get config path
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Error: Configuration file not found at: $ConfigPath" -ForegroundColor Red
        return
    }

    try {
        $jsonContent = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
        $projects = ConvertFrom-Json -InputObject $jsonContent

        if ($projects.Count -eq 0) {
            Write-Host "No projects found in configuration." -ForegroundColor Yellow
            return
        }

        # If no name provided, use fzf to select
        if ([string]::IsNullOrWhiteSpace($Name)) {
            if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
                Write-Host "Error: Please provide project name or install fzf for interactive selection." -ForegroundColor Red
                return
            }

            $originalOutputEncoding = [Console]::OutputEncoding
            try {
                [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
                $Name = $projects.name | fzf --prompt="Select project to remove: " --height=40% --layout=reverse --border
            } finally {
                [Console]::OutputEncoding = $originalOutputEncoding
            }

            if ([string]::IsNullOrWhiteSpace($Name)) {
                Write-Host "Operation cancelled." -ForegroundColor Gray
                return
            }
        }

        # Find and remove project
        $projectToRemove = $projects | Where-Object { $_.name -eq $Name }
        if (-not $projectToRemove) {
            Write-Host "Error: Project not found: $Name" -ForegroundColor Red
            return
        }

        # Confirm removal
        Write-Host "`nAre you sure you want to remove this project?" -ForegroundColor Yellow
        Write-Host "  Name: $($projectToRemove.name)" -ForegroundColor Cyan
        Write-Host "  Path: $($projectToRemove.rootPath)" -ForegroundColor Gray
        $confirm = Read-Host "`nContinue? (y/N)"

        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-Host "Operation cancelled." -ForegroundColor Gray
            return
        }

        # Remove project
        $updatedProjects = $projects | Where-Object { $_.name -ne $Name }
        $updatedProjects | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigPath -Encoding UTF8

        Write-Host "`nProject removed successfully: $Name" -ForegroundColor Green

    } catch {
        Write-Host "Error: Failed to remove project." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

function Edit-ProjectConfig {
    <#
    .SYNOPSIS
        Open the project configuration file in your default editor.

    .DESCRIPTION
        Quickly opens the projects.json file for manual editing.

    .PARAMETER ConfigPath
        Optional custom path to projects.json file.

    .EXAMPLE
        Edit-ProjectConfig
        # Opens config file in default editor
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    # Get config path
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    # Initialize config file if needed
    Initialize-ConfigFile -ConfigPath $ConfigPath

    Write-Host "Opening config file: $ConfigPath" -ForegroundColor Cyan

    # Try to open with VS Code/Cursor first, then default editor
    if (Get-Command code -ErrorAction SilentlyContinue) {
        code $ConfigPath
    } elseif (Get-Command cursor -ErrorAction SilentlyContinue) {
        cursor $ConfigPath
    } else {
        Start-Process $ConfigPath
    }
}

# Export module members
Set-Alias -Name cdp -Value Switch-Project
Set-Alias -Name add -Value Add-Project
Set-Alias -Name rm -Value Remove-Project
Set-Alias -Name ls -Value Get-ProjectList
Set-Alias -Name edit-config -Value Edit-ProjectConfig

Export-ModuleMember -Function Switch-Project, Get-ProjectList, Add-Project, Remove-Project, Edit-ProjectConfig -Alias cdp, add, rm, ls, edit-config
