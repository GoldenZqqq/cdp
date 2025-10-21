<#
.SYNOPSIS
    cdp - A fast project directory switcher for PowerShell.

.DESCRIPTION
    cdp provides a fuzzy-search interface powered by fzf to quickly
    switch between projects. Compatible with Project Manager plugin.

.NOTES
    Name: cdp
    Author: GoldenZqqq
    Version: 1.2.2
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

    .PARAMETER WSL
        If specified, launches WSL and changes to the project directory within WSL.
        Windows paths are automatically converted to WSL mount points (/mnt/c/, etc.).

    .EXAMPLE
        Switch-Project
        # Opens fzf menu to select from enabled projects

    .EXAMPLE
        cdp
        # Using the default alias

    .EXAMPLE
        cdp -WSL
        # Select a project and launch WSL in that directory

    .NOTES
        Requires fzf to be installed. Install via: winget install fzf
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$WSL
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
    $customConfigPath = Join-Path $env:USERPROFILE ".cdp\projects.json"
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
    $fzfExitCode = 0
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

        # Launch fzf with enhanced options
        $selectedProjectName = $enabledProjects.name | fzf `
            --prompt="Select project: " `
            --height=40% `
            --layout=reverse `
            --border `
            --preview-window=hidden `
            --bind="ctrl-c:abort,ctrl-g:abort,esc:clear-query"
        $fzfExitCode = $LASTEXITCODE
    }
    finally {
        [Console]::OutputEncoding = $originalOutputEncoding
    }

    # Process selection
    if ($fzfExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($selectedProjectName)) {
        Write-Host "Operation cancelled." -ForegroundColor Gray
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($selectedProjectName)) {
        $selectedProject = $enabledProjects | Where-Object { $_.name -eq $selectedProjectName }

        if ($null -ne $selectedProject -and (Test-Path -Path $selectedProject.rootPath)) {
            if ($WSL) {
                # Convert Windows path to WSL path and launch WSL
                $wslPath = Convert-WindowsPathToWSL -WindowsPath $selectedProject.rootPath
                Write-Host "Launching WSL in project: $($selectedProject.name)" -ForegroundColor Green
                Write-Host "WSL path: $wslPath" -ForegroundColor Gray

                # Launch WSL with cd command
                wsl --cd $wslPath
            } else {
                Set-Location -Path $selectedProject.rootPath
                Write-Host "Switched to project: $($selectedProject.name)" -ForegroundColor Green

                # Update Windows Terminal tab title
                $newTitle = $selectedProject.name
                Write-Host -NoNewline "$([char]27)]0;$newTitle$([char]7)"
            }
        } else {
            Write-Host "Error: Invalid path for project '$selectedProjectName'." -ForegroundColor Red
        }
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
    $customConfigPath = Join-Path $env:USERPROFILE ".cdp\projects.json"
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

# Helper function to convert Windows path to WSL path
function Convert-WindowsPathToWSL {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowsPath
    )

    # Normalize path separators
    $normalizedPath = $WindowsPath -replace '\\', '/'

    # Convert drive letter to WSL mount point
    # C:\path\to\dir -> /mnt/c/path/to/dir
    if ($normalizedPath -match '^([A-Za-z]):(.*)$') {
        $driveLetter = $matches[1].ToLower()
        $pathRemainder = $matches[2]
        return "/mnt/$driveLetter$pathRemainder"
    }

    # If no drive letter found, return as-is (might already be WSL path)
    return $normalizedPath
}

# Helper function to get stored config choice path
function Get-StoredConfigChoice {
    $configChoiceFile = Join-Path $env:USERPROFILE ".cdp\config"
    if (Test-Path $configChoiceFile) {
        $storedPath = Get-Content -Path $configChoiceFile -Raw -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($storedPath)) {
            return $storedPath.Trim()
        }
    }
    return $null
}

# Helper function to save config choice
function Save-ConfigChoice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    $configChoiceFile = Join-Path $env:USERPROFILE ".cdp\config"
    $configDir = Split-Path -Parent $configChoiceFile

    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $ConfigPath | Out-File -FilePath $configChoiceFile -Encoding UTF8 -NoNewline
}

# Helper function to find all available config files
function Get-AllAvailableConfigs {
    $configs = @()

    # Check all possible locations
    $cursorPath = Join-Path $env:APPDATA "Cursor\User\globalStorage\alefragnani.project-manager\projects.json"
    $vscodePath = Join-Path $env:APPDATA "Code\User\globalStorage\alefragnani.project-manager\projects.json"
    $customConfigPath = Join-Path $env:USERPROFILE ".cdp\projects.json"

    if (Test-Path $cursorPath) {
        $configs += [PSCustomObject]@{
            Path = $cursorPath
            Source = "Cursor Project Manager"
        }
    }

    if (Test-Path $vscodePath) {
        $configs += [PSCustomObject]@{
            Path = $vscodePath
            Source = "VS Code Project Manager"
        }
    }

    if (Test-Path $customConfigPath) {
        $configs += [PSCustomObject]@{
            Path = $customConfigPath
            Source = "Custom Config (~/.cdp)"
        }
    }

    return $configs
}

# Helper function to get default config path
function Get-DefaultConfigPath {
    # Priority order:
    # 1. Environment variable (highest priority, skip selection)
    # 2. Stored user choice from previous selection (~/.cdp/config)
    # 3. If multiple configs exist, let user choose and save choice
    # 4. Otherwise return the first available or default path

    if (-not [string]::IsNullOrWhiteSpace($env:CDP_CONFIG)) {
        return $env:CDP_CONFIG
    }

    # Check for stored config choice
    $storedChoice = Get-StoredConfigChoice
    if ($storedChoice -and (Test-Path $storedChoice)) {
        return $storedChoice
    }

    # Find all available configs
    $availableConfigs = Get-AllAvailableConfigs

    # If no configs found, return default (will be created)
    if ($availableConfigs.Count -eq 0) {
        $customConfigPath = Join-Path $env:USERPROFILE ".cdp\projects.json"
        return $customConfigPath
    }

    # If only one config, use it and save the choice
    if ($availableConfigs.Count -eq 1) {
        $selectedPath = $availableConfigs[0].Path
        Save-ConfigChoice -ConfigPath $selectedPath
        return $selectedPath
    }

    # Multiple configs found - let user choose
    Write-Host "`nMultiple configuration files found:" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host ""

    for ($i = 0; $i -lt $availableConfigs.Count; $i++) {
        $config = $availableConfigs[$i]
        Write-Host "  [$($i + 1)] " -ForegroundColor Yellow -NoNewline
        Write-Host "$($config.Source)" -ForegroundColor Green
        Write-Host "      $($config.Path)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "Your choice will be saved. Use " -ForegroundColor Gray -NoNewline
    Write-Host "cdp-config" -ForegroundColor Cyan -NoNewline
    Write-Host " to change it later." -ForegroundColor Gray
    Write-Host "Or set " -ForegroundColor Gray -NoNewline
    Write-Host "`$env:CDP_CONFIG" -ForegroundColor Cyan -NoNewline
    Write-Host " to override." -ForegroundColor Gray
    Write-Host ""

    # Get user selection
    do {
        $selection = Read-Host "Select config file (1-$($availableConfigs.Count))"
        $selectedIndex = $null
        if ([int]::TryParse($selection, [ref]$selectedIndex)) {
            if ($selectedIndex -ge 1 -and $selectedIndex -le $availableConfigs.Count) {
                $selectedPath = $availableConfigs[$selectedIndex - 1].Path
                $selectedSource = $availableConfigs[$selectedIndex - 1].Source

                # Save the choice
                Save-ConfigChoice -ConfigPath $selectedPath

                Write-Host "`nUsing: $selectedSource" -ForegroundColor Green
                Write-Host "Path: $selectedPath" -ForegroundColor Gray
                Write-Host "Saved to: " -ForegroundColor Gray -NoNewline
                Write-Host "~/.cdp/config" -ForegroundColor Cyan
                Write-Host ""
                return $selectedPath
            }
        }
        Write-Host "Invalid selection. Please enter a number between 1 and $($availableConfigs.Count)." -ForegroundColor Red
    } while ($true)
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
        $Path = (Get-Location).Path
    }

    # Resolve to absolute path
    $resolvedPath = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Host "Error: Invalid path." -ForegroundColor Red
        return
    }

    # Convert to string
    $Path = $resolvedPath.Path

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
            rootPath = $Path
            enabled = $true
        }

        $projects = @($projects) + $newProject

        # Save updated config
        $projects | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigPath -Encoding UTF8

        Write-Host "Project added successfully!" -ForegroundColor Green
        Write-Host "  Name: $Name" -ForegroundColor Cyan
        Write-Host "  Path: $Path" -ForegroundColor Gray
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

function Set-ProjectConfig {
    <#
    .SYNOPSIS
        Change the active configuration file.

    .DESCRIPTION
        Allows you to switch between different project configuration files
        (Cursor, VS Code, custom config). Your choice will be saved and
        used for all future cdp commands.

    .EXAMPLE
        Set-ProjectConfig
        # Opens interactive menu to select a different config file

    .EXAMPLE
        cdp-config
        # Using the alias
    #>

    [CmdletBinding()]
    param()

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Change Configuration File" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Find all available configs
    $availableConfigs = Get-AllAvailableConfigs

    if ($availableConfigs.Count -eq 0) {
        Write-Host "No configuration files found." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Available options:" -ForegroundColor Cyan
        Write-Host "  1. Create a custom config with: " -NoNewline -ForegroundColor Gray
        Write-Host "cdp-add" -ForegroundColor Cyan
        Write-Host "  2. Install Project Manager extension in VS Code/Cursor" -ForegroundColor Gray
        return
    }

    # Show current config
    $currentConfig = Get-StoredConfigChoice
    if ($currentConfig) {
        Write-Host "Current configuration:" -ForegroundColor Cyan
        $currentSource = ($availableConfigs | Where-Object { $_.Path -eq $currentConfig }).Source
        if ($currentSource) {
            Write-Host "  $currentSource" -ForegroundColor Green
        }
        Write-Host "  $currentConfig" -ForegroundColor Gray
        Write-Host ""
    }

    # Show all available configs
    Write-Host "Available configuration files:" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host ""

    for ($i = 0; $i -lt $availableConfigs.Count; $i++) {
        $config = $availableConfigs[$i]
        $isCurrent = ($config.Path -eq $currentConfig)

        Write-Host "  [$($i + 1)] " -ForegroundColor Yellow -NoNewline
        Write-Host "$($config.Source)" -ForegroundColor Green -NoNewline

        if ($isCurrent) {
            Write-Host " (current)" -ForegroundColor Cyan
        } else {
            Write-Host ""
        }

        Write-Host "      $($config.Path)" -ForegroundColor Gray
    }

    Write-Host ""

    # Get user selection
    do {
        $selection = Read-Host "Select config file (1-$($availableConfigs.Count), or 0 to cancel)"

        if ($selection -eq "0") {
            Write-Host "`nOperation cancelled." -ForegroundColor Gray
            return
        }

        $selectedIndex = $null
        if ([int]::TryParse($selection, [ref]$selectedIndex)) {
            if ($selectedIndex -ge 1 -and $selectedIndex -le $availableConfigs.Count) {
                $selectedPath = $availableConfigs[$selectedIndex - 1].Path
                $selectedSource = $availableConfigs[$selectedIndex - 1].Source

                # Save the choice
                Save-ConfigChoice -ConfigPath $selectedPath

                Write-Host "`n========================================" -ForegroundColor Green
                Write-Host "  Configuration Updated!" -ForegroundColor Green
                Write-Host "========================================`n" -ForegroundColor Green
                Write-Host "Now using: " -NoNewline -ForegroundColor Gray
                Write-Host "$selectedSource" -ForegroundColor Green
                Write-Host "Path: " -NoNewline -ForegroundColor Gray
                Write-Host "$selectedPath" -ForegroundColor Cyan
                Write-Host "Saved to: " -NoNewline -ForegroundColor Gray
                Write-Host "~/.cdp/config" -ForegroundColor Cyan
                Write-Host ""
                return
            }
        }
        Write-Host "Invalid selection. Please enter a number between 0 and $($availableConfigs.Count)." -ForegroundColor Red
    } while ($true)
}

# Export module members
Set-Alias -Name cdp -Value Switch-Project
Set-Alias -Name cdp-add -Value Add-Project
Set-Alias -Name cdp-rm -Value Remove-Project
Set-Alias -Name cdp-ls -Value Get-ProjectList
Set-Alias -Name cdp-edit -Value Edit-ProjectConfig
Set-Alias -Name cdp-config -Value Set-ProjectConfig

Export-ModuleMember -Function Switch-Project, Get-ProjectList, Add-Project, Remove-Project, Edit-ProjectConfig, Set-ProjectConfig -Alias cdp, cdp-add, cdp-rm, cdp-ls, cdp-edit, cdp-config
