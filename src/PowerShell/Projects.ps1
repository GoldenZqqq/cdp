# cdp PowerShell domain: Projects.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

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

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
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

    # Read existing projects
    try {
        $document = Read-CdpJsonArrayMutationDocument -LiteralPath $ConfigPath
        $projects = @($document.Value)

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
            pinned = $false
            aliases = @()
            tags = @()
        }

        $actionTarget = "$Name ($Path)"
        if (-not $PSCmdlet.ShouldProcess($actionTarget, "Add project to $ConfigPath")) {
            if ($PassThru) {
                $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
                return New-CdpActionResult -Action 'add-project' -Target $actionTarget -Status $status -Changed $false -Details $newProject
            }
            return
        }

        $projects = @($projects) + $newProject

        # Save updated config
        [void](Write-CdpJsonFile -LiteralPath $ConfigPath -Value @($projects) -ExpectedFingerprint $document.Fingerprint)

        Write-Host "Project added successfully!" -ForegroundColor Green
        Write-Host "  Name: $Name" -ForegroundColor Cyan
        Write-Host "  Path: $Path" -ForegroundColor Gray
        Write-Host "  Config: $ConfigPath" -ForegroundColor Gray

        if ($PassThru) {
            return New-CdpActionResult -Action 'add-project' -Target $actionTarget -Status 'succeeded' -Changed $true -Details $newProject
        }

    } catch {
        Write-Host "Error: Failed to add project." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
        if ($PassThru) {
            return New-CdpActionResult -Action 'add-project' -Target ([string]$Name) -Status 'failed' -Changed $false -Error $_.Exception.Message
        }
    }
}

function Get-CdpUniqueName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$UsedNames
    )

    if ($UsedNames.Add($Name)) {
        return $Name
    }

    $index = 2
    do {
        $candidate = "$Name-$index"
        $index++
    } while (-not $UsedNames.Add($candidate))

    $candidate
}

function Repair-ProjectConfig {
    <#
    .SYNOPSIS
        Safely repair the active cdp project configuration.

    .DESCRIPTION
        Cleans only the JSON configuration, never project files. Invalid entries
        are removed, duplicate root paths keep the first entry, duplicate names
        are renamed, missing paths are disabled, and missing pinned fields are
        filled with false.
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    try {
        $document = Read-CdpJsonArrayMutationDocument -LiteralPath $ConfigPath
        $projects = @($document.Value)
        $usedNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        $usedPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        $summary = [ordered]@{ RemovedInvalid = 0; RemovedDuplicatePaths = 0; RenamedDuplicates = 0; DisabledMissingPaths = 0; AddedPinnedFields = 0; FixedEnabledFields = 0 }
        $cleanProjects = @()

        foreach ($project in $projects) {
            if ([string]::IsNullOrWhiteSpace($project.name) -or [string]::IsNullOrWhiteSpace($project.rootPath)) {
                $summary.RemovedInvalid++
                continue
            }

            $pathKey = Get-CdpComparablePath -Path ([string]$project.rootPath)
            if (-not $usedPaths.Add($pathKey)) {
                $summary.RemovedDuplicatePaths++
                continue
            }

            if (-not ($project.enabled -is [bool])) {
                if ($project.PSObject.Properties['enabled']) { $project.enabled = $false } else { $project | Add-Member -NotePropertyName enabled -NotePropertyValue $false }
                $summary.FixedEnabledFields++
            }

            if (-not $project.PSObject.Properties['pinned']) {
                $project | Add-Member -NotePropertyName pinned -NotePropertyValue $false
                $summary.AddedPinnedFields++
            }

            foreach ($propertyName in @('aliases', 'tags')) {
                if (-not $project.PSObject.Properties[$propertyName]) {
                    $project | Add-Member -NotePropertyName $propertyName -NotePropertyValue @()
                }
            }

            $uniqueName = Get-CdpUniqueName -Name ([string]$project.name) -UsedNames $usedNames
            if (-not [string]::Equals($uniqueName, [string]$project.name, [StringComparison]::Ordinal)) {
                $project.name = $uniqueName
                $summary.RenamedDuplicates++
            }

            if ($project.enabled -eq $true -and -not (Test-Path -LiteralPath ([string]$project.rootPath))) {
                $project.enabled = $false
                $summary.DisabledMissingPaths++
            }

            $cleanProjects += $project
        }

        $changeCount = 0
        foreach ($value in $summary.Values) { $changeCount += [int]$value }
        $details = [PSCustomObject]@{
            ConfigPath = $ConfigPath
            ProjectCount = $cleanProjects.Count
            RemovedInvalid = $summary.RemovedInvalid
            RemovedDuplicatePaths = $summary.RemovedDuplicatePaths
            RenamedDuplicates = $summary.RenamedDuplicates
            DisabledMissingPaths = $summary.DisabledMissingPaths
            AddedPinnedFields = $summary.AddedPinnedFields
            FixedEnabledFields = $summary.FixedEnabledFields
        }

        if ($changeCount -eq 0) {
            Write-Host "No project configuration repairs are needed." -ForegroundColor Green
            if ($PassThru) {
                return New-CdpActionResult -Action 'repair-config' -Target $ConfigPath -Status 'skipped' -Changed $false -Details $details
            }
            return
        }

        if (-not $PSCmdlet.ShouldProcess($ConfigPath, "Apply $changeCount project configuration repairs")) {
            if ($PassThru) {
                $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
                return New-CdpActionResult -Action 'repair-config' -Target $ConfigPath -Status $status -Changed $false -Details $details
            }
            return
        }

        [void](Write-CdpJsonFile -LiteralPath $ConfigPath -Value @($cleanProjects) -ExpectedFingerprint $document.Fingerprint)

        Write-Host "cdp config repaired: $ConfigPath" -ForegroundColor Green
        foreach ($item in $summary.GetEnumerator()) {
            Write-Host "  $($item.Key): $($item.Value)" -ForegroundColor Gray
        }

        if ($PassThru) {
            return New-CdpActionResult -Action 'repair-config' -Target $ConfigPath -Status 'succeeded' -Changed $true -Details $details
        }
    } catch {
        Write-Host "Error: Failed to repair project configuration." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
        if ($PassThru) {
            return New-CdpActionResult -Action 'repair-config' -Target $ConfigPath -Status 'failed' -Changed $false -Error $_.Exception.Message
        }
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

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
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
        $document = Read-CdpJsonDocument -LiteralPath $ConfigPath
        $projects = $document.Value

        if ($projects.Count -eq 0) {
            Write-Host "No projects found in configuration." -ForegroundColor Yellow
            return
        }

        # If no name provided, use fzf to select
        if ([string]::IsNullOrWhiteSpace($Name)) {
            $fzfCommand = Resolve-CdpFzfCommand
            if (-not $fzfCommand) {
                Write-Host "Error: Please provide project name or install fzf for interactive selection." -ForegroundColor Red
                return
            }

            $originalOutputEncoding = [Console]::OutputEncoding
            $originalInputEncoding = [Console]::InputEncoding
            try {
                [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
                [Console]::InputEncoding = [System.Text.Encoding]::UTF8
                $Name = $projects.name | & $fzfCommand `
                    --prompt="Select project to remove: " `
                    --height=60% `
                    --layout=reverse `
                    --border `
                    --no-mouse
            } finally {
                [Console]::OutputEncoding = $originalOutputEncoding
                [Console]::InputEncoding = $originalInputEncoding
            }

            if ([string]::IsNullOrWhiteSpace($Name)) {
                return
            }
        }

        # Find and remove project
        $projectToRemove = $projects | Where-Object { $_.name -eq $Name }
        if (-not $projectToRemove) {
            Write-Host "Error: Project not found: $Name" -ForegroundColor Red
            return
        }

        # Show the plan; ShouldProcess owns confirmation and WhatIf behavior.
        Write-Host "`nProject scheduled for removal:" -ForegroundColor Yellow
        Write-Host "  Name: $($projectToRemove.name)" -ForegroundColor Cyan
        Write-Host "  Path: $($projectToRemove.rootPath)" -ForegroundColor Gray
        if (-not $PSCmdlet.ShouldProcess([string]$projectToRemove.name, "Remove project from $ConfigPath")) {
            if ($PassThru) {
                $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
                return New-CdpActionResult -Action 'remove-project' -Target ([string]$projectToRemove.name) -Status $status -Changed $false -Details $projectToRemove
            }
            return
        }

        # Remove project
        $updatedProjects = $projects | Where-Object { $_.name -ne $Name }
        [void](Write-CdpJsonFile -LiteralPath $ConfigPath -Value @($updatedProjects) -ExpectedFingerprint $document.Fingerprint)

        Write-Host "`nProject removed successfully: $Name" -ForegroundColor Green

        if ($PassThru) {
            return New-CdpActionResult -Action 'remove-project' -Target ([string]$Name) -Status 'succeeded' -Changed $true -Details $projectToRemove
        }

    } catch {
        Write-Host "Error: Failed to remove project." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
        if ($PassThru) {
            return New-CdpActionResult -Action 'remove-project' -Target ([string]$Name) -Status 'failed' -Changed $false -Error $_.Exception.Message
        }
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

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [int]$Selection = 0,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

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

    # Resolve the explicit selection, retaining the interactive legacy path.
    if ($Selection -le 0) {
        $selectionText = Read-Host "Select config file (1-$($availableConfigs.Count), or 0 to cancel)"
        $parsedSelection = 0
        if (-not [int]::TryParse($selectionText, [ref]$parsedSelection) -or $parsedSelection -eq 0) {
            Write-Host "`nOperation cancelled." -ForegroundColor Gray
            return
        }
        $Selection = $parsedSelection
    }
    if ($Selection -lt 1 -or $Selection -gt $availableConfigs.Count) {
        throw "Invalid selection. Please choose a number between 1 and $($availableConfigs.Count)."
    }
    $selectedPath = $availableConfigs[$Selection - 1].Path
    $selectedSource = $availableConfigs[$Selection - 1].Source

    if (-not $PSCmdlet.ShouldProcess($selectedPath, 'Persist active cdp configuration choice')) {
        if ($PassThru) {
            $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
            return New-CdpActionResult -Action 'select-config' -Target $selectedPath -Status $status -Changed $false
        }
        return
    }
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
    if ($PassThru) {
        return New-CdpActionResult -Action 'select-config' -Target $selectedPath -Status 'succeeded' -Changed $true
    }
}
