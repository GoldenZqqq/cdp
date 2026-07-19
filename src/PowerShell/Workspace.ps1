# cdp PowerShell domain: Workspace.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function Get-CdpWorkspaceLauncher {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Open
    )

    $launcherName = $Open.Trim()
    if ($launcherName -notmatch '^[A-Za-z0-9._:/\\-]+$') {
        throw 'Launcher must be a single executable name or safe path without arguments.'
    }
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
    $resolution = Resolve-CdpProjectPath -Project $Project -Profile $(if ($WSL) { 'wsl' } else { $null })
    if ($resolution.ErrorCode) { throw $resolution.ErrorMessage }
    $workingDirectory = $resolution.ResolvedPath

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

function Invoke-CdpWorkspaceLaunch {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)][object[]]$Projects,
        [Parameter(Mandatory = $true)][string[]]$ProjectNames,
        [Parameter(Mandatory = $false)][object]$Launcher,
        [Parameter(Mandatory = $false)][switch]$PassThru
    )

    $hasWt = $null -ne (Get-Command wt.exe -ErrorAction SilentlyContinue)
    $results = @()
    foreach ($projName in $ProjectNames) {
        $project = @($Projects | Where-Object {
            [string]::Equals([string]$_.name, $projName, [StringComparison]::OrdinalIgnoreCase)
        } | Select-Object -First 1)
        if ($project.Count -eq 0) {
            Write-Host "  Project '$projName' not found in config, skipping." -ForegroundColor Yellow
            $results += New-CdpActionResult -Action 'launch-workspace-project' -Target $projName -Status 'failed' -Changed $false -Error 'Project not found in active config.'
            continue
        }
        $project = $project[0]
        $resolution = Resolve-CdpProjectPath -Project $project
        if ($resolution.ErrorCode) {
            Write-Host "  Invalid path profile for '$projName', skipping." -ForegroundColor Yellow
            $results += New-CdpActionResult -Action 'launch-workspace-project' -Target $projName -Status 'failed' -Changed $false -Error $resolution.ErrorMessage
            continue
        }
        $projPath = [string]$resolution.ResolvedPath
        if (-not (Test-Path -LiteralPath $projPath)) {
            Write-Host "  Path missing for '$projName', skipping." -ForegroundColor Yellow
            $results += New-CdpActionResult -Action 'launch-workspace-project' -Target $projName -Status 'failed' -Changed $false -Error 'Project path is missing.'
            continue
        }
        if (-not $hasWt) {
            Write-Host "  $projName -> $projPath" -ForegroundColor Cyan
            $results += New-CdpActionResult -Action 'launch-workspace-project' -Target $projName -Status 'skipped' -Changed $false -Error 'Windows Terminal is unavailable.'
            continue
        }

        $wtArgs = @('-w', '0', 'new-tab', '-d', $projPath, '--title', $projName)
        if ($null -ne $Launcher) {
            $wtArgs += @('--', $Launcher.Command) + @($Launcher.Arguments)
        }
        if (-not $PSCmdlet.ShouldProcess("$projName ($projPath)", 'Launch Windows Terminal workspace tab')) {
            $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
            $results += New-CdpActionResult -Action 'launch-workspace-project' -Target $projName -Status $status -Changed $false
            continue
        }
        try {
            Start-Process wt.exe -ArgumentList $wtArgs -ErrorAction Stop
            Write-Host "  Opened tab: $projName" -ForegroundColor Green
            $results += New-CdpActionResult -Action 'launch-workspace-project' -Target $projName -Status 'succeeded' -Changed $true
        } catch {
            Write-Host "  Failed to open tab '$projName': $($_.Exception.Message)" -ForegroundColor Red
            $results += New-CdpActionResult -Action 'launch-workspace-project' -Target $projName -Status 'failed' -Changed $false -Error $_.Exception.Message
        }
    }
    if (-not $hasWt) {
        Write-Host "`nWindows Terminal (wt.exe) not found. Listed projects above." -ForegroundColor Yellow
        Write-Host "Install Windows Terminal for multi-tab workspace launching." -ForegroundColor Gray
    }
    if (@($results | Where-Object Status -eq 'failed').Count -gt 0) { $global:LASTEXITCODE = 1 }
    if ($PassThru) { return $results }
}

function Invoke-CdpWorkspace {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
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
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    $wsPath = Get-CdpWorkspacesPath -ConfigPath $ConfigPath

    if ($List) {
        $workspaceDocument = if (Test-Path -LiteralPath $wsPath) {
            Read-CdpJsonDocument -LiteralPath $wsPath
        } else {
            [PSCustomObject]@{ Value = @(); Fingerprint = 'missing' }
        }
        $workspaces = @($workspaceDocument.Value)
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
        if (-not [string]::IsNullOrWhiteSpace($Open)) {
            [void](Get-CdpWorkspaceLauncher -Open $Open)
        }

        $workspaceDocument = if (Test-Path -LiteralPath $wsPath) {
            Read-CdpJsonDocument -LiteralPath $wsPath
        } else {
            [PSCustomObject]@{ Value = @(); Fingerprint = 'missing' }
        }
        $workspaces = @($workspaceDocument.Value)
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

        if (-not $PSCmdlet.ShouldProcess($Add, "Create workspace definition in $wsPath")) {
            if ($PassThru) {
                $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
                return New-CdpActionResult -Action 'add-workspace' -Target $Add -Status $status -Changed $false -Details $newWs
            }
            return
        }

        $allWs = @($workspaces) + @($newWs)
        [void](Write-CdpJsonFile -LiteralPath $wsPath -Value @($allWs) -ExpectedFingerprint $workspaceDocument.Fingerprint)
        Write-Host "Workspace '$Add' created with $($Projects.Count) projects." -ForegroundColor Green
        if ($PassThru) {
            return New-CdpActionResult -Action 'add-workspace' -Target $Add -Status 'succeeded' -Changed $true -Details $newWs
        }
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
    $launcherName = if (-not [string]::IsNullOrWhiteSpace($Open)) { [string]$Open } elseif ($ws.open) { [string]$ws.open } else { "" }
    $launcher = if (-not [string]::IsNullOrWhiteSpace($launcherName)) {
        Get-CdpWorkspaceLauncher -Open $launcherName
    } else {
        $null
    }

    $launchParameters = @{
        Projects = @($configData.EnabledProjects)
        ProjectNames = @($ws.projects)
        Launcher = $launcher
        PassThru = $PassThru
    }
    if ($WhatIfPreference) { $launchParameters.WhatIf = $true }
    if ($PSBoundParameters.ContainsKey('Confirm')) { $launchParameters.Confirm = $PSBoundParameters['Confirm'] }
    Invoke-CdpWorkspaceLaunch @launchParameters
}

function Invoke-CdpWorkspaceInvocation {
    param([object]$Invocation)

    $safety = @{}
    if ($Invocation.DryRun) { $safety.WhatIf = $true }
    if ($Invocation.Yes) { $safety.Confirm = $false }

    switch ($Invocation.WorkspaceAction) {
        'list' { Invoke-CdpWorkspace -List -ConfigPath $Invocation.ConfigPath; return }
        'add' {
            Invoke-CdpWorkspace @safety `
                -Add $Invocation.WorkspaceName `
                -Projects $Invocation.Projects `
                -Open $Invocation.Open `
                -ConfigPath $Invocation.ConfigPath
            return
        }
        'open' {
            Invoke-CdpWorkspace @safety `
                -Name $Invocation.WorkspaceName `
                -Open $Invocation.Open `
                -ConfigPath $Invocation.ConfigPath
            return
        }
        default { Invoke-CdpWorkspace -ConfigPath $Invocation.ConfigPath }
    }
}
