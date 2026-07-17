<#
.SYNOPSIS
    cdp - A fast project directory switcher for PowerShell.

.DESCRIPTION
    cdp provides a fuzzy-search interface powered by fzf to quickly
    switch between projects. Compatible with Project Manager plugin.

.NOTES
    Name: cdp
    Author: GoldenZqqq
    Version: 2.0.4
    License: MIT
#>

$script:CdpProjectConfigCache = @{}
$script:CdpFzfCommand = $null

function Get-CdpCurrentModule {
    Get-Module -Name cdp |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1
}

function Get-CdpCurrentModuleVersion {
    $module = Get-CdpCurrentModule

    if ($module -and $module.Version) {
        return [version]$module.Version
    }

    return $null
}

function Get-CdpVersionText {
    $version = Get-CdpCurrentModuleVersion
    if ($version) {
        return $version.ToString()
    }

    return "unknown"
}

function Write-CdpBrandHeader {
    $versionText = Get-CdpVersionText
    $logo = @(
        '         _'
        '  ___ __| |_ __'
        ' / __/ _` | "_ \'
        '| (_| (_| | |_) |'
        ' \___\__,_| .__/'
        '          |_|'
    )

    Write-Host ""
    foreach ($line in $logo) {
        Write-Host $line -ForegroundColor Cyan
    }
    Write-Host "cdp v$versionText" -ForegroundColor Green
    Write-Host "fast project switching for PowerShell and WSL" -ForegroundColor Gray
    Write-Host ""
}

function Get-CdpPickerHeader {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ShownProjectCount,

        [Parameter(Mandatory = $true)]
        [int]$TotalProjectCount,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    $versionText = Get-CdpVersionText
    $projectText = if ($ShownProjectCount -eq $TotalProjectCount) {
        "$TotalProjectCount projects"
    } else {
        "$ShownProjectCount shown / $TotalProjectCount projects"
    }

    "cdp v$versionText | $projectText | enter to warp | $ConfigPath"
}

function Format-CdpAnsiText {
    param(
        [AllowNull()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Code
    )

    $escape = [char]27
    "${escape}[${Code}m$Text${escape}[0m"
}

function ConvertTo-CdpPickerField {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return ""
    }

    $Value -replace "[`r`n`t]+", " "
}

function Test-CdpProjectPinned {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Project
    )

    $pinnedProperty = $Project.PSObject.Properties['pinned']
    return $null -ne $pinnedProperty -and $Project.pinned -eq $true
}

function Get-CdpProjectStringList {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Project,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName
    )

    $property = $Project.PSObject.Properties[$PropertyName]
    if ($null -eq $property -or $null -eq $property.Value) {
        return @()
    }

    @($property.Value | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
}

function Sort-CdpProjectsForDisplay {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Projects
    )

    $indexedProjects = for ($i = 0; $i -lt $Projects.Count; $i++) {
        [PSCustomObject]@{
            Project = $Projects[$i]
            Index = $i
            PinRank = if (Test-CdpProjectPinned -Project $Projects[$i]) { 0 } else { 1 }
        }
    }

    @($indexedProjects |
        Sort-Object -Property PinRank, Index |
        ForEach-Object { $_.Project })
}

function New-CdpPickerLine {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Project,

        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    $rawName = ConvertTo-CdpPickerField -Value $Project.name
    $rawPath = ConvertTo-CdpPickerField -Value $Project.rootPath
    $displayIndex = Format-CdpAnsiText -Text ("{0,3}" -f $Index) -Code "38;5;242"
    $nameText = if (Test-CdpProjectPinned -Project $Project) { "[pin] $rawName" } else { $rawName }
    $displayName = Format-CdpAnsiText -Text $nameText -Code "1;38;5;81"
    $displayPath = Format-CdpAnsiText -Text $rawPath -Code "38;5;245"

    "{0}`t{1}`t{2}`t{3}`t{4}`t{5}" -f $Index, $rawName, $rawPath, $displayIndex, $displayName, $displayPath
}

function Get-CdpPickerPreviewContent {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Project
    )

    $rootPath = [string]$Project.rootPath
    $pathExists = Test-Path -LiteralPath $rootPath
    $pathState = if ($pathExists) { "path exists" } else { "path missing" }
    $gitPath = Join-Path $rootPath ".git"
    $gitState = if ($pathExists -and (Test-Path -LiteralPath $gitPath)) {
        "git repo detected"
    } else {
        "git repo not detected"
    }

    @(
        "cdp project"
        "-----------"
        "name   $($Project.name)"
        "path   $rootPath"
        "pin    $(if (Test-CdpProjectPinned -Project $Project) { 'pinned' } else { 'not pinned' })"
        "alias  $((Get-CdpProjectStringList -Project $Project -PropertyName 'aliases') -join ', ')"
        "tags   $((Get-CdpProjectStringList -Project $Project -PropertyName 'tags') -join ', ')"
        ""
        "state  $pathState"
        "git    $gitState"
        ""
        "Enter  switch to this project"
        "Esc    cancel"
    )
}

function New-CdpPickerPreviewDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Projects
    )

    $previewDir = Join-Path ([System.IO.Path]::GetTempPath()) "cdp-fzf-$PID-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $previewDir -Force | Out-Null

    $index = 1
    foreach ($project in $Projects) {
        $previewPath = Join-Path $previewDir "$index.txt"
        Get-CdpPickerPreviewContent -Project $project |
            Set-Content -Path $previewPath -Encoding UTF8
        $index++
    }

    @'
param(
    [Parameter(Mandatory = $false)]
    [string]$Index
)

$safeIndex = $Index -replace '[^0-9]', ''
if ([string]::IsNullOrWhiteSpace($safeIndex)) {
    "cdp project"
    "-----------"
    "preview unavailable"
    return
}

$previewPath = Join-Path $PSScriptRoot "$safeIndex.txt"
if (Test-Path -LiteralPath $previewPath) {
    Get-Content -LiteralPath $previewPath
    return
}

"cdp project"
"-----------"
"preview unavailable"
"missing: $previewPath"
'@ | Set-Content -Path (Join-Path $previewDir "preview.ps1") -Encoding UTF8

    $previewDir
}

function Get-CdpPickerPreviewCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PreviewDir
    )

    $scriptPath = Join-Path $PreviewDir "preview.ps1"
    $escapedScriptPath = $scriptPath -replace '"', '\"'
    "powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$escapedScriptPath`" {1}"
}

function Get-CdpFzfColorTheme {
    "fg:#cdd6f4,bg:-1,hl:#89dceb,fg+:#ffffff,bg+:#313244,hl+:#f5c2e7,prompt:#94e2d5,pointer:#f38ba8,marker:#a6e3a1,border:#89b4fa,header:#bac2de,info:#fab387"
}

function Get-CdpDisplayWidth {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return 0 }
    $width = 0
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int]$ch
        if ($code -ge 0x1100 -and (
            ($code -ge 0x1100 -and $code -le 0x115F) -or
            ($code -ge 0x2E80 -and $code -le 0xA4CF) -or
            ($code -ge 0xAC00 -and $code -le 0xD7A3) -or
            ($code -ge 0xF900 -and $code -le 0xFAFF) -or
            ($code -ge 0xFE30 -and $code -le 0xFE4F) -or
            ($code -ge 0xFF00 -and $code -le 0xFF60) -or
            ($code -ge 0xFFE0 -and $code -le 0xFFE6)
        )) {
            $width += 2
        } else {
            $width += 1
        }
    }
    return $width
}

function Pad-CdpText {
    param([AllowNull()][string]$Text, [int]$Width)
    if ($null -eq $Text) { $Text = "" }
    $displayWidth = Get-CdpDisplayWidth $Text
    $padding = $Width - $displayWidth
    if ($padding -gt 0) {
        return $Text + (" " * $padding)
    }
    return $Text
}

function Limit-CdpText {
    param(
        [AllowNull()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$MaxLength
    )

    if ($null -eq $Text -or $Text -eq "") {
        return ""
    }

    if ((Get-CdpDisplayWidth $Text) -le $MaxLength) {
        return $Text
    }

    $result = ""
    $currentWidth = 0
    foreach ($ch in $Text.ToCharArray()) {
        $chWidth = if (([int]$ch) -ge 0x2E80) { 2 } else { 1 }
        if ($currentWidth + $chWidth -gt $MaxLength - 3) {
            break
        }
        $result += $ch
        $currentWidth += $chWidth
    }
    return $result + "..."
}

function Invoke-CdpOnEnter {
    param([object]$Project)

    if (-not $Project.PSObject.Properties['onEnter'] -or $null -eq $Project.onEnter) {
        return
    }

    $onEnter = $Project.onEnter

    try {
        if ($onEnter -is [string]) {
            if (-not [string]::IsNullOrWhiteSpace($onEnter)) {
                Invoke-Expression $onEnter
            }
        } elseif ($onEnter.PSObject.Properties['env']) {
            $onEnter.env.PSObject.Properties | ForEach-Object {
                [System.Environment]::SetEnvironmentVariable($_.Name, [string]$_.Value, 'Process')
            }
        }

        if ($onEnter -isnot [string] -and $onEnter.PSObject.Properties['powershell']) {
            $psCmd = [string]$onEnter.powershell
            if (-not [string]::IsNullOrWhiteSpace($psCmd)) {
                Invoke-Expression $psCmd
            }
        }
    } catch {
        Write-Host "  onEnter warning: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

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

    .PARAMETER Query
        Optional project name or path query. If exactly one enabled project
        matches, switches directly. If multiple projects match, opens fzf with
        only those matches.

    .PARAMETER WSL
        If specified, launches WSL and changes to the project directory within WSL.
        Windows paths are automatically converted to WSL mount points (/mnt/c/, etc.).

    .PARAMETER Open
        Optional command to start after switching to the selected project. Common
        values include code, cursor, codex, claude, and gemini.

    .EXAMPLE
        Switch-Project
        # Opens fzf menu to select from enabled projects

    .EXAMPLE
        cdp
        # Using the default alias

    .EXAMPLE
        cdp api
        # Directly switches to the matching project, or filters fzf to matches

    .EXAMPLE
        cdp -WSL
        # Select a project and launch WSL in that directory

    .EXAMPLE
        cdp api -Open codex
        # Switches to the matching project and starts Codex there

    .NOTES
        Requires fzf to be installed. Install via: winget install fzf
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [switch]$WSL,

        [Parameter(Mandatory = $false)]
        [Alias('o')]
        [string]$Open
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
        $configData = Get-CdpProjectConfig -ConfigPath $ConfigPath
        $enabledProjects = @(Sort-CdpProjectsForDisplay -Projects @($configData.EnabledProjects))
    } catch {
        Write-Host "Error: Failed to read or parse configuration file." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
        return
    }

    if ($null -eq $enabledProjects -or $enabledProjects.Count -eq 0) {
        Write-Host "No enabled projects found in configuration." -ForegroundColor Yellow
        return
    }

    $projectsForSelection = $enabledProjects
    $selectedProjectName = $null

    if (-not [string]::IsNullOrWhiteSpace($Query)) {
        $queryMatches = @(Get-CdpProjectMatches -Projects $enabledProjects -Query $Query)

        if ($queryMatches.Count -eq 0) {
            Write-Host "No project matched query: $Query" -ForegroundColor Yellow
            return
        }

        if ($queryMatches.Count -eq 1) {
            $selectedProjectName = $queryMatches[0].name
        } else {
            $projectsForSelection = $queryMatches
        }
    }

    if ([string]::IsNullOrWhiteSpace($selectedProjectName)) {
        # Check if fzf is installed only when interactive selection is needed.
        $fzfCommand = Resolve-CdpFzfCommand
        if (-not $fzfCommand) {
            Write-Host "Error: 'fzf' command not found." -ForegroundColor Red
            Write-Host "Please install fzf first: winget install fzf" -ForegroundColor Cyan
            Write-Host "Then restart your terminal." -ForegroundColor Cyan
            return
        }

        # Set console encoding for fzf interaction
        # CRITICAL: Must set BOTH InputEncoding and OutputEncoding for IME to work
        $originalOutputEncoding = [Console]::OutputEncoding
        $originalInputEncoding = [Console]::InputEncoding
        $previewDir = $null
        try {
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            [Console]::InputEncoding = [System.Text.Encoding]::UTF8

            # Launch fzf with themed ANSI rows and a lightweight project preview.
            # Note: --no-mouse prevents IME mouse click conflicts
            $prompt = if ([string]::IsNullOrWhiteSpace($Query)) {
                "cdp > "
            } else {
                "cdp ($Query) > "
            }
            $header = Get-CdpPickerHeader `
                -ShownProjectCount $projectsForSelection.Count `
                -TotalProjectCount $enabledProjects.Count `
                -ConfigPath $ConfigPath
            $previewDir = New-CdpPickerPreviewDirectory -Projects $projectsForSelection
            $previewCommand = Get-CdpPickerPreviewCommand -PreviewDir $previewDir
            $colorOption = "--color=$(Get-CdpFzfColorTheme)"
            $pickerLines = for ($i = 0; $i -lt $projectsForSelection.Count; $i++) {
                New-CdpPickerLine -Project $projectsForSelection[$i] -Index ($i + 1)
            }

            $selectedLine = $pickerLines | & $fzfCommand `
                --prompt=$prompt `
                --header=$header `
                --height=70% `
                --layout=reverse `
                --border=rounded `
                --border-label=" cdp warp " `
                --ansi `
                --delimiter="$([char]9)" `
                --with-nth=4,5,6 `
                --nth=2,3 `
                --no-mouse `
                --preview=$previewCommand `
                --preview-window=right:50%:wrap `
                --pointer=">" `
                --marker="*" `
                $colorOption

            if (-not [string]::IsNullOrWhiteSpace($selectedLine)) {
                $selectedFields = $selectedLine -split "`t"
                if ($selectedFields.Count -ge 2) {
                    $selectedProjectName = $selectedFields[1]
                }
            }
        }
        finally {
            [Console]::OutputEncoding = $originalOutputEncoding
            [Console]::InputEncoding = $originalInputEncoding
            if (-not [string]::IsNullOrWhiteSpace($previewDir) -and (Test-Path -LiteralPath $previewDir)) {
                Remove-Item -LiteralPath $previewDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Process selection
    # Note: Don't check exit code to avoid IME-related false cancellations
    # Only check if a project was actually selected
    if ([string]::IsNullOrWhiteSpace($selectedProjectName)) {
        # User cancelled or no selection made
        return
    }

    $selectedProject = @($enabledProjects | Where-Object {
        $_.name -eq $selectedProjectName
    }) | Select-Object -First 1

    if ($null -ne $selectedProject -and (Test-Path -Path $selectedProject.rootPath)) {
        if ($WSL) {
            # Convert Windows path to WSL path and launch WSL
            $wslPath = Convert-WindowsPathToWSL -WindowsPath $selectedProject.rootPath
            $launchText = if ([string]::IsNullOrWhiteSpace($Open)) {
                "Launching WSL in project: $($selectedProject.name)"
            } else {
                "Launching WSL workspace: $($selectedProject.name)"
            }
            Write-Host $launchText -ForegroundColor Green
            Write-Host "WSL path: $wslPath" -ForegroundColor Gray

            Add-CdpRecentProject -Project $selectedProject

            if ([string]::IsNullOrWhiteSpace($Open)) {
                # Launch WSL with cd command
                wsl --cd $wslPath
            } else {
                Invoke-CdpWorkspaceLauncher -Project $selectedProject -Open $Open -WSL
            }
        } else {
            Set-Location -Path $selectedProject.rootPath
            Add-CdpRecentProject -Project $selectedProject
            Write-Host "Switched to project: $($selectedProject.name)" -ForegroundColor Green

            # Update Windows Terminal tab title
            $newTitle = $selectedProject.name
            Write-Host -NoNewline "$([char]27)]0;$newTitle$([char]7)"

            Invoke-CdpOnEnter -Project $selectedProject

            if (-not [string]::IsNullOrWhiteSpace($Open)) {
                Invoke-CdpWorkspaceLauncher -Project $selectedProject -Open $Open
            }
        }
    } else {
        Write-Host "Error: Invalid path for project '$selectedProjectName'." -ForegroundColor Red
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
        $configData = Get-CdpProjectConfig -ConfigPath $ConfigPath
        $enabledProjects = @(Sort-CdpProjectsForDisplay -Projects @($configData.EnabledProjects))

        if ($null -eq $enabledProjects -or $enabledProjects.Count -eq 0) {
            Write-Host "No enabled projects found." -ForegroundColor Yellow
            return
        }

        $nameWidth = 14
        foreach ($project in $enabledProjects) {
            $projectName = [string]$project.name
            $nameWidth = [Math]::Max($nameWidth, $projectName.Length)
        }
        $nameWidth = [Math]::Min($nameWidth, 30)

        Write-Host "`ncdp projects " -ForegroundColor Cyan -NoNewline
        Write-Host "($($enabledProjects.Count) enabled)" -ForegroundColor DarkGray
        Write-Host ("-" * 104) -ForegroundColor DarkGray
        Write-Host ("  {0,-4} " -f "#") -ForegroundColor DarkGray -NoNewline
        Write-Host ("{0,-5} " -f "Pin") -ForegroundColor DarkGray -NoNewline
        Write-Host (("{0,-$nameWidth} " -f "Project")) -ForegroundColor Cyan -NoNewline
        Write-Host "Path" -ForegroundColor DarkGray
        Write-Host ("-" * 104) -ForegroundColor DarkGray

        $index = 1
        foreach ($project in $enabledProjects) {
            $number = "{0:00}" -f $index
            $projectName = Limit-CdpText -Text ([string]$project.name) -MaxLength $nameWidth
            $pinText = if (Test-CdpProjectPinned -Project $project) { "*" } else { "" }
            Write-Host ("  {0,-4} " -f $number) -ForegroundColor DarkGray -NoNewline
            Write-Host ("{0,-5} " -f $pinText) -ForegroundColor Yellow -NoNewline
            Write-Host (("{0,-$nameWidth} " -f $projectName)) -ForegroundColor Green -NoNewline
            Write-Host "$($project.rootPath)" -ForegroundColor DarkGray
            $index++
        }

        Write-Host ("-" * 104) -ForegroundColor DarkGray
        Write-Host "config: $ConfigPath" -ForegroundColor DarkGray
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

function Resolve-CdpFzfCommand {
    if (-not [string]::IsNullOrWhiteSpace($env:CDP_FZF_PATH)) {
        $configuredPath = [Environment]::ExpandEnvironmentVariables($env:CDP_FZF_PATH)
        if (Test-Path -LiteralPath $configuredPath -PathType Leaf) {
            $script:CdpFzfCommand = (Get-Item -LiteralPath $configuredPath).FullName
            return $script:CdpFzfCommand
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($script:CdpFzfCommand) -and
        (Test-Path -LiteralPath $script:CdpFzfCommand -PathType Leaf)) {
        return $script:CdpFzfCommand
    }

    $fzfCommand = Get-Command fzf -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($fzfCommand) {
        $script:CdpFzfCommand = if ([string]::IsNullOrWhiteSpace($fzfCommand.Path)) {
            $fzfCommand.Name
        } else {
            $fzfCommand.Path
        }
        return $script:CdpFzfCommand
    }

    return $null
}

function Clear-CdpProjectConfigCache {
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $script:CdpProjectConfigCache.Clear()
        return
    }

    try {
        $cacheKey = (Get-Item -LiteralPath $ConfigPath -ErrorAction Stop).FullName
        [void]$script:CdpProjectConfigCache.Remove($cacheKey)
    } catch {
        $script:CdpProjectConfigCache.Clear()
    }
}

function Get-CdpProjectConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    $configItem = Get-Item -LiteralPath $ConfigPath -ErrorAction Stop
    $cacheKey = $configItem.FullName
    $cachedConfig = $script:CdpProjectConfigCache[$cacheKey]

    if ($cachedConfig -and
        $cachedConfig.Length -eq $configItem.Length -and
        $cachedConfig.LastWriteTimeUtcTicks -eq $configItem.LastWriteTimeUtc.Ticks) {
        return $cachedConfig
    }

    $jsonContent = Get-Content -LiteralPath $configItem.FullName -Raw -Encoding UTF8
    $allProjects = ConvertFrom-Json -InputObject $jsonContent
    $projects = @()
    if ($null -ne $allProjects) {
        $projects = @($allProjects)
    }

    $configData = [PSCustomObject]@{
        Path = $configItem.FullName
        Length = $configItem.Length
        LastWriteTimeUtcTicks = $configItem.LastWriteTimeUtc.Ticks
        Projects = $projects
        EnabledProjects = @($projects | Where-Object { $_.enabled })
    }

    $script:CdpProjectConfigCache[$cacheKey] = $configData
    return $configData
}

function Get-CdpProjectMatches {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Projects,

        [Parameter(Mandatory = $true)]
        [string]$Query
    )

    $comparison = [StringComparison]::OrdinalIgnoreCase

    if ($Query.StartsWith('@')) {
        $tagQuery = $Query.Substring(1)
        return @($Projects | Where-Object {
            @(Get-CdpProjectStringList -Project $_ -PropertyName 'tags') |
                Where-Object { [string]::Equals($_, $tagQuery, $comparison) }
        })
    }

    $exactMatches = @($Projects | Where-Object {
        $projectAliases = @(Get-CdpProjectStringList -Project $_ -PropertyName 'aliases')
        [string]::Equals([string]$_.name, $Query, $comparison) -or
            @($projectAliases | Where-Object { [string]::Equals($_, $Query, $comparison) }).Count -gt 0
    })

    if ($exactMatches.Count -gt 0) {
        return $exactMatches
    }

    return @($Projects | Where-Object {
        $projectName = if ($null -eq $_.name) { "" } else { [string]$_.name }
        $projectPath = if ($null -eq $_.rootPath) { "" } else { [string]$_.rootPath }
        $projectAliases = @(Get-CdpProjectStringList -Project $_ -PropertyName 'aliases')
        $projectTags = @(Get-CdpProjectStringList -Project $_ -PropertyName 'tags')

        $projectName.IndexOf($Query, $comparison) -ge 0 -or
            $projectPath.IndexOf($Query, $comparison) -ge 0 -or
            @($projectAliases | Where-Object { $_.IndexOf($Query, $comparison) -ge 0 }).Count -gt 0 -or
            @($projectTags | Where-Object { $_.IndexOf($Query, $comparison) -ge 0 }).Count -gt 0
    })
}

function Test-CdpConfigPathArgument {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Argument
    )

    if ([string]::IsNullOrWhiteSpace($Argument)) {
        return $false
    }

    if (Test-Path -LiteralPath $Argument) {
        return $true
    }

    return $Argument.EndsWith(".json", [StringComparison]::OrdinalIgnoreCase) -or
        $Argument.Contains('\') -or
        $Argument.Contains('/') -or
        $Argument.StartsWith('~') -or
        $Argument -match '^[A-Za-z]:'
}

function Get-CdpWorkspaceLauncher {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Open
    )

    $launcherName = $Open.Trim()
    $normalizedName = $launcherName.ToLowerInvariant()
    $command = $launcherName
    $arguments = @()
    $label = $launcherName

    switch ($normalizedName) {
        { $_ -in @('code', 'vscode') } {
            $command = 'code'
            $arguments = @('.')
            $label = 'VS Code'
        }
        'cursor' {
            $command = 'cursor'
            $arguments = @('.')
            $label = 'Cursor'
        }
        'codex' { $label = 'Codex' }
        'claude' { $label = 'Claude' }
        'gemini' { $label = 'Gemini' }
    }

    [PSCustomObject]@{
        Name = $launcherName
        Label = $label
        Command = $command
        Arguments = $arguments
    }
}

function Invoke-CdpWorkspaceLauncher {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Project,

        [Parameter(Mandatory = $true)]
        [string]$Open,

        [Parameter(Mandatory = $false)]
        [switch]$WSL
    )

    if ([string]::IsNullOrWhiteSpace($Open)) {
        return
    }

    $launcher = Get-CdpWorkspaceLauncher -Open $Open
    $workingDirectory = if ($WSL) {
        Convert-WindowsPathToWSL -WindowsPath ([string]$Project.rootPath)
    } else {
        [string]$Project.rootPath
    }

    $result = [PSCustomObject]@{
        ProjectName = [string]$Project.name
        WorkingDirectory = $workingDirectory
        WSL = [bool]$WSL
        Name = $launcher.Name
        Label = $launcher.Label
        Command = $launcher.Command
        Arguments = @($launcher.Arguments)
    }

    if ($env:CDP_OPEN_DRY_RUN -eq '1') {
        Write-Host "Would open $($Project.name) with $($launcher.Label)." -ForegroundColor Gray
        return $result
    }

    Write-Host "Opening with $($launcher.Label)..." -ForegroundColor Cyan
    if ($WSL) {
        wsl --cd $workingDirectory --exec $launcher.Command @($launcher.Arguments)
        return
    }

    if (-not (Get-Command $launcher.Command -ErrorAction SilentlyContinue)) {
        Write-Host "Error: '$($launcher.Command)' command not found." -ForegroundColor Red
        return
    }

    & $launcher.Command @($launcher.Arguments)
}

function New-CdpInvocation {
    param([string]$Kind)

    [PSCustomObject]@{
        Kind = $Kind
        Command = $Kind
        ConfigPath = $null
        Query = $null
        Open = $null
        DirtyOnly = $false
        Fix = $false
        Push = $false
        TagFilter = $null
        WorkspaceAction = $null
        WorkspaceName = $null
        Projects = @()
        Name = $null
        Value = $null
        RootPath = $null
        MaxDepth = 4
        Count = 10
    }
}

function Get-CdpInvocationTokens {
    param([string]$Command, [string]$ConfigPath, [string[]]$RemainingArgs)

    $tokens = @()
    if (-not [string]::IsNullOrWhiteSpace($Command)) { $tokens += $Command }
    if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) { $tokens += $ConfigPath }
    if ($null -ne $RemainingArgs) { $tokens += @($RemainingArgs) }
    @($tokens | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Split-CdpCommonOptions {
    param([string[]]$Tokens, [string]$Open)

    $positionals = New-Object 'System.Collections.Generic.List[string]'
    $resolvedOpen = $Open
    $resolvedConfig = $null
    for ($i = 0; $i -lt $Tokens.Count; $i++) {
        $token = $Tokens[$i]
        if ($token -in @('--open', '-open', '-o')) {
            if ($i + 1 -ge $Tokens.Count) { throw "Missing value after --open." }
            if (-not [string]::IsNullOrWhiteSpace($resolvedOpen)) { throw "The --open option was specified more than once." }
            $resolvedOpen = $Tokens[++$i]
            continue
        }
        if ($token -in @('--config', '-config')) {
            if ($i + 1 -ge $Tokens.Count) { throw "Missing value after --config." }
            if (-not [string]::IsNullOrWhiteSpace($resolvedConfig)) { throw "The --config option was specified more than once." }
            $resolvedConfig = $Tokens[++$i]
            continue
        }
        $positionals.Add($token)
    }

    [PSCustomObject]@{ Tokens = @($positionals); Open = $resolvedOpen; ConfigPath = $resolvedConfig }
}

function Resolve-CdpCommandKind {
    param([string]$Command)

    if ([string]::IsNullOrWhiteSpace($Command)) { return $null }
    switch -Regex ($Command.ToLowerInvariant()) {
        '^(status|st)$' { return 'status' }
        '^(workspace|ws)$' { return 'workspace' }
        '^(doctor|health|check)$' { return 'doctor' }
        '^(about|version|--version|-v)$' { return 'about' }
        '^(recent|recents|history)$' { return 'recent' }
        '^(pin|pinned|favorite|star)$' { return 'pin' }
        '^(unpin|unfavorite|unstar)$' { return 'unpin' }
        '^(alias|add-alias)$' { return 'alias' }
        '^(unalias|remove-alias)$' { return 'unalias' }
        '^(tag|add-tag)$' { return 'tag' }
        '^(untag|remove-tag)$' { return 'untag' }
        '^(clean|repair|fix)$' { return 'clean' }
        '^(init|setup)$' { return 'init' }
        '^(scan|import)$' { return 'scan' }
        default { return $null }
    }
}

function ConvertFrom-CdpStatusTokens {
    param([string[]]$Tokens, [string]$ConfigPath)

    $result = New-CdpInvocation -Kind 'status'
    $result.ConfigPath = $ConfigPath
    foreach ($token in $Tokens) {
        if ($token -in @('--dirty', '-dirty', '-d')) { $result.DirtyOnly = $true; continue }
        if ($token -in @('--fix', '-fix')) { $result.Fix = $true; continue }
        if ($token -in @('--push', '-push')) { $result.Push = $true; continue }
        if ($token.StartsWith('@')) {
            if ($result.TagFilter) { throw "Only one status tag filter can be specified." }
            $result.TagFilter = $token
            continue
        }
        if ($token.StartsWith('-')) { throw "Unknown status option: $token" }
        if ($result.ConfigPath) { throw "Only one status config path can be specified." }
        $result.ConfigPath = $token
    }
    if ($result.Fix -and $result.Push) { throw "The --fix and --push actions cannot be used together." }
    if ($result.DirtyOnly -and ($result.Fix -or $result.Push)) { throw "The --dirty filter and status actions cannot be used together." }
    $result
}

function ConvertFrom-CdpWorkspaceTokens {
    param([string[]]$Tokens, [string]$ConfigPath, [string]$Open)

    $result = New-CdpInvocation -Kind 'workspace'
    $result.ConfigPath = $ConfigPath
    $result.Open = $Open
    if ($Tokens.Count -eq 0) {
        if ($Open) { throw "The --open option requires a workspace name or --add action." }
        $result.WorkspaceAction = 'usage'
        return $result
    }
    $action = $Tokens[0].ToLowerInvariant()
    if ($action -in @('--list', '-l', 'list')) {
        if ($Open) { throw "The --open option is not valid with workspace --list." }
        if ($Tokens.Count -ne 1) { throw "Workspace --list does not accept project arguments." }
        $result.WorkspaceAction = 'list'
        return $result
    }
    if ($action -in @('--add', '-a', 'add')) {
        if ($Tokens.Count -lt 3) { throw "Workspace --add requires a name and at least one project." }
        $result.WorkspaceAction = 'add'
        $result.WorkspaceName = $Tokens[1]
        $result.Projects = @($Tokens | Select-Object -Skip 2)
        return $result
    }
    if ($Tokens.Count -ne 1) { throw "Workspace launch accepts one workspace name." }
    if ($Tokens[0].StartsWith('-')) { throw "Unknown workspace option: $($Tokens[0])" }
    $result.WorkspaceAction = 'open'
    $result.WorkspaceName = $Tokens[0]
    $result
}

function Set-CdpTrailingConfigPath {
    param([object]$Result, [string[]]$Arguments, [int]$RequiredCount)

    if ($Arguments.Count -lt $RequiredCount -or $Arguments.Count -gt ($RequiredCount + 1)) {
        throw "Invalid arguments for cdp $($Result.Kind)."
    }
    if ($Arguments.Count -eq ($RequiredCount + 1)) {
        if ($Result.ConfigPath) { throw "The config path was specified more than once." }
        $Result.ConfigPath = $Arguments[-1]
    }
}

function ConvertFrom-CdpManagementTokens {
    param([string]$Kind, [string[]]$Tokens, [string]$ConfigPath)

    $result = New-CdpInvocation -Kind $Kind
    $result.ConfigPath = $ConfigPath
    if ($Kind -eq 'doctor') {
        $items = @($Tokens | Where-Object { if ($_ -in @('--fix', '-fix')) { $result.Fix = $true; $false } else { $true } })
        Set-CdpTrailingConfigPath -Result $result -Arguments $items -RequiredCount 0
    } elseif ($Kind -in @('about', 'clean')) {
        Set-CdpTrailingConfigPath -Result $result -Arguments $Tokens -RequiredCount 0
    } elseif ($Kind -eq 'recent') {
        if ($Tokens.Count -gt 1) { throw "Recent count must be a positive integer." }
        if ($Tokens.Count -eq 1) {
            $recentCount = 0
            if (-not [int]::TryParse($Tokens[0], [ref]$recentCount)) { throw "Recent count must be a positive integer." }
            $result.Count = $recentCount
        }
        if ($result.Count -le 0) { throw "Recent count must be a positive integer." }
    } elseif ($Kind -in @('pin', 'unpin')) {
        Set-CdpTrailingConfigPath -Result $result -Arguments $Tokens -RequiredCount 1
        $result.Name = $Tokens[0]
    } elseif ($Kind -in @('alias', 'unalias', 'tag', 'untag')) {
        Set-CdpTrailingConfigPath -Result $result -Arguments $Tokens -RequiredCount 2
        $result.Name = $Tokens[0]
        $result.Value = $Tokens[1]
    } else {
        $result = ConvertFrom-CdpScanTokens -Kind $Kind -Tokens $Tokens -ConfigPath $ConfigPath
    }
    $result
}

function ConvertFrom-CdpScanTokens {
    param([string]$Kind, [string[]]$Tokens, [string]$ConfigPath)

    $result = New-CdpInvocation -Kind $Kind
    $result.ConfigPath = $ConfigPath
    if ($Tokens.Count -gt 0) { $result.RootPath = $Tokens[0] }
    $depthSet = $false
    foreach ($token in @($Tokens | Select-Object -Skip 1)) {
        $depth = 0
        if ([int]::TryParse($token, [ref]$depth)) {
            if ($depthSet -or $depth -lt 1) { throw "Max depth must be one positive integer." }
            $result.MaxDepth = $depth
            $depthSet = $true
        } elseif (-not $result.ConfigPath) {
            $result.ConfigPath = $token
        } else {
            throw "The config path was specified more than once."
        }
    }
    $result
}

function ConvertFrom-CdpSwitchTokens {
    param([string[]]$Tokens, [string]$Query, [string]$ConfigPath, [string]$Open)

    $result = New-CdpInvocation -Kind 'switch'
    $result.Query = $Query
    $result.ConfigPath = $ConfigPath
    $result.Open = $Open
    $items = @($Tokens)
    if ([string]::IsNullOrWhiteSpace($result.Query) -and $items.Count -gt 0 -and -not (Test-CdpConfigPathArgument $items[0])) {
        $result.Query = $items[0]
        $items = @($items | Select-Object -Skip 1)
    }
    if ($items.Count -gt 1) { throw "Project switching accepts one query and one config path." }
    if ($items.Count -eq 1) {
        if ($items[0].StartsWith('-')) { throw "Unknown cdp option: $($items[0])" }
        if ($result.ConfigPath) { throw "The config path was specified more than once." }
        $result.ConfigPath = $items[0]
    }
    $result
}

function ConvertFrom-CdpInvokeArguments {
    param([string]$Command, [string]$ConfigPath, [string]$Query, [string]$Open, [string[]]$RemainingArgs)

    $tokens = @(Get-CdpInvocationTokens -Command $Command -ConfigPath $ConfigPath -RemainingArgs $RemainingArgs)
    $common = Split-CdpCommonOptions -Tokens $tokens -Open $Open
    $tokens = @($common.Tokens)
    $kind = if ($tokens.Count -gt 0) { Resolve-CdpCommandKind -Command $tokens[0] } else { $null }
    if ($kind) { $tokens = @($tokens | Select-Object -Skip 1) }

    if ($kind -eq 'status') {
        if ($common.Open) { throw "The --open option is not valid for status." }
        return ConvertFrom-CdpStatusTokens -Tokens $tokens -ConfigPath $common.ConfigPath
    }
    if ($kind -eq 'workspace') {
        return ConvertFrom-CdpWorkspaceTokens -Tokens $tokens -ConfigPath $common.ConfigPath -Open $common.Open
    }
    if ($kind) {
        if ($common.Open) { throw "The --open option is only valid for project and workspace commands." }
        return ConvertFrom-CdpManagementTokens -Kind $kind -Tokens $tokens -ConfigPath $common.ConfigPath
    }
    ConvertFrom-CdpSwitchTokens -Tokens $tokens -Query $Query -ConfigPath $common.ConfigPath -Open $common.Open
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
        Clear-CdpProjectConfigCache -ConfigPath $ConfigPath
        Write-Host "Created new config file at: $ConfigPath" -ForegroundColor Green
    }
}

function Get-CdpStatePath {
    if (-not [string]::IsNullOrWhiteSpace($env:CDP_STATE_PATH)) {
        return [Environment]::ExpandEnvironmentVariables($env:CDP_STATE_PATH)
    }

    Join-Path $env:USERPROFILE ".cdp\state.json"
}

function New-CdpState {
    [PSCustomObject]@{
        recentProjects = @()
    }
}

function Get-CdpState {
    $statePath = Get-CdpStatePath
    if (-not (Test-Path -LiteralPath $statePath)) {
        return New-CdpState
    }

    try {
        $jsonContent = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8
        $state = ConvertFrom-Json -InputObject $jsonContent

        if ($null -eq $state -or $state -is [array]) {
            return New-CdpState
        }

        if ($state.PSObject.Properties.Name -notcontains 'recentProjects') {
            $state | Add-Member -MemberType NoteProperty -Name recentProjects -Value @()
        }

        $state.recentProjects = @($state.recentProjects)
        return $state
    } catch {
        return New-CdpState
    }
}

function Save-CdpState {
    param(
        [Parameter(Mandatory = $true)]
        [object]$State
    )

    $statePath = Get-CdpStatePath
    $stateDir = Split-Path -Parent $statePath
    if (-not [string]::IsNullOrWhiteSpace($stateDir) -and -not (Test-Path -LiteralPath $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }

    ConvertTo-Json -InputObject $State -Depth 10 |
        Out-File -FilePath $statePath -Encoding UTF8
}

function Add-CdpRecentProject {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Project,

        [Parameter(Mandatory = $false)]
        [int]$MaxCount = 20
    )

    try {
        $name = [string]$Project.name
        $rootPath = [string]$Project.rootPath
        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($rootPath)) {
            return
        }

        $state = Get-CdpState
        $recentProjects = @($state.recentProjects)
        $existing = @($recentProjects | Where-Object {
            [string]::Equals([string]$_.rootPath, $rootPath, [StringComparison]::OrdinalIgnoreCase)
        }) | Select-Object -First 1

        $visitCount = 1
        if ($existing -and $null -ne $existing.visitCount) {
            $visitCount = [int]$existing.visitCount + 1
        }

        $newEntry = [PSCustomObject]@{
            name = $name
            rootPath = $rootPath
            lastVisitedAt = [DateTimeOffset]::UtcNow.ToString("o")
            visitCount = $visitCount
        }

        $state.recentProjects = @(
            @($recentProjects | Where-Object {
                -not [string]::Equals([string]$_.rootPath, $rootPath, [StringComparison]::OrdinalIgnoreCase)
            }) + $newEntry |
                Sort-Object -Property @{
                    Expression = {
                        try {
                            [DateTimeOffset]::Parse([string]$_.lastVisitedAt)
                        } catch {
                            [DateTimeOffset]::MinValue
                        }
                    }
                } -Descending |
                Select-Object -First $MaxCount
        )

        Save-CdpState -State $state
    } catch {
        Write-Verbose "Failed to record recent project: $($_.Exception.Message)"
    }
}

function Get-CdpRecentProjects {
    <#
    .SYNOPSIS
        Show recently visited cdp projects.

    .DESCRIPTION
        Lists projects successfully opened through cdp, ordered by most recent
        visit. Recent state is stored separately from project configuration at
        ~/.cdp/state.json.

    .PARAMETER Count
        Maximum number of recent projects to display. Defaults to 10.

    .PARAMETER PassThru
        Returns recent project objects instead of only writing the table.

    .EXAMPLE
        cdp recent
        # Shows recently visited projects
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [int]$Count = 10,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    if ($Count -le 0) {
        $Count = 10
    }

    $state = Get-CdpState
    $recentProjects = @($state.recentProjects |
        Sort-Object -Property @{
            Expression = {
                try {
                    [DateTimeOffset]::Parse([string]$_.lastVisitedAt)
                } catch {
                    [DateTimeOffset]::MinValue
                }
            }
        } -Descending |
        Select-Object -First $Count)

    if ($PassThru) {
        return $recentProjects
    }

    if ($recentProjects.Count -eq 0) {
        Write-Host "No recent projects yet. Switch with cdp first." -ForegroundColor Yellow
        return
    }

    $nameWidth = 14
    foreach ($project in $recentProjects) {
        $projectName = [string]$project.name
        $nameWidth = [Math]::Max($nameWidth, $projectName.Length)
    }
    $nameWidth = [Math]::Min($nameWidth, 30)

    Write-Host "`ncdp recent " -ForegroundColor Cyan -NoNewline
    Write-Host "($($recentProjects.Count) shown)" -ForegroundColor DarkGray
    Write-Host ("-" * 110) -ForegroundColor DarkGray
    Write-Host ("  {0,-4} " -f "#") -ForegroundColor DarkGray -NoNewline
    Write-Host (("{0,-$nameWidth} " -f "Project")) -ForegroundColor Cyan -NoNewline
    Write-Host ("{0,-24} " -f "Last used") -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-7} " -f "Visits") -ForegroundColor DarkGray -NoNewline
    Write-Host "Path" -ForegroundColor DarkGray
    Write-Host ("-" * 110) -ForegroundColor DarkGray

    $index = 1
    foreach ($project in $recentProjects) {
        $number = "{0:00}" -f $index
        $projectName = Limit-CdpText -Text ([string]$project.name) -MaxLength $nameWidth
        $lastVisited = [string]$project.lastVisitedAt
        $visitCount = if ($null -eq $project.visitCount) { 1 } else { [int]$project.visitCount }

        Write-Host ("  {0,-4} " -f $number) -ForegroundColor DarkGray -NoNewline
        Write-Host (("{0,-$nameWidth} " -f $projectName)) -ForegroundColor Green -NoNewline
        Write-Host ("{0,-24} " -f (Limit-CdpText -Text $lastVisited -MaxLength 24)) -ForegroundColor DarkGray -NoNewline
        Write-Host ("{0,-7} " -f $visitCount) -ForegroundColor Cyan -NoNewline
        Write-Host "$($project.rootPath)" -ForegroundColor DarkGray
        $index++
    }

    Write-Host ("-" * 110) -ForegroundColor DarkGray
    Write-Host "state: $(Get-CdpStatePath)" -ForegroundColor DarkGray
}

function New-CdpHealthCheck {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    [PSCustomObject]@{
        Name = $Name
        Passed = $Passed
        Level = $Level
        Message = $Message
    }
}

function Write-CdpHealthCheck {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Check
    )

    if ($Check.Passed) {
        Write-Host "[OK]   " -ForegroundColor Green -NoNewline
    } elseif ($Check.Level -eq 'Warning') {
        Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    } else {
        Write-Host "[FAIL] " -ForegroundColor Red -NoNewline
    }

    Write-Host "$($Check.Name): " -NoNewline
    Write-Host $Check.Message -ForegroundColor Gray
}

function Get-CdpDependencyHealthChecks {
    $fzfCommand = Resolve-CdpFzfCommand

    if ($fzfCommand) {
        return @(New-CdpHealthCheck -Name "fzf" -Passed $true -Message "found at $fzfCommand")
    }

    return @(New-CdpHealthCheck -Name "fzf" -Passed $false -Level Error -Message "not found in PATH")
}

function Get-CdpUpgradeCommand {
    "Update-Module -Name cdp -Scope CurrentUser -Force"
}

function Get-CdpUpdateHealthChecks {
    param(
        [Parameter(Mandatory = $false)]
        [version]$CurrentVersion,

        [Parameter(Mandatory = $false)]
        [version]$LatestVersion
    )

    if ($env:CDP_SKIP_UPDATE_CHECK -in @('1', 'true', 'TRUE', 'yes', 'YES')) {
        return @(New-CdpHealthCheck -Name "updates" -Passed $true -Message "skipped by CDP_SKIP_UPDATE_CHECK")
    }

    if (-not $CurrentVersion) {
        $CurrentVersion = Get-CdpCurrentModuleVersion
    }

    if (-not $CurrentVersion) {
        return @(New-CdpHealthCheck -Name "updates" -Passed $true `
            -Message "current module version unknown; install with: Install-Module -Name cdp -Scope CurrentUser -Force -AllowClobber")
    }

    if (-not $LatestVersion) {
        if (-not (Get-Command Find-Module -ErrorAction SilentlyContinue)) {
            return @(New-CdpHealthCheck -Name "updates" -Passed $true `
                -Message "PowerShellGet not available; upgrade with: $(Get-CdpUpgradeCommand)")
        }

        try {
            $galleryModule = Find-Module -Name cdp -Repository PSGallery -ErrorAction Stop
            $LatestVersion = [version]$galleryModule.Version
        } catch {
            return @(New-CdpHealthCheck -Name "updates" -Passed $true `
                -Message "could not check PowerShell Gallery: $($_.Exception.Message)")
        }
    }

    if ($LatestVersion -gt $CurrentVersion) {
        return @(New-CdpHealthCheck -Name "updates" -Passed $false -Level Warning `
            -Message "new version available: $CurrentVersion -> $LatestVersion; upgrade with: $(Get-CdpUpgradeCommand)")
    }

    if ($CurrentVersion -gt $LatestVersion) {
        return @(New-CdpHealthCheck -Name "updates" -Passed $true `
            -Message "current version $CurrentVersion is newer than PowerShell Gallery $LatestVersion")
    }

    return @(New-CdpHealthCheck -Name "updates" -Passed $true `
        -Message "current version $CurrentVersion is up to date")
}

function Get-CdpAboutInfo {
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    $module = Get-CdpCurrentModule
    $versionText = Get-CdpVersionText
    $modulePath = if ($module) { $module.Path } else { $null }

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $configResult = Resolve-CdpHealthConfigPath -ConfigPath $ConfigPath
        $ConfigPath = $configResult.Path
    }

    $projectCount = 0
    $enabledProjectCount = 0
    if (-not [string]::IsNullOrWhiteSpace($ConfigPath) -and (Test-Path -LiteralPath $ConfigPath)) {
        try {
            $configData = Get-CdpProjectConfig -ConfigPath $ConfigPath
            $projectCount = @($configData.Projects).Count
            $enabledProjectCount = @($configData.EnabledProjects).Count
        } catch {
            $projectCount = 0
            $enabledProjectCount = 0
        }
    }

    [PSCustomObject]@{
        Name = "cdp"
        Version = $versionText
        ModulePath = $modulePath
        ConfigPath = $ConfigPath
        ProjectCount = $projectCount
        EnabledProjectCount = $enabledProjectCount
        UpgradeCommand = Get-CdpUpgradeCommand
    }
}

function Show-CdpAbout {
    <#
    .SYNOPSIS
        Show cdp version and runtime information.

    .DESCRIPTION
        Displays a compact cdp brand header, module version, active config path,
        project counts, and the recommended upgrade command.

    .PARAMETER ConfigPath
        Optional custom path to projects.json file.

    .PARAMETER PassThru
        Returns the about information object in addition to console output.

    .EXAMPLE
        cdp about
        # Shows cdp version and runtime information
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    $about = Get-CdpAboutInfo -ConfigPath $ConfigPath

    Write-CdpBrandHeader
    Write-Host "Module: " -NoNewline -ForegroundColor Gray
    Write-Host $about.ModulePath -ForegroundColor Cyan
    Write-Host "Config: " -NoNewline -ForegroundColor Gray
    Write-Host $about.ConfigPath -ForegroundColor Cyan
    Write-Host "Projects: " -NoNewline -ForegroundColor Gray
    Write-Host "$($about.EnabledProjectCount) enabled / $($about.ProjectCount) total" -ForegroundColor Green
    Write-Host "Upgrade: " -NoNewline -ForegroundColor Gray
    Write-Host $about.UpgradeCommand -ForegroundColor Cyan

    if ($PassThru) {
        return $about
    }
}

function Resolve-CdpHealthConfigPath {
    param(
        [string]$ConfigPath
    )

    $checks = @()
    $configSource = "argument"

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        if (-not [string]::IsNullOrWhiteSpace($env:CDP_CONFIG)) {
            $ConfigPath = $env:CDP_CONFIG
            $configSource = "CDP_CONFIG"
        } else {
            $storedChoice = Get-StoredConfigChoice
            if ($storedChoice -and (Test-Path -LiteralPath $storedChoice)) {
                $ConfigPath = $storedChoice
                $configSource = "saved choice"
            } else {
                $availableConfigs = @(Get-AllAvailableConfigs)
                if ($availableConfigs.Count -gt 0) {
                    $ConfigPath = $availableConfigs[0].Path
                    $configSource = $availableConfigs[0].Source

                    if ($availableConfigs.Count -gt 1) {
                        $checks += New-CdpHealthCheck -Name "config selection" -Passed $false `
                            -Level Warning -Message "multiple configs found; run cdp-config to choose one"
                    }
                } else {
                    $ConfigPath = Join-Path $env:USERPROFILE ".cdp\projects.json"
                    $configSource = "default custom config"
                }
            }
        }
    }

    [PSCustomObject]@{
        Path = $ConfigPath
        Source = $configSource
        Checks = $checks
    }
}

function Get-CdpConfigParseResult {
    param(
        [string]$ConfigPath,
        [string]$ConfigSource
    )

    $checks = @()
    $projects = @()
    $parsed = $false

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        $checks += New-CdpHealthCheck -Name "config file" -Passed $false `
            -Level Error -Message "not found at $ConfigPath"
        return [PSCustomObject]@{ Projects = $projects; Checks = $checks; Parsed = $parsed }
    }

    $checks += New-CdpHealthCheck -Name "config file" -Passed $true -Message "$ConfigSource -> $ConfigPath"

    try {
        $jsonContent = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
        $parsedProjects = ConvertFrom-Json -InputObject $jsonContent
        if ($null -ne $parsedProjects) {
            $projects = @($parsedProjects)
        }

        $checks += New-CdpHealthCheck -Name "JSON" -Passed $true -Message "parsed successfully"
        $parsed = $true
    } catch {
        $checks += New-CdpHealthCheck -Name "JSON" -Passed $false -Level Error -Message $_.Exception.Message
    }

    [PSCustomObject]@{ Projects = $projects; Checks = $checks; Parsed = $parsed }
}

function Get-CdpProjectHealthChecks {
    param(
        [object[]]$Projects
    )

    $invalidProjects = @($Projects | Where-Object {
        [string]::IsNullOrWhiteSpace($_.name) -or
        [string]::IsNullOrWhiteSpace($_.rootPath) -or
        -not ($_.enabled -is [bool])
    })
    $enabledProjects = @($Projects | Where-Object { $_.enabled -eq $true })
    $duplicateNames = @($Projects | Group-Object -Property name | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.Name) -and $_.Count -gt 1
    })
    $missingPaths = @($enabledProjects | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.rootPath) -and
        -not (Test-Path -LiteralPath $_.rootPath)
    })

    @(
        New-CdpHealthCheck -Name "project schema" -Passed ($invalidProjects.Count -eq 0) `
            -Level Error -Message "$($invalidProjects.Count) invalid project entries"
        New-CdpHealthCheck -Name "enabled projects" -Passed ($enabledProjects.Count -gt 0) `
            -Level Warning -Message "$($enabledProjects.Count) enabled of $($Projects.Count) total"
        New-CdpHealthCheck -Name "duplicate names" -Passed ($duplicateNames.Count -eq 0) `
            -Level Warning -Message "$($duplicateNames.Count) duplicate project names"
        New-CdpHealthCheck -Name "project paths" -Passed ($missingPaths.Count -eq 0) `
            -Level Warning -Message "$($missingPaths.Count) enabled project paths missing"
    )
}

function Write-CdpHealthSummary {
    param(
        [object[]]$Checks
    )

    Write-Host "`ncdp doctor" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Gray
    foreach ($check in $Checks) {
        Write-CdpHealthCheck -Check $check
    }
    Write-Host ""

    $errorCount = @($Checks | Where-Object { -not $_.Passed -and $_.Level -eq 'Error' }).Count
    $warningCount = @($Checks | Where-Object { -not $_.Passed -and $_.Level -eq 'Warning' }).Count

    if ($errorCount -eq 0 -and $warningCount -eq 0) {
        Write-Host "All checks passed." -ForegroundColor Green
    } else {
        Write-Host "Summary: $errorCount error(s), $warningCount warning(s)." -ForegroundColor Yellow
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
            pinned = $false
            aliases = @()
            tags = @()
        }

        $projects = @($projects) + $newProject

        # Save updated config
        $projects | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigPath -Encoding UTF8
        Clear-CdpProjectConfigCache -ConfigPath $ConfigPath

        Write-Host "Project added successfully!" -ForegroundColor Green
        Write-Host "  Name: $Name" -ForegroundColor Cyan
        Write-Host "  Path: $Path" -ForegroundColor Gray
        Write-Host "  Config: $ConfigPath" -ForegroundColor Gray

    } catch {
        Write-Host "Error: Failed to add project." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

function Set-ProjectPin {
    <#
    .SYNOPSIS
        Pin or unpin a project in the cdp list.

    .DESCRIPTION
        Marks a project as pinned so it appears before normal projects in cdp
        pickers and lists. If no name is provided, cdp tries to pin the project
        matching the current directory.

    .PARAMETER Name
        Project name or query to pin or unpin. Omit it inside a project root.

    .PARAMETER ConfigPath
        Optional custom path to projects.json file.

    .PARAMETER Pinned
        Set to true to pin the project or false to unpin it.

    .PARAMETER PassThru
        Returns the updated project object for tests and scripting.

    .EXAMPLE
        cdp pin api
        # Pins the matching project

    .EXAMPLE
        cdp unpin api
        # Removes the pin from the matching project
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [bool]$Pinned = $true,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    Initialize-ConfigFile -ConfigPath $ConfigPath

    try {
        $allProjects = ConvertFrom-Json -InputObject (Get-Content -Path $ConfigPath -Raw -Encoding UTF8)
        $projects = @($allProjects)
        $targetProjects = if ([string]::IsNullOrWhiteSpace($Name)) {
            $currentPath = Get-CdpComparablePath -Path (Get-Location).Path
            @($projects | Where-Object {
                (Get-CdpComparablePath -Path ([string]$_.rootPath)) -eq $currentPath
            })
        } else {
            @(Get-CdpProjectMatches -Projects $projects -Query $Name)
        }

        if ($targetProjects.Count -eq 0) {
            Write-Host "No project matched for pin update." -ForegroundColor Yellow
            return
        }

        if ($targetProjects.Count -gt 1) {
            Write-Host "Multiple projects matched. Please use a more specific name." -ForegroundColor Yellow
            $targetProjects | ForEach-Object { Write-Host "  $($_.name)" -ForegroundColor Gray }
            return
        }

        $target = $targetProjects[0]
        foreach ($project in $projects) {
            $sameName = [string]::Equals([string]$project.name, [string]$target.name, [StringComparison]::OrdinalIgnoreCase)
            $samePath = [string]::Equals([string]$project.rootPath, [string]$target.rootPath, [StringComparison]::OrdinalIgnoreCase)
            if ($sameName -and $samePath) {
                if ($project.PSObject.Properties['pinned']) {
                    $project.pinned = $Pinned
                } else {
                    $project | Add-Member -NotePropertyName pinned -NotePropertyValue $Pinned
                }
            }
        }

        $projects | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigPath -Encoding UTF8
        Clear-CdpProjectConfigCache -ConfigPath $ConfigPath

        $stateText = if ($Pinned) { "Pinned" } else { "Unpinned" }
        Write-Host "$stateText project: $($target.name)" -ForegroundColor Green

        if ($PassThru) {
            return ($projects | Where-Object {
                [string]::Equals([string]$_.name, [string]$target.name, [StringComparison]::OrdinalIgnoreCase) -and
                [string]::Equals([string]$_.rootPath, [string]$target.rootPath, [StringComparison]::OrdinalIgnoreCase)
            } | Select-Object -First 1)
        }
    } catch {
        Write-Host "Error: Failed to update project pin." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

function Clear-ProjectPin {
    <#
    .SYNOPSIS
        Remove the pinned state from a cdp project.

    .DESCRIPTION
        Convenience wrapper for Set-ProjectPin -Pinned false.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    Set-ProjectPin -Name $Name -ConfigPath $ConfigPath -Pinned:$false -PassThru:$PassThru
}

function Update-CdpProjectStringList {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [ValidateSet('aliases', 'tags')]
        [string]$PropertyName,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$Remove,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Value)) {
        Write-Host "Project name and metadata value are required." -ForegroundColor Yellow
        return
    }

    Initialize-ConfigFile -ConfigPath $ConfigPath

    try {
        $allProjects = ConvertFrom-Json -InputObject (Get-Content -Path $ConfigPath -Raw -Encoding UTF8)
        $projects = @($allProjects)
        $targets = @(Get-CdpProjectMatches -Projects $projects -Query $Name)

        if ($targets.Count -ne 1) {
            Write-Host "Expected one project match, found $($targets.Count)." -ForegroundColor Yellow
            return
        }

        $target = $targets[0]
        foreach ($project in $projects) {
            $sameName = [string]::Equals([string]$project.name, [string]$target.name, [StringComparison]::OrdinalIgnoreCase)
            $samePath = [string]::Equals([string]$project.rootPath, [string]$target.rootPath, [StringComparison]::OrdinalIgnoreCase)
            if ($sameName -and $samePath) {
                $values = @(Get-CdpProjectStringList -Project $project -PropertyName $PropertyName)
                if ($Remove) {
                    $values = @($values | Where-Object { -not [string]::Equals($_, $Value, [StringComparison]::OrdinalIgnoreCase) })
                } elseif (@($values | Where-Object { [string]::Equals($_, $Value, [StringComparison]::OrdinalIgnoreCase) }).Count -eq 0) {
                    $values += $Value
                }

                if ($project.PSObject.Properties[$PropertyName]) {
                    $project.$PropertyName = @($values)
                } else {
                    $project | Add-Member -NotePropertyName $PropertyName -NotePropertyValue @($values)
                }
            }
        }

        $projects | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigPath -Encoding UTF8
        Clear-CdpProjectConfigCache -ConfigPath $ConfigPath

        $action = if ($Remove) { "Removed" } else { "Added" }
        Write-Host "$action $PropertyName '$Value' for project: $($target.name)" -ForegroundColor Green

        if ($PassThru) {
            return ($projects | Where-Object {
                [string]::Equals([string]$_.name, [string]$target.name, [StringComparison]::OrdinalIgnoreCase) -and
                [string]::Equals([string]$_.rootPath, [string]$target.rootPath, [StringComparison]::OrdinalIgnoreCase)
            } | Select-Object -First 1)
        }
    } catch {
        Write-Host "Error: Failed to update project metadata." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

function Add-ProjectAlias {
    [CmdletBinding()]
    param([string]$Name, [string]$Alias, [string]$ConfigPath, [switch]$PassThru)
    Update-CdpProjectStringList -Name $Name -Value $Alias -PropertyName aliases -ConfigPath $ConfigPath -PassThru:$PassThru
}

function Remove-ProjectAlias {
    [CmdletBinding()]
    param([string]$Name, [string]$Alias, [string]$ConfigPath, [switch]$PassThru)
    Update-CdpProjectStringList -Name $Name -Value $Alias -PropertyName aliases -ConfigPath $ConfigPath -Remove -PassThru:$PassThru
}

function Add-ProjectTag {
    [CmdletBinding()]
    param([string]$Name, [string]$Tag, [string]$ConfigPath, [switch]$PassThru)
    Update-CdpProjectStringList -Name $Name -Value $Tag -PropertyName tags -ConfigPath $ConfigPath -PassThru:$PassThru
}

function Remove-ProjectTag {
    [CmdletBinding()]
    param([string]$Name, [string]$Tag, [string]$ConfigPath, [switch]$PassThru)
    Update-CdpProjectStringList -Name $Name -Value $Tag -PropertyName tags -ConfigPath $ConfigPath -Remove -PassThru:$PassThru
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

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    Initialize-ConfigFile -ConfigPath $ConfigPath

    try {
        $allProjects = ConvertFrom-Json -InputObject (Get-Content -Path $ConfigPath -Raw -Encoding UTF8)
        $projects = @($allProjects)
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

        ConvertTo-Json -InputObject @($cleanProjects) -Depth 10 | Out-File -FilePath $ConfigPath -Encoding UTF8
        Clear-CdpProjectConfigCache -ConfigPath $ConfigPath

        Write-Host "cdp config repaired: $ConfigPath" -ForegroundColor Green
        foreach ($item in $summary.GetEnumerator()) {
            Write-Host "  $($item.Key): $($item.Value)" -ForegroundColor Gray
        }

        if ($PassThru) {
            [PSCustomObject]@{
                ConfigPath = $ConfigPath
                ProjectCount = $cleanProjects.Count
                RemovedInvalid = $summary.RemovedInvalid
                RemovedDuplicatePaths = $summary.RemovedDuplicatePaths
                RenamedDuplicates = $summary.RenamedDuplicates
                DisabledMissingPaths = $summary.DisabledMissingPaths
                AddedPinnedFields = $summary.AddedPinnedFields
                FixedEnabledFields = $summary.FixedEnabledFields
            }
        }
    } catch {
        Write-Host "Error: Failed to repair project configuration." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

function Get-CdpGitProjectInfo {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Project
    )

    $rootPath = [string]$Project.rootPath
    $info = [PSCustomObject]@{
        Name = [string]$Project.name
        RootPath = $rootPath
        PathExists = $false
        IsGitRepo = $false
        Branch = ""
        DirtyCount = 0
        UntrackedCount = 0
        AheadCount = 0
        BehindCount = 0
        LastCommitRelative = ""
        StatusLabel = ""
        NeedsAttention = $false
    }

    if (-not (Test-Path -LiteralPath $rootPath)) {
        $info.StatusLabel = "path missing"
        $info.NeedsAttention = $true
        return $info
    }

    $info.PathExists = $true

    $insideWorkTree = $false
    try {
        $probe = (& git -C $rootPath rev-parse --is-inside-work-tree 2>$null)
        $insideWorkTree = $LASTEXITCODE -eq 0 -and $probe -eq 'true'
    } catch {}
    if (-not $insideWorkTree) {
        $info.StatusLabel = "not a git repo"
        return $info
    }

    $info.IsGitRepo = $true

    try {
        $info.Branch = (& git -C $rootPath branch --show-current 2>$null)
        if ([string]::IsNullOrWhiteSpace($info.Branch)) {
            $info.Branch = (& git -C $rootPath rev-parse --short HEAD 2>$null)
        }
    } catch {}

    try {
        $porcelain = @(& git -C $rootPath status --porcelain 2>$null)
        foreach ($line in $porcelain) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line.Length -ge 2 -and $line.Substring(0, 2) -eq "??") {
                $info.UntrackedCount++
            } else {
                $info.DirtyCount++
            }
        }
    } catch {}

    try {
        $ahead = (& git -C $rootPath rev-list --count "@{u}..HEAD" 2>$null)
        if ($null -ne $ahead) { $info.AheadCount = [int]$ahead }
    } catch {}

    try {
        $behind = (& git -C $rootPath rev-list --count "HEAD..@{u}" 2>$null)
        if ($null -ne $behind) { $info.BehindCount = [int]$behind }
    } catch {}

    try {
        $info.LastCommitRelative = (& git -C $rootPath log -1 --format="%cr" 2>$null)
    } catch {}

    if ($info.DirtyCount -gt 0 -and $info.UntrackedCount -gt 0) {
        $info.StatusLabel = "$($info.DirtyCount) dirty + $($info.UntrackedCount) untracked"
        $info.NeedsAttention = $true
    } elseif ($info.DirtyCount -gt 0) {
        $info.StatusLabel = "$($info.DirtyCount) dirty"
        $info.NeedsAttention = $true
    } elseif ($info.UntrackedCount -gt 0) {
        $info.StatusLabel = "$($info.UntrackedCount) untracked"
        $info.NeedsAttention = $true
    } else {
        $info.StatusLabel = "clean"
    }

    if ($info.BehindCount -gt 0) {
        $info.NeedsAttention = $true
    }

    return $info
}

function Get-CdpWorkspacesPath {
    param([string]$ConfigPath)

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }
    $configDir = Split-Path -Parent $ConfigPath
    return Join-Path $configDir 'workspaces.json'
}

function Get-CdpWorkspaces {
    param([string]$WorkspacesPath)

    if ([string]::IsNullOrWhiteSpace($WorkspacesPath)) {
        $WorkspacesPath = Get-CdpWorkspacesPath
    }

    if (-not (Test-Path -LiteralPath $WorkspacesPath)) {
        return @()
    }

    $allWs = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $WorkspacesPath -Raw -Encoding UTF8)
    return @($allWs)
}

function Invoke-CdpWorkspace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [switch]$List,

        [Parameter(Mandatory = $false)]
        [string]$Add,

        [Parameter(Mandatory = $false)]
        [string[]]$Projects,

        [Parameter(Mandatory = $false)]
        [string]$Open,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    $wsPath = Get-CdpWorkspacesPath -ConfigPath $ConfigPath

    if ($List) {
        $workspaces = Get-CdpWorkspaces -WorkspacesPath $wsPath
        if ($workspaces.Count -eq 0) {
            Write-Host "No workspaces defined." -ForegroundColor Yellow
            Write-Host "Create one: cdp workspace --add <name> <project1> <project2> ..." -ForegroundColor Gray
            return
        }
        Write-Host ""
        Write-Host "cdp workspaces" -ForegroundColor Cyan
        Write-Host ("-" * 60)
        foreach ($ws in $workspaces) {
            $projList = ($ws.projects -join ", ")
            $openLabel = if ($ws.open) { " [$($ws.open)]" } else { "" }
            Write-Host "  $($ws.name)" -ForegroundColor Green -NoNewline
            Write-Host "$openLabel" -ForegroundColor Cyan -NoNewline
            Write-Host " -> $projList" -ForegroundColor Gray
        }
        Write-Host ("-" * 60)
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($Add)) {
        if ($null -eq $Projects -or $Projects.Count -eq 0) {
            Write-Host "Usage: cdp workspace --add <name> <project1> <project2> ..." -ForegroundColor Yellow
            return
        }

        $workspaces = Get-CdpWorkspaces -WorkspacesPath $wsPath
        $existing = $workspaces | Where-Object { $_.name -eq $Add }
        if ($existing) {
            Write-Host "Workspace '$Add' already exists." -ForegroundColor Yellow
            return
        }

        $newWs = [PSCustomObject]@{
            name = $Add
            projects = @($Projects)
        }
        if (-not [string]::IsNullOrWhiteSpace($Open)) {
            $newWs | Add-Member -NotePropertyName open -NotePropertyValue $Open
        }

        $allWs = @($workspaces) + @($newWs)
        $wsDir = Split-Path -Parent $wsPath
        if (-not (Test-Path $wsDir)) { New-Item -ItemType Directory -Path $wsDir -Force | Out-Null }
        ConvertTo-Json -InputObject @($allWs) -Depth 10 | Out-File -FilePath $wsPath -Encoding UTF8
        Write-Host "Workspace '$Add' created with $($Projects.Count) projects." -ForegroundColor Green
        return
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Host "Usage: cdp workspace <name> | cdp workspace --list | cdp workspace --add <name> <projects...>" -ForegroundColor Yellow
        return
    }

    $workspaces = Get-CdpWorkspaces -WorkspacesPath $wsPath
    $ws = $workspaces | Where-Object { $_.name -eq $Name } | Select-Object -First 1

    if (-not $ws) {
        Write-Host "Workspace '$Name' not found." -ForegroundColor Red
        $available = ($workspaces | ForEach-Object { $_.name }) -join ", "
        if ($available) { Write-Host "Available: $available" -ForegroundColor Gray }
        return
    }

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }
    $configData = Get-CdpProjectConfig -ConfigPath $ConfigPath
    $launcher = if (-not [string]::IsNullOrWhiteSpace($Open)) { $Open } elseif ($ws.open) { $ws.open } else { "" }

    $hasWt = $null -ne (Get-Command wt.exe -ErrorAction SilentlyContinue)

    foreach ($projName in $ws.projects) {
        $project = $configData.EnabledProjects | Where-Object {
            [string]::Equals([string]$_.name, $projName, [StringComparison]::OrdinalIgnoreCase)
        } | Select-Object -First 1

        if (-not $project) {
            Write-Host "  Project '$projName' not found in config, skipping." -ForegroundColor Yellow
            continue
        }

        $projPath = [string]$project.rootPath
        if (-not (Test-Path -LiteralPath $projPath)) {
            Write-Host "  Path missing for '$projName', skipping." -ForegroundColor Yellow
            continue
        }

        if ($hasWt) {
            $wtArgs = @('-w', '0', 'new-tab', '-d', $projPath, '--title', $projName)
            if (-not [string]::IsNullOrWhiteSpace($launcher)) {
                $wtArgs += @('--', 'pwsh', '-NoExit', '-Command', "& { Set-Location '$projPath'; $launcher }")
            }
            Start-Process wt.exe -ArgumentList $wtArgs
            Write-Host "  Opened tab: $projName" -ForegroundColor Green
        } else {
            Write-Host "  $projName -> $projPath" -ForegroundColor Cyan
        }
    }

    if (-not $hasWt) {
        Write-Host ""
        Write-Host "Windows Terminal (wt.exe) not found. Listed projects above." -ForegroundColor Yellow
        Write-Host "Install Windows Terminal for multi-tab workspace launching." -ForegroundColor Gray
    }
}

function Show-CdpProjectStatus {
    <#
    .SYNOPSIS
        Show Git status of all configured projects.

    .DESCRIPTION
        Displays a dashboard view of all enabled projects showing current branch,
        working tree status, ahead/behind counts, and last commit time. Quickly
        answers: which repos have uncommitted changes? Which are behind remote?

    .PARAMETER ConfigPath
        Optional custom path to projects.json file.

    .PARAMETER DirtyOnly
        Only show projects that need attention (dirty, untracked, or behind remote).

    .PARAMETER TagFilter
        Only show projects matching a tag (e.g. '@work').

    .PARAMETER PassThru
        Returns project status objects for scripting.

    .EXAMPLE
        cdp status
        # Shows Git status of all projects

    .EXAMPLE
        cdp status --dirty
        # Only shows projects with uncommitted changes

    .EXAMPLE
        cdp status @work
        # Shows status of projects tagged 'work'
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [Alias('d')]
        [switch]$DirtyOnly,

        [Parameter(Mandatory = $false)]
        [string]$TagFilter,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru,

        [Parameter(Mandatory = $false)]
        [switch]$Fix,

        [Parameter(Mandatory = $false)]
        [switch]$Push
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Error: Configuration file not found at: $ConfigPath" -ForegroundColor Red
        return
    }

    try {
        $configData = Get-CdpProjectConfig -ConfigPath $ConfigPath
        $enabledProjects = @($configData.EnabledProjects)
    } catch {
        Write-Host "Error: Failed to read configuration." -ForegroundColor Red
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($TagFilter)) {
        $tagQuery = $TagFilter
        if ($tagQuery.StartsWith('@')) {
            $tagQuery = $tagQuery.Substring(1)
        }
        $comparison = [StringComparison]::OrdinalIgnoreCase
        $enabledProjects = @($enabledProjects | Where-Object {
            @(Get-CdpProjectStringList -Project $_ -PropertyName 'tags') |
                Where-Object { [string]::Equals($_, $tagQuery, $comparison) }
        })
    }

    if ($enabledProjects.Count -eq 0) {
        Write-Host "No projects to check." -ForegroundColor Yellow
        return
    }

    $statusList = @()
    $total = $enabledProjects.Count
    $scanned = 0
    foreach ($project in $enabledProjects) {
        $scanned++
        Write-Host "`r  Scanning $scanned/$total... " -ForegroundColor DarkGray -NoNewline
        $statusList += Get-CdpGitProjectInfo -Project $project
    }
    Write-Host "`r                              `r" -NoNewline

    if ($PassThru) {
        if ($DirtyOnly) {
            return @($statusList | Where-Object { $_.NeedsAttention })
        }
        return $statusList
    }

    if ($Fix) {
        $missingProjects = @($statusList | Where-Object { -not $_.PathExists })
        if ($missingProjects.Count -eq 0) {
            Write-Host "`nNo path-missing projects to remove." -ForegroundColor Green
            return
        }
        Write-Host "`nRemoving $($missingProjects.Count) path-missing projects:" -ForegroundColor Yellow
        foreach ($proj in $missingProjects) {
            Write-Host "  x $($proj.Name)" -ForegroundColor DarkGray -NoNewline
            Write-Host "  $($proj.RootPath)" -ForegroundColor DarkGray
        }
        $resolvedConfig = if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) { $ConfigPath } else { Get-DefaultConfigPath }
        $allProjects = ConvertFrom-Json -InputObject (Get-Content -Path $resolvedConfig -Raw -Encoding UTF8)
        $missingPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($project in $missingProjects) {
            [void]$missingPaths.Add((Get-CdpComparablePath -Path $project.RootPath))
        }
        $cleaned = @(@($allProjects) | Where-Object {
            $_.enabled -ne $true -or
                -not $missingPaths.Contains((Get-CdpComparablePath -Path ([string]$_.rootPath)))
        })
        ConvertTo-Json -InputObject $cleaned -Depth 10 | Out-File -FilePath $resolvedConfig -Encoding UTF8
        Clear-CdpProjectConfigCache -ConfigPath $resolvedConfig
        Write-Host "`nRemoved $($missingProjects.Count) projects. $($cleaned.Count) projects remain." -ForegroundColor Green
        return
    }

    if ($Push) {
        $aheadProjects = @($statusList | Where-Object { $_.AheadCount -gt 0 -and $_.IsGitRepo })
        if ($aheadProjects.Count -eq 0) {
            Write-Host "`nNo repos ahead of remote." -ForegroundColor Green
            return
        }
        Write-Host "`nPushing $($aheadProjects.Count) repos ahead of remote:" -ForegroundColor Yellow
        foreach ($proj in $aheadProjects) {
            Write-Host "  $($proj.Name) (^$($proj.AheadCount))... " -ForegroundColor Cyan -NoNewline
            try {
                $pushOutput = @(& git -C $proj.RootPath push --porcelain 2>&1)
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "done" -ForegroundColor Green
                } else {
                    $failure = @($pushOutput | Select-Object -Last 1) -join ''
                    Write-Host "failed: $failure" -ForegroundColor Red
                }
            } catch {
                Write-Host "failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        return
    }

    if ($DirtyOnly) {
        $statusList = @($statusList | Where-Object { $_.NeedsAttention })
    }

    $nameWidth = 14
    foreach ($item in $statusList) {
        $nameWidth = [Math]::Max($nameWidth, (Get-CdpDisplayWidth $item.Name))
    }
    $nameWidth = [Math]::Min($nameWidth, 24)

    $branchWidth = 12
    foreach ($item in $statusList) {
        $bw = Get-CdpDisplayWidth $item.Branch
        if ($bw -gt $branchWidth) {
            $branchWidth = [Math]::Min($bw, 20)
        }
    }

    $filterLabel = if ($DirtyOnly) { " (dirty only)" } elseif (-not [string]::IsNullOrWhiteSpace($TagFilter)) { " ($TagFilter)" } else { "" }
    Write-Host "`ncdp project status " -ForegroundColor Cyan -NoNewline
    Write-Host "($($statusList.Count) projects$filterLabel)" -ForegroundColor DarkGray
    Write-Host ("-" * 110) -ForegroundColor DarkGray

    Write-Host ("  {0,-4} " -f "#") -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-$nameWidth} " -f "Project") -ForegroundColor Cyan -NoNewline
    Write-Host ("{0,-$branchWidth} " -f "Branch") -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-24} " -f "Status") -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-10} " -f "Sync") -ForegroundColor DarkGray -NoNewline
    Write-Host "Last Commit" -ForegroundColor DarkGray
    Write-Host ("-" * 110) -ForegroundColor DarkGray

    $index = 1
    foreach ($item in $statusList) {
        $number = "{0:00}" -f $index
        $displayName = Limit-CdpText -Text $item.Name -MaxLength $nameWidth
        $displayBranch = Limit-CdpText -Text $item.Branch -MaxLength $branchWidth

        Write-Host ("  {0,-4} " -f $number) -ForegroundColor DarkGray -NoNewline
        Write-Host "$(Pad-CdpText $displayName $nameWidth) " -ForegroundColor Green -NoNewline

        if (-not $item.IsGitRepo) {
            Write-Host "$(Pad-CdpText '-' $branchWidth) " -ForegroundColor DarkGray -NoNewline
            $labelColor = if ($item.PathExists) { "DarkGray" } else { "Red" }
            Write-Host $item.StatusLabel -ForegroundColor $labelColor
            $index++
            continue
        }

        Write-Host "$(Pad-CdpText $displayBranch $branchWidth) " -ForegroundColor DarkCyan -NoNewline

        $statusIcon = if ($item.DirtyCount -gt 0) { "x" } elseif ($item.UntrackedCount -gt 0) { "!" } else { "+" }
        $statusColor = if ($item.DirtyCount -gt 0) { "Red" } elseif ($item.UntrackedCount -gt 0) { "Yellow" } else { "Green" }
        $statusText = "$statusIcon $($item.StatusLabel)"
        Write-Host ("{0,-24} " -f $statusText) -ForegroundColor $statusColor -NoNewline

        $syncParts = @()
        if ($item.AheadCount -gt 0) { $syncParts += "^$($item.AheadCount)" }
        if ($item.BehindCount -gt 0) { $syncParts += "v$($item.BehindCount)" }
        $syncText = if ($syncParts.Count -gt 0) { $syncParts -join " " } else { "" }
        $syncColor = if ($item.BehindCount -gt 0) { "Yellow" } elseif ($item.AheadCount -gt 0) { "Cyan" } else { "DarkGray" }
        Write-Host ("{0,-10} " -f $syncText) -ForegroundColor $syncColor -NoNewline

        Write-Host $item.LastCommitRelative -ForegroundColor DarkGray
        $index++
    }

    Write-Host ("-" * 110) -ForegroundColor DarkGray

    $attentionCount = @($statusList | Where-Object { $_.NeedsAttention -and $_.IsGitRepo }).Count
    $missingCount = @($statusList | Where-Object { -not $_.PathExists }).Count
    $summaryParts = @()
    if ($attentionCount -gt 0) { $summaryParts += "$attentionCount repos need attention" }
    if ($missingCount -gt 0) { $summaryParts += "$missingCount path missing" }

    if ($summaryParts.Count -gt 0) {
        Write-Host ($summaryParts -join " | ") -ForegroundColor Yellow
    } else {
        Write-Host "All projects clean." -ForegroundColor Green
    }

    if ($summaryParts.Count -gt 0) {
        Write-Host ""
        if ($missingCount -gt 0) {
            Write-Host "  Tip: cdp status --fix   Remove $missingCount path-missing projects" -ForegroundColor DarkGray
        }
        $aheadCount = @($statusList | Where-Object { $_.AheadCount -gt 0 -and $_.IsGitRepo }).Count
        if ($aheadCount -gt 0) {
            Write-Host "  Tip: cdp status --push  Push $aheadCount repos ahead of remote" -ForegroundColor DarkGray
        }
    }
}

function Initialize-Cdp {
    <#
    .SYNOPSIS
        Initialize cdp for first-time use.

    .DESCRIPTION
        Creates the default cdp config if needed, saves it as the active config,
        checks fzf availability, and optionally scans a root directory for Git
        repositories.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$RootPath,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 4,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Join-Path $env:USERPROFILE ".cdp\projects.json"
    }

    Initialize-ConfigFile -ConfigPath $ConfigPath
    Save-ConfigChoice -ConfigPath $ConfigPath

    $fzfFound = $null -ne (Resolve-CdpFzfCommand)
    Write-CdpBrandHeader
    Write-Host "Config: $ConfigPath" -ForegroundColor Cyan
    Write-Host "Saved active config choice." -ForegroundColor Green
    if ($fzfFound) {
        Write-Host "fzf: found" -ForegroundColor Green
    } else {
        Write-Host "fzf: not found. Install with winget install fzf" -ForegroundColor Yellow
    }

    $scanResult = $null
    if (-not [string]::IsNullOrWhiteSpace($RootPath)) {
        $scanResult = Import-GitProjects -RootPath $RootPath -ConfigPath $ConfigPath -MaxDepth $MaxDepth -PassThru
    }

    if ($PassThru) {
        [PSCustomObject]@{
            ConfigPath = $ConfigPath
            FzfFound = $fzfFound
            ScanResult = $scanResult
        }
    }
}

function Get-CdpComparablePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    } catch {
        try {
            return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
        } catch {
            return $Path.TrimEnd('\', '/')
        }
    }
}

function Get-CdpUniqueProjectName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$ExistingNames
    )

    $baseName = Split-Path -Leaf $Path
    if (-not $ExistingNames.Contains($baseName)) {
        return $baseName
    }

    $parentPath = Split-Path -Parent $Path
    $parentName = Split-Path -Leaf $parentPath
    $candidateRoot = if ([string]::IsNullOrWhiteSpace($parentName)) {
        $baseName
    } else {
        "$parentName-$baseName"
    }

    $candidate = $candidateRoot
    $index = 2
    while ($ExistingNames.Contains($candidate)) {
        $candidate = "$candidateRoot-$index"
        $index++
    }

    $candidate
}

function Get-CdpGitRepositoryRoots {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 4
    )

    $resolvedRoot = (Resolve-Path -LiteralPath $RootPath -ErrorAction Stop).Path

    function Search-GitRepository {
        param(
            [string]$Path,
            [int]$Depth
        )

        if (Test-Path -LiteralPath (Join-Path $Path '.git')) {
            [PSCustomObject]@{ Path = $Path }
            return
        }

        if ($Depth -le 0) {
            return
        }

        Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne '.git' } |
            ForEach-Object { Search-GitRepository -Path $_.FullName -Depth ($Depth - 1) }
    }

    @((Search-GitRepository -Path $resolvedRoot -Depth $MaxDepth) |
        Sort-Object -Property Path -Unique)
}

function Import-GitProjects {
    <#
    .SYNOPSIS
        Scan Git repositories and import them into the project list.

    .DESCRIPTION
        Finds directories containing a .git entry under the target root path and
        appends missing repositories to the active cdp configuration.

    .PARAMETER RootPath
        Directory to scan. Defaults to the current directory.

    .PARAMETER ConfigPath
        Optional custom path to projects.json file.

    .PARAMETER MaxDepth
        Maximum directory depth to scan under RootPath. Defaults to 4.

    .PARAMETER PassThru
        Returns a summary object for tests and scripting.

    .EXAMPLE
        cdp-scan E:\Projects
        # Imports Git repositories below E:\Projects
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RootPath,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 4,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        $RootPath = (Get-Location).Path
    }

    $resolvedRoot = Resolve-Path -LiteralPath $RootPath -ErrorAction SilentlyContinue
    if (-not $resolvedRoot) {
        Write-Host "Error: Invalid scan path." -ForegroundColor Red
        return
    }

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    Initialize-ConfigFile -ConfigPath $ConfigPath

    try {
        $jsonContent = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
        $parsedProjects = ConvertFrom-Json -InputObject $jsonContent
        $projects = @()
        if ($null -ne $parsedProjects) {
            $projects = @($parsedProjects)
        }
        $repos = @(Get-CdpGitRepositoryRoots -RootPath $resolvedRoot.Path -MaxDepth $MaxDepth)
    } catch {
        Write-Host "Error: Failed to scan or read configuration." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
        return
    }

    $existingPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $existingNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($project in $projects) {
        if (-not [string]::IsNullOrWhiteSpace($project.rootPath)) {
            [void]$existingPaths.Add((Get-CdpComparablePath -Path $project.rootPath))
        }
        if (-not [string]::IsNullOrWhiteSpace($project.name)) {
            [void]$existingNames.Add([string]$project.name)
        }
    }

    $addedProjects = @()
    $skippedCount = 0
    foreach ($repo in $repos) {
        $repoPath = (Get-CdpComparablePath -Path $repo.Path)
        if ($existingPaths.Contains($repoPath)) {
            $skippedCount++
            continue
        }

        $name = Get-CdpUniqueProjectName -Path $repoPath -ExistingNames $existingNames
        $newProject = [PSCustomObject]@{ name = $name; rootPath = $repoPath; enabled = $true; pinned = $false; aliases = @(); tags = @() }
        $projects += $newProject
        $addedProjects += $newProject
        [void]$existingPaths.Add($repoPath)
        [void]$existingNames.Add($name)
    }

    if ($addedProjects.Count -gt 0) {
        ConvertTo-Json -InputObject @($projects) -Depth 10 |
            Out-File -FilePath $ConfigPath -Encoding UTF8
        Clear-CdpProjectConfigCache -ConfigPath $ConfigPath
    }

    Write-Host "Git repositories found: $($repos.Count)" -ForegroundColor Cyan
    Write-Host "Projects added: $($addedProjects.Count)" -ForegroundColor Green
    Write-Host "Projects skipped: $skippedCount" -ForegroundColor Yellow
    Write-Host "Config: $ConfigPath" -ForegroundColor Gray

    if ($PassThru) {
        [PSCustomObject]@{
            RootPath = $resolvedRoot.Path
            ConfigPath = $ConfigPath
            FoundCount = $repos.Count
            AddedCount = $addedProjects.Count
            SkippedCount = $skippedCount
            AddedProjects = $addedProjects
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
        Clear-CdpProjectConfigCache -ConfigPath $ConfigPath

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

function Test-ProjectHealth {
    <#
    .SYNOPSIS
        Diagnose the cdp runtime environment and project configuration.

    .DESCRIPTION
        Checks fzf availability, cdp update status, active configuration discovery,
        JSON shape, duplicate project names, enabled project count, and missing paths.

    .PARAMETER ConfigPath
        Optional custom path to projects.json file.

    .PARAMETER PassThru
        Returns a structured health summary object in addition to console output.

    .PARAMETER SkipUpdateCheck
        Skips the PowerShell Gallery version check.

    .PARAMETER Fix
        Repairs the project configuration instead of only reporting issues.

    .EXAMPLE
        Test-ProjectHealth
        # Runs diagnostics for the active cdp configuration

    .EXAMPLE
        cdp doctor
        # Runs diagnostics through the short cdp command
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru,

        [Parameter(Mandatory = $false)]
        [switch]$SkipUpdateCheck,

        [Parameter(Mandatory = $false)]
        [switch]$Fix
    )

    if ($Fix) {
        Repair-ProjectConfig -ConfigPath $ConfigPath -PassThru:$PassThru
        return
    }

    $configResult = Resolve-CdpHealthConfigPath -ConfigPath $ConfigPath
    $parseResult = Get-CdpConfigParseResult -ConfigPath $configResult.Path -ConfigSource $configResult.Source
    $projects = @($parseResult.Projects)
    $checks = @(Get-CdpDependencyHealthChecks) + @($configResult.Checks) + @($parseResult.Checks)

    if (-not $SkipUpdateCheck) {
        $checks += Get-CdpUpdateHealthChecks
    }

    if ($parseResult.Parsed) {
        $checks += Get-CdpProjectHealthChecks -Projects $projects
    }

    $errorCount = @($checks | Where-Object { -not $_.Passed -and $_.Level -eq 'Error' }).Count
    $warningCount = @($checks | Where-Object { -not $_.Passed -and $_.Level -eq 'Warning' }).Count

    Write-CdpBrandHeader
    Write-CdpHealthSummary -Checks $checks

    if ($PassThru) {
        [PSCustomObject]@{
            ConfigPath = $configResult.Path
            Checks = $checks
            ErrorCount = $errorCount
            WarningCount = $warningCount
            ProjectCount = $projects.Count
            EnabledProjectCount = @($projects | Where-Object { $_.enabled -eq $true }).Count
            MissingPathCount = @($projects | Where-Object {
                $_.enabled -eq $true -and
                -not [string]::IsNullOrWhiteSpace($_.rootPath) -and
                -not (Test-Path -LiteralPath $_.rootPath)
            }).Count
        }
    }
}

function Invoke-CdpStatusInvocation {
    param([object]$Invocation)

    Show-CdpProjectStatus `
        -ConfigPath $Invocation.ConfigPath `
        -DirtyOnly:$Invocation.DirtyOnly `
        -TagFilter $Invocation.TagFilter `
        -Fix:$Invocation.Fix `
        -Push:$Invocation.Push
}

function Invoke-CdpWorkspaceInvocation {
    param([object]$Invocation)

    switch ($Invocation.WorkspaceAction) {
        'list' { Invoke-CdpWorkspace -List -ConfigPath $Invocation.ConfigPath; return }
        'add' {
            Invoke-CdpWorkspace `
                -Add $Invocation.WorkspaceName `
                -Projects $Invocation.Projects `
                -Open $Invocation.Open `
                -ConfigPath $Invocation.ConfigPath
            return
        }
        'open' {
            Invoke-CdpWorkspace `
                -Name $Invocation.WorkspaceName `
                -Open $Invocation.Open `
                -ConfigPath $Invocation.ConfigPath
            return
        }
        default { Invoke-CdpWorkspace -ConfigPath $Invocation.ConfigPath }
    }
}

function Invoke-CdpManagementInvocation {
    param([object]$Invocation)

    switch ($Invocation.Kind) {
        'doctor' {
            if ($Invocation.Fix) { Repair-ProjectConfig -ConfigPath $Invocation.ConfigPath }
            else { Test-ProjectHealth -ConfigPath $Invocation.ConfigPath }
        }
        'about' { Show-CdpAbout -ConfigPath $Invocation.ConfigPath }
        'recent' { Get-CdpRecentProjects -Count $Invocation.Count }
        'pin' { Set-ProjectPin -Name $Invocation.Name -ConfigPath $Invocation.ConfigPath }
        'unpin' { Clear-ProjectPin -Name $Invocation.Name -ConfigPath $Invocation.ConfigPath }
        'alias' { Add-ProjectAlias -Name $Invocation.Name -Alias $Invocation.Value -ConfigPath $Invocation.ConfigPath }
        'unalias' { Remove-ProjectAlias -Name $Invocation.Name -Alias $Invocation.Value -ConfigPath $Invocation.ConfigPath }
        'tag' { Add-ProjectTag -Name $Invocation.Name -Tag $Invocation.Value -ConfigPath $Invocation.ConfigPath }
        'untag' { Remove-ProjectTag -Name $Invocation.Name -Tag $Invocation.Value -ConfigPath $Invocation.ConfigPath }
        'clean' { Repair-ProjectConfig -ConfigPath $Invocation.ConfigPath }
        'init' {
            Initialize-Cdp -RootPath $Invocation.RootPath -ConfigPath $Invocation.ConfigPath -MaxDepth $Invocation.MaxDepth
        }
        'scan' {
            Import-GitProjects -RootPath $Invocation.RootPath -ConfigPath $Invocation.ConfigPath -MaxDepth $Invocation.MaxDepth
        }
    }
}

function Invoke-Cdp {
    <#
    .SYNOPSIS
        Short command entry point for cdp.

    .DESCRIPTION
        Keeps the classic `cdp` project switch behavior and adds lightweight
        subcommands such as `cdp doctor`.

    .PARAMETER Command
        Optional subcommand, query, or path-like config argument. Use `doctor` to
        run diagnostics. Non-path values are treated as project queries.

    .PARAMETER ConfigPath
        Optional custom path to projects.json file.

    .PARAMETER Query
        Optional project name or path query. `cdp api` is shorthand for
        `Invoke-Cdp -Query api`.

    .PARAMETER WSL
        If specified, launches WSL and changes to the selected project directory.

    .PARAMETER Open
        Optional command to start after switching to the selected project.

    .EXAMPLE
        cdp
        # Opens fzf menu to select a project

    .EXAMPLE
        cdp doctor
        # Runs cdp diagnostics

    .EXAMPLE
        cdp api
        # Switches directly when the query has one match

    .EXAMPLE
        cdp api -Open codex
        # Switches to the matching project and starts Codex there
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Command,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [switch]$WSL,

        [Parameter(Mandatory = $false)]
        [Alias('o')]
        [string]$Open,

        [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
        [string[]]$RemainingArgs
    )

    try {
        $invocation = ConvertFrom-CdpInvokeArguments `
            -Command $Command `
            -ConfigPath $ConfigPath `
            -Query $Query `
            -Open $Open `
            -RemainingArgs $RemainingArgs
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    switch ($invocation.Kind) {
        'status' { Invoke-CdpStatusInvocation -Invocation $invocation; return }
        'workspace' { Invoke-CdpWorkspaceInvocation -Invocation $invocation; return }
        'switch' {
            Switch-Project `
                -ConfigPath $invocation.ConfigPath `
                -Query $invocation.Query `
                -WSL:$WSL `
                -Open $invocation.Open
            return
        }
        default { Invoke-CdpManagementInvocation -Invocation $invocation }
    }
}

# Export module members
Set-Alias -Name cdp -Value Invoke-Cdp
Set-Alias -Name cdp-add -Value Add-Project
Set-Alias -Name cdp-rm -Value Remove-Project
Set-Alias -Name cdp-ls -Value Get-ProjectList
Set-Alias -Name cdp-edit -Value Edit-ProjectConfig
Set-Alias -Name cdp-config -Value Set-ProjectConfig
Set-Alias -Name cdp-doctor -Value Test-ProjectHealth
Set-Alias -Name cdp-scan -Value Import-GitProjects
Set-Alias -Name cdp-recent -Value Get-CdpRecentProjects
Set-Alias -Name cdp-pin -Value Set-ProjectPin
Set-Alias -Name cdp-unpin -Value Clear-ProjectPin
Set-Alias -Name cdp-clean -Value Repair-ProjectConfig
Set-Alias -Name cdp-status -Value Show-CdpProjectStatus
Set-Alias -Name cdp-init -Value Initialize-Cdp
Set-Alias -Name cdp-alias -Value Add-ProjectAlias
Set-Alias -Name cdp-unalias -Value Remove-ProjectAlias
Set-Alias -Name cdp-tag -Value Add-ProjectTag
Set-Alias -Name cdp-untag -Value Remove-ProjectTag

Register-ArgumentCompleter -CommandName Invoke-Cdp -ParameterName Command -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $subcommands = @(
        'status', 'doctor', 'about', 'recent', 'pin', 'unpin',
        'alias', 'unalias', 'tag', 'untag', 'clean', 'init', 'scan', 'workspace'
    )

    $completions = @($subcommands | Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) })

    try {
        $configPath = Get-DefaultConfigPath
        if (Test-Path -LiteralPath $configPath) {
            $configData = Get-CdpProjectConfig -ConfigPath $configPath
            $completions += @($configData.EnabledProjects | ForEach-Object {
                $name = [string]$_.name
                if ($name -like "$wordToComplete*") {
                    [System.Management.Automation.CompletionResult]::new($name, $name, 'ParameterValue', $name)
                }
            } | Where-Object { $null -ne $_ })
        }
    } catch {}

    return $completions
}

Register-ArgumentCompleter -CommandName Invoke-Cdp -ParameterName Open -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    @('code', 'cursor', 'codex', 'claude', 'gemini') | Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

Export-ModuleMember `
    -Function Invoke-Cdp, Switch-Project, Get-ProjectList, Add-Project, Set-ProjectPin, Clear-ProjectPin, Repair-ProjectConfig, Initialize-Cdp, Add-ProjectAlias, Remove-ProjectAlias, Add-ProjectTag, Remove-ProjectTag, Import-GitProjects, Remove-Project, Edit-ProjectConfig, Set-ProjectConfig, Test-ProjectHealth, Show-CdpAbout, Get-CdpRecentProjects, Show-CdpProjectStatus, Invoke-CdpWorkspace `
    -Alias cdp, cdp-add, cdp-rm, cdp-ls, cdp-edit, cdp-config, cdp-doctor, cdp-scan, cdp-recent, cdp-pin, cdp-unpin, cdp-clean, cdp-init, cdp-alias, cdp-unalias, cdp-tag, cdp-untag, cdp-status
