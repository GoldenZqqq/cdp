# cdp PowerShell domain: Workspace.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function Get-CdpWorkspaceLauncher {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Open
    )

    $launcherName = $Open
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
        default { throw "Unsupported launcher '$Open'. Use code, cursor, codex, claude, or gemini." }
    }

    [PSCustomObject]@{
        Name = $command
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

function Complete-CdpWorkspaceLaunch {
    param([object[]]$Results, [bool]$HasWindowsTerminal, [switch]$PassThru)

    if (-not $HasWindowsTerminal) {
        Write-Host "`nWindows Terminal (wt.exe) not found. Listed projects above." -ForegroundColor Yellow
        Write-Host 'Install Windows Terminal for multi-tab workspace launching.' -ForegroundColor Gray
    }
    $global:LASTEXITCODE = if (@($Results | Where-Object Status -eq 'failed').Count -gt 0) { 1 } else { 0 }
    if ($PassThru) { $Results }
}

function Invoke-CdpWorkspaceLaunch {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $false)][object[]]$Projects,
        [Parameter(Mandatory = $false)][string[]]$ProjectNames,
        [Parameter(Mandatory = $false)][object]$Launcher,
        [Parameter(Mandatory = $false)][object[]]$Plan,
        [Parameter(Mandatory = $false)][object]$Layout,
        [Parameter(Mandatory = $false)][switch]$PassThru
    )

    if (-not $Layout) { $Layout = [PSCustomObject]@{ mode = 'tabs' } }
    if (-not $Plan) { $Plan = @(New-CdpLegacyWorkspaceLaunchPlan -Projects $Projects -ProjectNames $ProjectNames -Launcher $Launcher) }
    $nativePlan = @(New-CdpWindowsTerminalLaunchPlan -Plan $Plan -Layout $Layout)
    $launchable = @($nativePlan | Where-Object { $_.Item.Status -in @('ok', 'legacy', 'renamed') })
    $hasWt = $launchable.Count -eq 0 -or $WhatIfPreference
    if (-not $hasWt) { $hasWt = $null -ne (Get-Command wt.exe -ErrorAction SilentlyContinue) }
    $results = @()
    $first = $true
    foreach ($nativeItem in $nativePlan) {
        $item = $nativeItem.Item
        if ($item.Status -notin @('ok', 'legacy', 'renamed')) {
            Write-Host "  Cannot launch '$($item.Name)': $($item.Status)." -ForegroundColor Yellow
            $results += New-CdpActionResult -Action 'launch-workspace-project' -Target $item.Name -Status 'failed' -Changed $false -Error $item.Status
            continue
        }
        if (-not $hasWt -and -not $WhatIfPreference) {
            Write-Host "  $($item.Name) -> $($item.ResolvedPath)" -ForegroundColor Cyan
            $results += New-CdpActionResult -Action 'launch-workspace-project' -Target $item.Name -Status 'skipped' -Changed $false -Error 'Windows Terminal is unavailable.'
            continue
        }

        $wtArgs = if ($first) { $nativeItem.FirstArguments } else { $nativeItem.NextArguments }
        if (-not $PSCmdlet.ShouldProcess("$($item.Name) ($($item.ResolvedPath))", 'Launch Windows Terminal workspace item')) {
            $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
            $results += New-CdpActionResult -Action 'launch-workspace-project' -Target $item.Name -Status $status -Changed $false
            continue
        }
        try {
            Start-Process wt.exe -ArgumentList $wtArgs -ErrorAction Stop
            Write-Host "  Opened workspace item: $($item.Name)" -ForegroundColor Green
            $results += New-CdpActionResult -Action 'launch-workspace-project' -Target $item.Name -Status 'succeeded' -Changed $true
            $first = $false
        } catch {
            Write-Host "  Failed to open '$($item.Name)': $($_.Exception.Message)" -ForegroundColor Red
            $results += New-CdpActionResult -Action 'launch-workspace-project' -Target $item.Name -Status 'failed' -Changed $false -Error $_.Exception.Message
        }
    }
    Complete-CdpWorkspaceLaunch -Results $results -HasWindowsTerminal ($hasWt -or $WhatIfPreference) -PassThru:$PassThru
}

function Invoke-CdpWorkspaceAddAction {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param([string]$Name, [string[]]$Projects, [string]$Open, [string]$Layout, [string]$ConfigPath, [switch]$PassThru)

    $workspacePath = Get-CdpWorkspacesPath -ConfigPath $ConfigPath
    $document = Read-CdpWorkspaceDocument -Path $workspacePath
    $workspaces = @($document.Value)
    if ((Get-CdpWorkspaceByName -Workspaces $workspaces -Name $Name).Count -gt 0) {
        throw "Workspace '$Name' already exists."
    }
    $context = Get-CdpWorkspaceConfigContext -ConfigPath $ConfigPath
    $workspace = New-CdpWorkspaceDefinition -Name $Name -ProjectNames $Projects `
        -Projects @($context.Data.Projects) -Open $Open -Layout $Layout
    if (-not $PSCmdlet.ShouldProcess($Name, "Create workspace definition in $workspacePath")) {
        if ($PassThru) {
            $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
            return New-CdpActionResult -Action add-workspace -Target $Name -Status $status -Changed $false -Details $workspace
        }
        return
    }
    [void](Write-CdpJsonFile -LiteralPath $workspacePath -Value @($workspaces + $workspace) -ExpectedFingerprint $document.Fingerprint)
    Write-Host "Workspace '$Name' created with $($Projects.Count) projects." -ForegroundColor Green
    if ($PassThru) { New-CdpActionResult -Action add-workspace -Target $Name -Status succeeded -Changed $true -Details $workspace }
}

function Invoke-CdpWorkspaceEditAction {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param([string]$Name, [string[]]$Projects, [string]$Open, [string]$Layout, [switch]$ClearOpen, [string]$ConfigPath, [switch]$PassThru)

    $workspacePath = Get-CdpWorkspacesPath -ConfigPath $ConfigPath
    $document = Read-CdpWorkspaceDocument -Path $workspacePath
    $workspaces = @($document.Value)
    $workspaceMatches = @(Get-CdpWorkspaceByName -Workspaces $workspaces -Name $Name)
    if ($workspaceMatches.Count -eq 0) { throw "Workspace '$Name' not found." }
    $context = Get-CdpWorkspaceConfigContext -ConfigPath $ConfigPath
    $update = Update-CdpWorkspaceDefinition -Workspace $workspaceMatches[0] -ProjectNames $Projects `
        -Projects @($context.Data.Projects) -Open $Open -Layout $Layout -ClearOpen:$ClearOpen
    if (-not $update.Changed) {
        if ($PassThru) { return New-CdpActionResult -Action edit-workspace -Target $Name -Status skipped -Changed $false -Details $update.Workspace }
        return
    }
    if (-not $PSCmdlet.ShouldProcess($Name, "Edit workspace definition in $workspacePath")) {
        if ($PassThru) {
            $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
            return New-CdpActionResult -Action edit-workspace -Target $Name -Status $status -Changed $false -Details $update.Workspace
        }
        return
    }
    [void](Write-CdpJsonFile -LiteralPath $workspacePath -Value $workspaces -ExpectedFingerprint $document.Fingerprint)
    Write-Host "Workspace '$Name' updated." -ForegroundColor Green
    if ($PassThru) { New-CdpActionResult -Action edit-workspace -Target $Name -Status succeeded -Changed $true -Details $update.Workspace }
}

function Invoke-CdpWorkspaceRemoveAction {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param([string]$Name, [string]$ConfigPath, [switch]$PassThru)

    $workspacePath = Get-CdpWorkspacesPath -ConfigPath $ConfigPath
    $document = Read-CdpWorkspaceDocument -Path $workspacePath
    $workspaces = @($document.Value)
    $workspaceMatches = @(Get-CdpWorkspaceByName -Workspaces $workspaces -Name $Name)
    if ($workspaceMatches.Count -eq 0) { throw "Workspace '$Name' not found." }
    if (-not $PSCmdlet.ShouldProcess($Name, "Remove workspace definition from $workspacePath")) {
        if ($PassThru) {
            $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
            return New-CdpActionResult -Action remove-workspace -Target $Name -Status $status -Changed $false -Details $workspaceMatches[0]
        }
        return
    }
    $remaining = @($workspaces | Where-Object { -not [string]::Equals([string]$_.name, $Name, [StringComparison]::Ordinal) })
    [void](Write-CdpJsonFile -LiteralPath $workspacePath -Value $remaining -ExpectedFingerprint $document.Fingerprint)
    Write-Host "Workspace '$Name' removed." -ForegroundColor Green
    if ($PassThru) { New-CdpActionResult -Action remove-workspace -Target $Name -Status succeeded -Changed $true -Details $workspaceMatches[0] }
}

function Invoke-CdpWorkspaceValidateAction {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param([string]$Name, [switch]$Fix, [string]$ConfigPath, [switch]$PassThru)

    $workspacePath = Get-CdpWorkspacesPath -ConfigPath $ConfigPath
    $document = Read-CdpWorkspaceDocument -Path $workspacePath
    $workspaces = @($document.Value)
    $targets = if ($Name) { @(Get-CdpWorkspaceByName -Workspaces $workspaces -Name $Name) } else { $workspaces }
    if ($Name -and $targets.Count -eq 0) { throw "Workspace '$Name' not found." }
    $context = Get-CdpWorkspaceConfigContext -ConfigPath $ConfigPath
    $results = @()
    foreach ($workspace in $targets) {
        $results += Get-CdpWorkspaceValidation -Workspace $workspace -Projects @($context.Data.Projects)
    }
    if (-not $Fix) { Write-CdpWorkspaceValidation $results; if ($PassThru) { return $results }; return }
    $changed = $false
    foreach ($workspace in $targets) {
        $validation = @(Get-CdpWorkspaceValidation -Workspace $workspace -Projects @($context.Data.Projects))
        $conversion = Convert-CdpWorkspaceReferences -Workspace $workspace -Validation $validation
        if ($conversion.Changed) { $changed = $true }
    }
    Write-CdpWorkspaceValidation $results
    if (-not $changed) {
        if ($PassThru) { return New-CdpActionResult -Action validate-workspace -Target $(if($Name){$Name}else{$workspacePath}) -Status skipped -Changed $false -Details $results }
        return
    }
    if (-not $PSCmdlet.ShouldProcess($workspacePath, 'Migrate resolvable workspace references')) {
        if ($PassThru) {
            $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
            return New-CdpActionResult -Action validate-workspace -Target $(if($Name){$Name}else{$workspacePath}) -Status $status -Changed $false -Details $results
        }
        return
    }
    [void](Write-CdpJsonFile -LiteralPath $workspacePath -Value $workspaces -ExpectedFingerprint $document.Fingerprint)
    if ($PassThru) { New-CdpActionResult -Action validate-workspace -Target $(if($Name){$Name}else{$workspacePath}) -Status succeeded -Changed $true -Details $results }
}

function Invoke-CdpWorkspaceShowAction {
    param([string]$Name, [string]$ConfigPath, [switch]$PassThru)

    $workspacePath = Get-CdpWorkspacesPath -ConfigPath $ConfigPath
    $workspaces = @((Read-CdpWorkspaceDocument -Path $workspacePath).Value)
    $workspaceMatches = @(Get-CdpWorkspaceByName -Workspaces $workspaces -Name $Name)
    if ($workspaceMatches.Count -eq 0) { throw "Workspace '$Name' not found." }
    $context = Get-CdpWorkspaceConfigContext -ConfigPath $ConfigPath
    Show-CdpWorkspaceDetail -Workspace $workspaceMatches[0] -Projects @($context.Data.Projects) -PassThru:$PassThru
}

function Invoke-CdpWorkspaceListAction {
    param([string]$ConfigPath)

    $workspacePath = Get-CdpWorkspacesPath -ConfigPath $ConfigPath
    $workspaces = @((Read-CdpWorkspaceDocument -Path $workspacePath).Value)
    Show-CdpWorkspaceList -Workspaces $workspaces
}

function Invoke-CdpWorkspaceOpenAction {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param([string]$Name, [string]$Open, [string]$ConfigPath, [switch]$PassThru)

    $workspacePath = Get-CdpWorkspacesPath -ConfigPath $ConfigPath
    $workspaces = @((Read-CdpWorkspaceDocument -Path $workspacePath).Value)
    $workspaceMatches = @(Get-CdpWorkspaceByName -Workspaces $workspaces -Name $Name)
    if ($workspaceMatches.Count -eq 0) { throw "Workspace '$Name' not found." }
    $workspace = $workspaceMatches[0]
    $context = Get-CdpWorkspaceConfigContext -ConfigPath $ConfigPath
    $layout = ConvertTo-CdpWorkspaceLayout -Existing $workspace.layout
    if (-not (Test-CdpWorkspaceLayout -Layout $layout)) { throw 'Workspace layout is invalid.' }
    $plan = @(New-CdpWorkspaceLaunchPlan -Workspace $workspace -Projects @($context.Data.Projects) -OpenOverride $Open)
    $launchParameters = @{ Plan=$plan; Layout=$layout; PassThru=$PassThru }
    if ($WhatIfPreference) { $launchParameters.WhatIf = $true }
    if ($PSBoundParameters.ContainsKey('Confirm')) { $launchParameters.Confirm = $PSBoundParameters['Confirm'] }
    Invoke-CdpWorkspaceLaunch @launchParameters
}

function Invoke-CdpWorkspace {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
    param(
        [Parameter(Position = 0)][string]$Name,
        [switch]$List,
        [string]$Add,
        [string]$Show,
        [string]$Edit,
        [string]$Remove,
        [switch]$Validate,
        [switch]$Fix,
        [string[]]$Projects,
        [string]$Open,
        [string]$Layout,
        [switch]$ClearOpen,
        [string]$ConfigPath,
        [switch]$PassThru
    )

    $safety = @{}
    if ($WhatIfPreference) { $safety.WhatIf = $true }
    if ($PSBoundParameters.ContainsKey("Confirm")) { $safety.Confirm = $PSBoundParameters["Confirm"] }
    if ($List) { return Invoke-CdpWorkspaceListAction -ConfigPath $ConfigPath }
    if ($Show) { return Invoke-CdpWorkspaceShowAction -Name $Show -ConfigPath $ConfigPath -PassThru:$PassThru }
    if ($Remove) { return Invoke-CdpWorkspaceRemoveAction @safety -Name $Remove -ConfigPath $ConfigPath -PassThru:$PassThru }
    if ($Validate) {
        return Invoke-CdpWorkspaceValidateAction @safety -Name $Name -Fix:$Fix -ConfigPath $ConfigPath -PassThru:$PassThru
    }
    if ($Edit) {
        return Invoke-CdpWorkspaceEditAction @safety -Name $Edit -Projects $Projects -Open $Open -Layout $Layout `
            -ClearOpen:$ClearOpen -ConfigPath $ConfigPath -PassThru:$PassThru
    }
    if (-not [string]::IsNullOrWhiteSpace($Add)) {
        return Invoke-CdpWorkspaceAddAction @safety -Name $Add -Projects $Projects -Open $Open -Layout $Layout `
            -ConfigPath $ConfigPath -PassThru:$PassThru
    }
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Host "Usage: cdp workspace <name> | cdp workspace list | cdp workspace add <name> <projects...>" -ForegroundColor Yellow
        return
    }
    Invoke-CdpWorkspaceOpenAction @safety -Name $Name -Open $Open -ConfigPath $ConfigPath -PassThru:$PassThru
}

function Invoke-CdpWorkspaceInvocation {
    param([object]$Invocation)

    $safety = @{}
    if ($Invocation.DryRun) { $safety.WhatIf = $true }
    if ($Invocation.Yes) { $safety.Confirm = $false }

    switch ($Invocation.WorkspaceAction) {
        'list' { Invoke-CdpWorkspace -List -ConfigPath $Invocation.ConfigPath; return }
        'show' { Invoke-CdpWorkspace -Show $Invocation.WorkspaceName -ConfigPath $Invocation.ConfigPath; return }
        'add' {
            Invoke-CdpWorkspace @safety `
                -Add $Invocation.WorkspaceName `
                -Projects $Invocation.Projects `
                -Open $Invocation.Open `
                -Layout $Invocation.WorkspaceLayout `
                -ConfigPath $Invocation.ConfigPath
            return
        }
        'edit' {
            Invoke-CdpWorkspace @safety -Edit $Invocation.WorkspaceName -Projects $Invocation.Projects `
                -Open $Invocation.Open -ClearOpen:$Invocation.ClearOpen -Layout $Invocation.WorkspaceLayout `
                -ConfigPath $Invocation.ConfigPath
            return
        }
        'remove' { Invoke-CdpWorkspace @safety -Remove $Invocation.WorkspaceName -ConfigPath $Invocation.ConfigPath; return }
        'validate' {
            Invoke-CdpWorkspace @safety -Validate -Fix:$Invocation.Fix -Name $Invocation.WorkspaceName -ConfigPath $Invocation.ConfigPath
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
