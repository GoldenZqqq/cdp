# cdp PowerShell domain: ExecSelection.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function New-CdpExecPlanItem {
    param(
        [object]$Project,
        [string]$Name,
        [AllowEmptyString()][string]$RawPath,
        [AllowEmptyString()][string]$ResolvedPath,
        [string]$Status,
        [AllowEmptyString()][string]$Error = ''
    )

    [PSCustomObject]@{
        Name = $Name
        RawPath = $RawPath
        ResolvedPath = $ResolvedPath
        Project = $Project
        Status = $Status
        ExitCode = $null
        ElapsedMs = 0
        Stdout = ''
        Stderr = ''
        Error = $Error
    }
}

function ConvertTo-CdpExecProjectPlanItem {
    param([Parameter(Mandatory = $true)][object]$Project)

    $resolution = Resolve-CdpProjectPath -Project $Project
    $status = 'planned'
    $error = ''
    if ($Project.enabled -ne $true) {
        $status = 'disabled_project'
        $error = 'Project is disabled.'
    } elseif ($resolution.ErrorCode) {
        $status = 'path_profile_invalid'
        $error = $resolution.ErrorMessage
    } elseif (-not (Test-Path -LiteralPath $resolution.ResolvedPath -PathType Container)) {
        $status = 'path_missing'
        $error = 'Resolved project path does not exist.'
    }
    New-CdpExecPlanItem -Project $Project -Name ([string]$Project.name) `
        -RawPath ([string]$resolution.RawPath) -ResolvedPath ([string]$resolution.ResolvedPath) `
        -Status $status -Error $error
}

function Get-CdpExecExplicitItems {
    param([string[]]$Names, [object[]]$Projects)

    $items = @()
    foreach ($name in $Names) {
        $matches = @($Projects | Where-Object {
            [string]::Equals([string]$_.name, $name, [StringComparison]::Ordinal)
        })
        if ($matches.Count -eq 0) { throw "Exec project '$name' not found." }
        if ($matches.Count -gt 1) { throw "Exec project '$name' is ambiguous." }
        $items += ConvertTo-CdpExecProjectPlanItem -Project $matches[0]
    }
    $items
}

function Get-CdpExecTagItems {
    param([string]$Tag, [object[]]$Projects)

    $comparison = [StringComparison]::OrdinalIgnoreCase
    $matches = @($Projects | Where-Object {
        $_.enabled -eq $true -and
        @(Get-CdpProjectStringList -Project $_ -PropertyName 'tags' | Where-Object {
            [string]::Equals([string]$_, $Tag, $comparison)
        }).Count -gt 0
    })
    if ($matches.Count -eq 0) { throw "Exec tag '@$Tag' matched no enabled projects." }
    @($matches | ForEach-Object { ConvertTo-CdpExecProjectPlanItem -Project $_ })
}

function Get-CdpExecAllItems {
    param([object[]]$Projects)

    $matches = @($Projects | Where-Object { $_.enabled -eq $true })
    if ($matches.Count -eq 0) { throw 'Exec --all matched no enabled projects.' }
    @($matches | ForEach-Object { ConvertTo-CdpExecProjectPlanItem -Project $_ })
}

function ConvertTo-CdpExecWorkspaceReference {
    param([AllowNull()][object]$Reference)

    if ($Reference -is [string] -or -not (Test-CdpWorkspaceObject $Reference)) { return $Reference }
    [PSCustomObject]@{
        name = Get-CdpWorkspaceReferenceValue -Reference $Reference -Name 'name'
        rootPath = Get-CdpWorkspaceReferenceValue -Reference $Reference -Name 'rootPath'
    }
}

function ConvertTo-CdpExecWorkspaceItem {
    param([Parameter(Mandatory = $true)][object]$Resolution)

    $statusMap = @{
        'ok'='planned'; 'legacy'='planned'; 'renamed'='planned'
        'missing-project'='missing_project'; 'ambiguous-project'='ambiguous_project'
        'disabled-project'='disabled_project'; 'invalid-path-profile'='path_profile_invalid'
        'missing-path'='path_missing'; 'invalid-reference'='missing_project'
    }
    $status = $statusMap[[string]$Resolution.Status]
    if (-not $status) { $status = 'missing_project' }
    $error = if ($status -eq 'planned') { '' } else { "Workspace reference status: $($Resolution.Status)." }
    New-CdpExecPlanItem -Project $Resolution.Project -Name ([string]$Resolution.Name) `
        -RawPath ([string]$Resolution.RawPath) -ResolvedPath ([string]$Resolution.ResolvedPath) `
        -Status $status -Error $error
}

function Get-CdpExecWorkspaceItems {
    param([string]$Name, [string]$ConfigPath, [object[]]$Projects)

    $workspacePath = Get-CdpWorkspacesPath -ConfigPath $ConfigPath
    $workspaces = @((Read-CdpWorkspaceDocument -Path $workspacePath).Value)
    $matches = @($workspaces | Where-Object {
        [string]::Equals([string]$_.name, $Name, [StringComparison]::Ordinal)
    })
    if ($matches.Count -eq 0) { throw "Workspace '$Name' not found." }
    if ($matches.Count -gt 1) { throw "Workspace '$Name' is ambiguous." }
    $referenceValue = $matches[0].projects
    if (-not ($referenceValue -is [System.Array])) {
        throw "Workspace '$Name' projects must be a JSON array."
    }
    $references = @($referenceValue)
    if ($references.Count -eq 0) { throw "Workspace '$Name' does not contain projects." }
    foreach ($reference in $references) {
        $stableReference = ConvertTo-CdpExecWorkspaceReference -Reference $reference
        $resolution = Resolve-CdpWorkspaceReference -Reference $stableReference -Projects $Projects -WorkspaceOpen ''
        ConvertTo-CdpExecWorkspaceItem -Resolution $resolution
    }
}

function Assert-CdpExecProjectConfigArray {
    param([Parameter(Mandatory = $true)][string]$Path)

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop
    if (-not $content.TrimStart().StartsWith('[')) {
        throw 'Project configuration must be a JSON array.'
    }
}

function Select-CdpUniqueExecItems {
    param([object[]]$Items)

    $identities = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($item in $Items) {
        if ([string]::IsNullOrEmpty([string]$item.RawPath) -or $identities.Add([string]$item.RawPath)) {
            $item
        }
    }
}

function Resolve-CdpExecExecutable {
    param([Parameter(Mandatory = $true)][string]$Command)

    $resolved = @(Get-Command -Name $Command -CommandType Application -ErrorAction SilentlyContinue)
    if ($resolved.Count -eq 0) { throw "Exec command '$Command' was not found as a native executable." }
    $path = [string]$resolved[0].Path
    if ([string]::IsNullOrWhiteSpace($path)) { $path = [string]$resolved[0].Source }
    if ([string]::IsNullOrWhiteSpace($path)) { throw "Exec command '$Command' has no executable path." }
    $path
}

function Get-CdpExecSelectorDocument {
    param([Parameter(Mandatory = $true)][object]$Invocation)

    $value = switch ($Invocation.ExecSelectorKind) {
        'projects' { @($Invocation.ExecProjectNames) }
        'tag' { [string]$Invocation.ExecTag }
        'workspace' { [string]$Invocation.ExecWorkspace }
        'all' { $null }
    }
    [PSCustomObject]@{ kind = [string]$Invocation.ExecSelectorKind; value = $value }
}

function New-CdpExecPlan {
    param([Parameter(Mandatory = $true)][object]$Invocation)

    $configPath = $Invocation.ConfigPath
    if ([string]::IsNullOrWhiteSpace($configPath)) { $configPath = Get-DefaultConfigPath }
    $config = Get-CdpProjectConfig -ConfigPath $configPath
    Assert-CdpExecProjectConfigArray -Path $config.Path
    $projects = @($config.Projects)
    $items = switch ($Invocation.ExecSelectorKind) {
        'projects' { @(Get-CdpExecExplicitItems -Names @($Invocation.ExecProjectNames) -Projects $projects) }
        'tag' { @(Get-CdpExecTagItems -Tag $Invocation.ExecTag -Projects $projects) }
        'workspace' { @(Get-CdpExecWorkspaceItems -Name $Invocation.ExecWorkspace -ConfigPath $config.Path -Projects $projects) }
        'all' { @(Get-CdpExecAllItems -Projects $projects) }
        default { throw 'Exec selector is invalid.' }
    }
    $jobsDefault = [Math]::Max(1, [Math]::Min(4, [Environment]::ProcessorCount))
    $jobs = if ($Invocation.ThrottleLimit -gt 0) { $Invocation.ThrottleLimit } else {
        Get-CdpStatusIntegerSetting -Name 'CDP_EXEC_CONCURRENCY' -Default $jobsDefault -Minimum 1 -Maximum 16
    }
    $timeout = if ($Invocation.TimeoutSeconds -gt 0) { $Invocation.TimeoutSeconds } else {
        Get-CdpStatusIntegerSetting -Name 'CDP_EXEC_TIMEOUT_SECONDS' -Default 300 -Minimum 1 -Maximum 3600
    }
    [PSCustomObject]@{
        ConfigPath = $config.Path
        Selector = Get-CdpExecSelectorDocument -Invocation $Invocation
        Command = [string]$Invocation.ExecCommand
        Executable = Resolve-CdpExecExecutable -Command $Invocation.ExecCommand
        Arguments = @($Invocation.ExecArguments)
        Jobs = [int]$jobs
        TimeoutSeconds = [int]$timeout
        FailFast = [bool]$Invocation.FailFast
        DryRun = [bool]$Invocation.DryRun
        Items = @(Select-CdpUniqueExecItems -Items @($items))
    }
}
