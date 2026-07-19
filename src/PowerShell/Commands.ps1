# cdp PowerShell domain: Commands.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

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

    .PARAMETER AllowHook
        Execute a project command hook for this switch only. Command hooks are
        skipped by default.

    .PARAMETER NoHook
        Skip all onEnter environment values and command hooks for this switch.

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
        [string]$Open,

        [Parameter(Mandatory = $false)]
        [switch]$AllowHook,

        [Parameter(Mandatory = $false)]
        [switch]$NoHook
    )

    # Get config path
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Get-DefaultConfigPath
    }

    # Initialize config file if it doesn't exist and not using Project Manager
    $customConfigPath = Join-Path (Get-CdpUserHome) ".cdp\projects.json"
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
            $pathProfile = if ($WSL) { 'wsl' } else { $null }
            $previewDir = New-CdpPickerPreviewDirectory -Projects $projectsForSelection -Profile $pathProfile
            $previewCommand = Get-CdpPickerPreviewCommand -PreviewDir $previewDir
            $colorOption = "--color=$(Get-CdpFzfColorTheme)"
            $pickerLines = for ($i = 0; $i -lt $projectsForSelection.Count; $i++) {
                New-CdpPickerLine -Project $projectsForSelection[$i] -Index ($i + 1) -Profile $pathProfile
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

    if ($null -eq $selectedProject) {
        Write-Host "Error: Could not find project '$selectedProjectName'." -ForegroundColor Red
        return
    }

    try {
        $resolution = Resolve-CdpProjectPath -Project $selectedProject -Profile $(if ($WSL) { 'wsl' } else { $null })
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    if ($resolution.ErrorCode) {
        Write-Host "Error: $($resolution.ErrorMessage)" -ForegroundColor Red
        Write-Host "Project: $selectedProjectName; profile: $($resolution.Profile)" -ForegroundColor Gray
        return
    }

    if ($WSL -or (Test-Path -LiteralPath $resolution.ResolvedPath)) {
        if ($WSL) {
            $wslPath = $resolution.ResolvedPath
            $launchText = if ([string]::IsNullOrWhiteSpace($Open)) {
                "Launching WSL in project: $($selectedProject.name)"
            } else {
                "Launching WSL workspace: $($selectedProject.name)"
            }
            Write-Host $launchText -ForegroundColor Green
            Write-Host "WSL path: $wslPath" -ForegroundColor Gray

            if ([string]::IsNullOrWhiteSpace($Open)) {
                wsl --cd $wslPath
            } else {
                Invoke-CdpWorkspaceLauncher -Project $selectedProject -Open $Open -WSL
            }
            if ($LASTEXITCODE -eq 0 -or $env:CDP_OPEN_DRY_RUN -eq '1') {
                Add-CdpRecentProject -Project $selectedProject
            }
        } else {
            Set-Location -LiteralPath $resolution.ResolvedPath
            Add-CdpRecentProject -Project $selectedProject
            Write-Host "Switched to project: $($selectedProject.name)" -ForegroundColor Green

            # Update Windows Terminal tab title
            $newTitle = $selectedProject.name
            Write-Host -NoNewline "$([char]27)]0;$newTitle$([char]7)"

            Invoke-CdpOnEnter `
                -Project $selectedProject `
                -ConfigPath $ConfigPath `
                -AllowHook:$AllowHook `
                -NoHook:$NoHook

            if (-not [string]::IsNullOrWhiteSpace($Open)) {
                Invoke-CdpWorkspaceLauncher -Project $selectedProject -Open $Open
            }
        }
    } else {
        Write-Host "Error: Directory not found for project '$selectedProjectName'." -ForegroundColor Red
        Write-Host "Profile: $($resolution.Profile); path: $($resolution.ResolvedPath)" -ForegroundColor Gray
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
    $customConfigPath = Join-Path (Get-CdpUserHome) ".cdp\projects.json"
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
            $resolution = Resolve-CdpProjectPath -Project $project
            $pathText = if ($resolution.ErrorCode) { "<invalid $($resolution.Source)>" } else { $resolution.ResolvedPath }
            Write-Host $pathText -ForegroundColor DarkGray
            $index++
        }

        Write-Host ("-" * 104) -ForegroundColor DarkGray
        Write-Host "config: $ConfigPath" -ForegroundColor DarkGray
    } catch {
        Write-Host "Error: Failed to read configuration." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

function Invoke-CdpManagementInvocation {
    param([object]$Invocation)

    $safety = @{}
    if ($Invocation.DryRun) { $safety.WhatIf = $true }
    if ($Invocation.Yes) { $safety.Confirm = $false }

    switch ($Invocation.Kind) {
        'hook' { Invoke-CdpHookCommand @safety -Action $Invocation.HookAction -Name $Invocation.Name -ConfigPath $Invocation.ConfigPath }
        'doctor' {
            if ($Invocation.Fix) { Repair-ProjectConfig @safety -ConfigPath $Invocation.ConfigPath }
            else { Test-ProjectHealth -ConfigPath $Invocation.ConfigPath }
        }
        'about' { Show-CdpAbout -ConfigPath $Invocation.ConfigPath }
        'recent' { Get-CdpRecentProjects -Count $Invocation.Count }
        'config' { Set-ProjectConfig @safety -Selection $Invocation.Count }
        'add' { Add-Project @safety -Name $Invocation.Name -Path $Invocation.RootPath -ConfigPath $Invocation.ConfigPath }
        'remove' { Remove-Project @safety -Name $Invocation.Name -ConfigPath $Invocation.ConfigPath }
        'pin' { Set-ProjectPin @safety -Name $Invocation.Name -ConfigPath $Invocation.ConfigPath }
        'unpin' { Clear-ProjectPin @safety -Name $Invocation.Name -ConfigPath $Invocation.ConfigPath }
        'alias' { Add-ProjectAlias @safety -Name $Invocation.Name -Alias $Invocation.Value -ConfigPath $Invocation.ConfigPath }
        'unalias' { Remove-ProjectAlias @safety -Name $Invocation.Name -Alias $Invocation.Value -ConfigPath $Invocation.ConfigPath }
        'tag' { Add-ProjectTag @safety -Name $Invocation.Name -Tag $Invocation.Value -ConfigPath $Invocation.ConfigPath }
        'untag' { Remove-ProjectTag @safety -Name $Invocation.Name -Tag $Invocation.Value -ConfigPath $Invocation.ConfigPath }
        'clean' { Repair-ProjectConfig @safety -ConfigPath $Invocation.ConfigPath }
        'init' {
            Initialize-Cdp @safety -RootPath $Invocation.RootPath -ConfigPath $Invocation.ConfigPath -MaxDepth $Invocation.MaxDepth
        }
        'scan' {
            Import-GitProjects @safety -RootPath $Invocation.RootPath -ConfigPath $Invocation.ConfigPath -MaxDepth $Invocation.MaxDepth
        }
    }
}

function Test-CdpInvocationMutation {
    param([Parameter(Mandatory = $true)][object]$Invocation)

    if ($Invocation.Kind -eq 'status') { return $Invocation.Fix -or $Invocation.Push }
    if ($Invocation.Kind -eq 'workspace') { return $Invocation.WorkspaceAction -in @('add', 'open') }
    if ($Invocation.Kind -eq 'hook') { return $Invocation.HookAction -in @('trust', 'revoke') }
    if ($Invocation.Kind -eq 'doctor') { return $Invocation.Fix }
    $Invocation.Kind -in @('add', 'remove', 'pin', 'unpin', 'alias', 'unalias', 'tag', 'untag', 'clean', 'init', 'scan', 'config')
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

    .PARAMETER AllowHook
        Execute a project command hook for this switch only. Command hooks are
        skipped by default.

    .PARAMETER NoHook
        Skip all onEnter behavior for this switch.

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

    [CmdletBinding(SupportsShouldProcess = $true)]
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

        [Parameter(Mandatory = $false)]
        [switch]$AllowHook,

        [Parameter(Mandatory = $false)]
        [switch]$NoHook,

        [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
        [string[]]$RemainingArgs
    )

    $jsonRequested = @($Command, $ConfigPath) + @($RemainingArgs) | Where-Object { $_ -in @('--json', '-json') }
    try {
        $parserArgs = @($RemainingArgs)
        if ($AllowHook) { $parserArgs = @('--allow-hook') + $parserArgs }
        if ($NoHook) { $parserArgs = @('--no-hook') + $parserArgs }
        $invocation = ConvertFrom-CdpInvokeArguments `
            -Command $Command `
            -ConfigPath $ConfigPath `
            -Query $Query `
            -Open $Open `
            -RemainingArgs $parserArgs
        if ($WhatIfPreference) { $invocation.DryRun = $true }
        if ($PSBoundParameters.ContainsKey('Confirm') -and $PSBoundParameters['Confirm'] -eq $false) {
            $invocation.Yes = $true
        }
        if ($invocation.DryRun -and $invocation.Yes) {
            throw 'The -WhatIf and explicit confirmation options cannot be combined.'
        }
        if (($invocation.DryRun -or $invocation.Yes) -and -not (Test-CdpInvocationMutation -Invocation $invocation)) {
            throw 'Safety options are only valid for mutating commands.'
        }
    } catch {
        if ($jsonRequested) {
            [Console]::Error.WriteLine("Error: $($_.Exception.Message)")
            $global:LASTEXITCODE = 3
        } else {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
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
                -Open $invocation.Open `
                -AllowHook:$invocation.AllowHook `
                -NoHook:$invocation.NoHook
            return
        }
        default { Invoke-CdpManagementInvocation -Invocation $invocation }
    }
}
