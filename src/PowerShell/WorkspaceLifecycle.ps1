# cdp PowerShell domain: WorkspaceLifecycle.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function ConvertTo-CdpWorkspaceLayout {
    param([string]$Value, [object]$Existing)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ($Existing) { return $Existing }
        return [PSCustomObject]@{ mode = 'tabs' }
    }
    switch ($Value.ToLowerInvariant()) {
        'tabs' { return [PSCustomObject]@{ mode = 'tabs' } }
        'split-horizontal' { return [PSCustomObject]@{ mode = 'split'; direction = 'horizontal' } }
        'split-vertical' { return [PSCustomObject]@{ mode = 'split'; direction = 'vertical' } }
        default { throw 'Workspace layout must be tabs, split-horizontal, or split-vertical.' }
    }
}

function Test-CdpWorkspaceLayout {
    param([object]$Layout)

    if ($null -eq $Layout) { return $true }
    if (-not ($Layout -is [PSCustomObject] -or $Layout -is [System.Collections.IDictionary])) { return $false }
    $mode = [string]$Layout.mode
    if ($mode -eq 'tabs') { return $true }
    $mode -eq 'split' -and [string]$Layout.direction -in @('horizontal', 'vertical')
}

function Test-CdpWorkspaceObject {
    param([object]$Value)

    $null -ne $Value -and
        ($Value -is [PSCustomObject] -or $Value -is [System.Collections.IDictionary])
}

function Test-CdpWorkspaceSize {
    param([object]$Value)

    $integerTypes = @(
        [byte], [sbyte], [short], [ushort], [int], [uint], [long], [ulong]
    )
    $isInteger = $false
    foreach ($integerType in $integerTypes) {
        if ($Value -is $integerType) { $isInteger = $true; break }
    }
    if (-not $isInteger) { return $false }
    [decimal]$Value -ge 10 -and [decimal]$Value -le 90
}

function New-CdpWorkspaceProjectReference {
    param([Parameter(Mandatory = $true)][object]$Project)

    [PSCustomObject][ordered]@{
        name = [string]$Project.name
        rootPath = [string]$Project.rootPath
    }
}

function Get-CdpWorkspaceProjectReferences {
    param([string[]]$Names, [object[]]$Projects)

    $references = @()
    foreach ($name in $Names) {
        $projectMatches = @($Projects | Where-Object {
            $_.enabled -eq $true -and [string]::Equals([string]$_.name, $name, [StringComparison]::Ordinal)
        })
        if ($projectMatches.Count -ne 1) { throw "Workspace project '$name' must match one enabled project." }
        $references += New-CdpWorkspaceProjectReference -Project $projectMatches[0]
    }
    $references
}

function Get-CdpWorkspaceReferenceValue {
    param([object]$Reference, [string]$Name)

    if ($Reference -is [string] -or $null -eq $Reference) { return $null }
    if ($Reference -is [System.Collections.IDictionary] -and $Reference.Contains($Name)) {
        return $Reference[$Name]
    }
    $property = $Reference.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    $null
}

function Set-CdpWorkspaceReferenceValue {
    param([object]$Reference, [string]$Name, [object]$Value)

    if ($Reference -is [System.Collections.IDictionary]) {
        $Reference[$Name] = $Value
        return
    }
    if ($Reference.PSObject.Properties[$Name]) { $Reference.$Name = $Value }
    else { $Reference | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Get-CdpWorkspaceReferenceSchemaStatus {
    param([object]$Reference)

    if ($Reference -is [string]) {
        if ([string]::IsNullOrWhiteSpace([string]$Reference)) { return 'invalid-reference' }
        return 'ok'
    }
    if (-not (Test-CdpWorkspaceObject $Reference)) { return 'invalid-reference' }
    $name = [string](Get-CdpWorkspaceReferenceValue $Reference 'name')
    $rootPath = [string](Get-CdpWorkspaceReferenceValue $Reference 'rootPath')
    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($rootPath)) {
        return 'invalid-reference'
    }
    $sizeProperty = $Reference.PSObject.Properties['size']
    if ($Reference -is [System.Collections.IDictionary]) { $sizeProperty = $Reference.Contains('size') }
    if ($sizeProperty -and -not (Test-CdpWorkspaceSize (Get-CdpWorkspaceReferenceValue $Reference 'size'))) {
        return 'invalid-size'
    }
    $open = Get-CdpWorkspaceReferenceValue $Reference 'open'
    if ($null -ne $open) {
        if ([string]::IsNullOrWhiteSpace([string]$open)) { return 'invalid-launcher' }
        try { [void](Get-CdpWorkspaceLauncher -Open ([string]$open)) }
        catch { return 'invalid-launcher' }
    }
    'ok'
}

function Resolve-CdpWorkspaceReference {
    param([object]$Reference, [object[]]$Projects, [string]$WorkspaceOpen)

    $schemaStatus = Get-CdpWorkspaceReferenceSchemaStatus -Reference $Reference
    $legacy = $Reference -is [string]
    $configuredName = if ($legacy) { [string]$Reference } else { [string](Get-CdpWorkspaceReferenceValue $Reference 'name') }
    $rawPath = if ($legacy) { '' } else { [string](Get-CdpWorkspaceReferenceValue $Reference 'rootPath') }
    $projectMatches = if ($legacy) {
        @($Projects | Where-Object { [string]::Equals([string]$_.name, $configuredName, [StringComparison]::Ordinal) })
    } else {
        @($Projects | Where-Object { [string]::Equals([string]$_.rootPath, $rawPath, [StringComparison]::Ordinal) })
    }
    $status = if ($schemaStatus -ne 'ok') { $schemaStatus } elseif ($projectMatches.Count -eq 0) { 'missing-project' } elseif ($projectMatches.Count -gt 1) { 'ambiguous-project' } else { 'ok' }
    $project = if ($projectMatches.Count -eq 1) { $projectMatches[0] } else { $null }
    if ($schemaStatus -eq 'ok' -and $project -and $project.enabled -ne $true) { $status = 'disabled-project' }
    if ($schemaStatus -eq 'ok' -and $project -and $legacy) { $status = 'legacy' }
    if ($schemaStatus -eq 'ok' -and $project -and -not $legacy -and -not [string]::Equals([string]$project.name, $configuredName, [StringComparison]::Ordinal)) { $status = 'renamed' }
    New-CdpWorkspaceResolvedReference -Reference $Reference -Project $project -Status $status -WorkspaceOpen $WorkspaceOpen
}

function New-CdpWorkspaceResolvedReference {
    param([object]$Reference, [object]$Project, [string]$Status, [string]$WorkspaceOpen)

    $legacy = $Reference -is [string]
    $configuredName = if ($legacy) { [string]$Reference } else { [string](Get-CdpWorkspaceReferenceValue $Reference 'name') }
    $rawPath = if ($legacy) { if ($Project) { [string]$Project.rootPath } else { '' } } else { [string](Get-CdpWorkspaceReferenceValue $Reference 'rootPath') }
    $resolution = if ($Project) { Resolve-CdpProjectPath -Project $Project } else { $null }
    $canReplaceStatus = $Status -in @('ok', 'legacy', 'renamed')
    if ($canReplaceStatus -and $resolution -and $resolution.ErrorCode) { $Status = 'invalid-path-profile' }
    elseif ($canReplaceStatus -and $resolution -and -not (Test-Path -LiteralPath $resolution.ResolvedPath)) { $Status = 'missing-path' }
    $projectOpen = [string](Get-CdpWorkspaceReferenceValue $Reference 'open')
    $launcherName = if ($projectOpen) { $projectOpen } else { $WorkspaceOpen }
    try { if ($launcherName) { [void](Get-CdpWorkspaceLauncher -Open $launcherName) } }
    catch { if ($Status -in @('ok', 'legacy', 'renamed')) { $Status = 'invalid-launcher' } }
    [PSCustomObject]@{ IsProjectReference=$true; Reference=$Reference; ConfiguredName=$configuredName; Name=if($Project){[string]$Project.name}else{$configuredName}; RawPath=$rawPath; ResolvedPath=if($resolution){$resolution.ResolvedPath}else{''}; Project=$Project; Status=$Status; Launcher=$launcherName; Size=Get-CdpWorkspaceReferenceValue $Reference 'size' }
}

function Get-CdpWorkspaceValidation {
    param([object]$Workspace, [object[]]$Projects)

    $results = @()
    if (-not (Test-CdpWorkspaceObject $Workspace) -or [string]::IsNullOrWhiteSpace([string]$Workspace.name)) {
        return ,([PSCustomObject]@{ Name=''; Status='invalid-workspace'; RawPath=''; ResolvedPath=''; Reference=$null; Project=$null })
    }
    if (-not (Test-CdpWorkspaceLayout -Layout $Workspace.layout)) {
        $results += [PSCustomObject]@{ Name=[string]$Workspace.name; Status='invalid-layout'; RawPath=''; ResolvedPath=''; Reference=$null; Project=$null }
    }
    try { if ($Workspace.open) { [void](Get-CdpWorkspaceLauncher -Open ([string]$Workspace.open)) } } catch {
        $results += [PSCustomObject]@{ Name=[string]$Workspace.name; Status='invalid-launcher'; RawPath=''; ResolvedPath=''; Reference=$null; Project=$null }
    }
    $references = @($Workspace.projects)
    if ($references.Count -eq 0) {
        $results += [PSCustomObject]@{ Name=[string]$Workspace.name; Status='invalid-reference'; RawPath=''; ResolvedPath=''; Reference=$null; Project=$null }
    }
    foreach ($reference in $references) {
        $results += Resolve-CdpWorkspaceReference -Reference $reference -Projects $Projects -WorkspaceOpen ([string]$Workspace.open)
    }
    $results
}

function Convert-CdpWorkspaceReferences {
    param([object]$Workspace, [object[]]$Validation)

    $updated = @()
    $changed = $false
    foreach ($result in $Validation) {
        if (-not $result.IsProjectReference) { continue }
        if ($result.Project -and $result.Reference -is [string]) {
            $reference = New-CdpWorkspaceProjectReference -Project $result.Project
            $updated += $reference
            $changed = $true
        } elseif ($result.Project -and -not [string]::Equals([string]$result.Project.name, [string](Get-CdpWorkspaceReferenceValue $result.Reference 'name'), [StringComparison]::Ordinal)) {
            Set-CdpWorkspaceReferenceValue -Reference $result.Reference -Name name -Value ([string]$result.Project.name)
            $updated += $result.Reference
            $changed = $true
        } else { $updated += $result.Reference }
    }
    $Workspace.projects = @($updated)
    [PSCustomObject]@{ Workspace=$Workspace; Changed=$changed }
}

function Get-CdpWorkspaceByName {
    param([object[]]$Workspaces, [string]$Name)

    @($Workspaces | Where-Object {
        [string]::Equals([string]$_.name, $Name, [StringComparison]::Ordinal)
    } | Select-Object -First 1)
}

function Read-CdpWorkspaceDocument {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if (-not $content.TrimStart().StartsWith('[')) { throw 'Workspace configuration must be a JSON array.' }
        $document = Read-CdpJsonDocument -LiteralPath $Path
        return $document
    }
    [PSCustomObject]@{ Value = @(); Fingerprint = 'missing' }
}

function Get-CdpWorkspaceConfigContext {
    param([string]$ConfigPath)

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) { $ConfigPath = Get-DefaultConfigPath }
    [PSCustomObject]@{
        ConfigPath = $ConfigPath
        Data = Get-CdpProjectConfig -ConfigPath $ConfigPath
    }
}

function Get-CdpWorkspaceLayoutLabel {
    param([object]$Layout)

    $normalized = ConvertTo-CdpWorkspaceLayout -Existing $Layout
    if (-not (Test-CdpWorkspaceLayout -Layout $normalized)) { return 'invalid' }
    if ($normalized.mode -eq 'split') { return "split-$($normalized.direction)" }
    'tabs'
}

function Show-CdpWorkspaceList {
    param([object[]]$Workspaces)

    if ($Workspaces.Count -eq 0) {
        Write-Host 'No workspaces defined.' -ForegroundColor Yellow
        Write-Host 'Create one: cdp workspace add <name> <project1> <project2> ...' -ForegroundColor Gray
        return
    }
    Write-Host "`ncdp workspaces" -ForegroundColor Cyan
    Write-Host ('-' * 60)
    foreach ($workspace in $Workspaces) {
        $names = @($workspace.projects | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.name } })
        $openLabel = if ($workspace.open) { " [$($workspace.open)]" } else { '' }
        Write-Host "  $($workspace.name)" -ForegroundColor Green -NoNewline
        Write-Host $openLabel -ForegroundColor Cyan -NoNewline
        Write-Host " -> $($names -join ', ')" -ForegroundColor Gray
    }
    Write-Host ('-' * 60)
}

function Show-CdpWorkspaceDetail {
    param([object]$Workspace, [object[]]$Projects, [switch]$PassThru)

    $validation = @(Get-CdpWorkspaceValidation -Workspace $Workspace -Projects $Projects)
    $layoutLabel = Get-CdpWorkspaceLayoutLabel -Layout $Workspace.layout
    Write-Host "`nworkspace: $($Workspace.name)" -ForegroundColor Cyan
    Write-Host "layout: $layoutLabel" -ForegroundColor Gray
    foreach ($item in $validation) {
        $launcher = if ($item.Launcher) { $item.Launcher } else { '-' }
        Write-Host "  $($item.Name) [$($item.Status)] raw=$($item.RawPath) resolved=$($item.ResolvedPath) launcher=$launcher" -ForegroundColor Gray
    }
    if ($PassThru) {
        [PSCustomObject]@{
            name = [string]$Workspace.name
            open = [string]$Workspace.open
            layout = $layoutLabel
            workspace = $Workspace
            projects = $validation
        }
    }
}

function New-CdpWorkspaceDefinition {
    param([string]$Name, [string[]]$ProjectNames, [object[]]$Projects, [string]$Open, [string]$Layout)

    if ([string]::IsNullOrWhiteSpace($Name) -or $ProjectNames.Count -eq 0) {
        throw 'Workspace add requires a name and at least one project.'
    }
    if ($Open) { [void](Get-CdpWorkspaceLauncher -Open $Open) }
    $workspace = [PSCustomObject][ordered]@{
        name = $Name
        projects = @(Get-CdpWorkspaceProjectReferences -Names $ProjectNames -Projects $Projects)
    }
    if ($Open) { $workspace | Add-Member -NotePropertyName open -NotePropertyValue $Open }
    if ($Layout) { $workspace | Add-Member -NotePropertyName layout -NotePropertyValue (ConvertTo-CdpWorkspaceLayout $Layout) }
    $workspace
}

function Update-CdpWorkspaceDefinition {
    param([object]$Workspace, [string[]]$ProjectNames, [object[]]$Projects, [string]$Open, [string]$Layout, [switch]$ClearOpen)

    $before = ConvertTo-Json -InputObject $Workspace -Depth 100 -Compress
    if ($ProjectNames.Count -gt 0) {
        $Workspace.projects = @(Get-CdpWorkspaceProjectReferences -Names $ProjectNames -Projects $Projects)
    }
    if ($ClearOpen -and $Workspace.PSObject.Properties['open']) { $Workspace.PSObject.Properties.Remove('open') }
    elseif ($Open) {
        [void](Get-CdpWorkspaceLauncher -Open $Open)
        Set-CdpWorkspaceReferenceValue -Reference $Workspace -Name open -Value $Open
    }
    if ($Layout) {
        Set-CdpWorkspaceReferenceValue -Reference $Workspace -Name layout -Value (ConvertTo-CdpWorkspaceLayout $Layout)
    }
    $after = ConvertTo-Json -InputObject $Workspace -Depth 100 -Compress
    [PSCustomObject]@{ Workspace=$Workspace; Changed=($before -ne $after) }
}

function Write-CdpWorkspaceValidation {
    param([object[]]$Results)

    foreach ($item in $Results) {
        $color = if ($item.Status -in @('ok', 'legacy', 'renamed')) { 'Yellow' } else { 'Red' }
        Write-Host "  $($item.Name): $($item.Status)" -ForegroundColor $color
    }
}

function New-CdpWorkspaceLaunchPlan {
    param([object]$Workspace, [object[]]$Projects, [string]$OpenOverride)

    $overrideLauncher = $null
    if ($OpenOverride) { $overrideLauncher = Get-CdpWorkspaceLauncher -Open $OpenOverride }
    $validation = @(Get-CdpWorkspaceValidation -Workspace $Workspace -Projects $Projects)
    foreach ($item in $validation) {
        $launcherName = if ($OpenOverride) { $OpenOverride } else { [string]$item.Launcher }
        $launcher = if ($OpenOverride) { $overrideLauncher } else { $null }
        if (-not $OpenOverride -and $launcherName) { try { $launcher = Get-CdpWorkspaceLauncher -Open $launcherName } catch { $item.Status = 'invalid-launcher' } }
        [PSCustomObject]@{
            Name = $item.Name
            RawPath = $item.RawPath
            ResolvedPath = $item.ResolvedPath
            Project = $item.Project
            Status = $item.Status
            Launcher = $launcher
            Size = $item.Size
        }
    }
}

function New-CdpLegacyWorkspaceLaunchPlan {
    param([object[]]$Projects, [string[]]$ProjectNames, [object]$Launcher)

    foreach ($name in $ProjectNames) {
        $projectMatches = @($Projects | Where-Object {
            [string]::Equals([string]$_.name, $name, [StringComparison]::Ordinal)
        })
        if ($projectMatches.Count -ne 1) {
            [PSCustomObject]@{ Name=$name; Status='missing-project'; ResolvedPath=''; Launcher=$Launcher }
            continue
        }
        $resolution = Resolve-CdpProjectPath -Project $projectMatches[0]
        $status = if ($resolution.ErrorCode) { 'invalid-path-profile' } elseif (Test-Path -LiteralPath $resolution.ResolvedPath) { 'ok' } else { 'missing-path' }
        [PSCustomObject]@{ Name=$name; Project=$projectMatches[0]; RawPath=[string]$projectMatches[0].rootPath; ResolvedPath=$resolution.ResolvedPath; Status=$status; Launcher=$Launcher; Size=$null }
    }
}

function New-CdpWindowsTerminalLaunchPlan {
    param([object[]]$Plan, [object]$Layout)

    foreach ($item in $Plan) {
        $launchable = $item.Status -in @('ok', 'legacy', 'renamed')
        [PSCustomObject]@{
            Item = $item
            FirstArguments = if ($launchable) { @(Get-CdpWindowsTerminalWorkspaceArguments -Item $item -Layout $Layout -First $true) } else { @() }
            NextArguments = if ($launchable) { @(Get-CdpWindowsTerminalWorkspaceArguments -Item $item -Layout $Layout -First $false) } else { @() }
        }
    }
}

function Get-CdpWindowsTerminalWorkspaceArguments {
    param([object]$Item, [object]$Layout, [bool]$First)

    $arguments = @('-w', '0')
    if ($Layout.mode -eq 'split' -and -not $First) {
        $arguments += 'split-pane'
        $arguments += if ($Layout.direction -eq 'vertical') { '-V' } else { '-H' }
        if ($Item.Size) { $arguments += @('-s', ([double]$Item.Size / 100).ToString('0.##', [Globalization.CultureInfo]::InvariantCulture)) }
    } else { $arguments += 'new-tab' }
    $arguments += @('-d', $Item.ResolvedPath, '--title', $Item.Name)
    if ($Item.Launcher) { $arguments += @('--', $Item.Launcher.Command) + @($Item.Launcher.Arguments) }
    $arguments
}
