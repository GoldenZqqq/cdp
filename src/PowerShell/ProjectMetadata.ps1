# cdp PowerShell domain: ProjectMetadata.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

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

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
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

    try {
        $document = Read-CdpJsonArrayMutationDocument -LiteralPath $ConfigPath
        $projects = @($document.Value)
        $targetProjects = if ([string]::IsNullOrWhiteSpace($Name)) {
            $currentPath = Get-CdpComparablePath -Path (Get-Location).Path
            @($projects | Where-Object {
                $resolution = Resolve-CdpProjectPath -Project $_
                -not $resolution.ErrorCode -and
                    (Get-CdpComparablePath -Path $resolution.ResolvedPath) -eq $currentPath
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
        $stateText = if ($Pinned) { "Pin" } else { "Unpin" }
        $currentPinned = $target.PSObject.Properties['pinned'] -and [bool]$target.pinned
        if ($currentPinned -eq $Pinned) {
            Write-Host "Project already has the requested pin state: $($target.name)" -ForegroundColor Yellow
            if ($PassThru) {
                return New-CdpActionResult -Action ($stateText.ToLowerInvariant()) -Target ([string]$target.name) -Status 'skipped' -Changed $false -Details $target
            }
            return
        }
        if (-not $PSCmdlet.ShouldProcess([string]$target.name, "$stateText project in $ConfigPath")) {
            if ($PassThru) {
                $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
                return New-CdpActionResult -Action ($stateText.ToLowerInvariant()) -Target ([string]$target.name) -Status $status -Changed $false -Details $target
            }
            return
        }

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

        [void](Write-CdpJsonFile -LiteralPath $ConfigPath -Value @($projects) -ExpectedFingerprint $document.Fingerprint)

        $completedText = if ($Pinned) { "Pinned" } else { "Unpinned" }
        Write-Host "$completedText project: $($target.name)" -ForegroundColor Green

        if ($PassThru) {
            $updatedProject = ($projects | Where-Object {
                [string]::Equals([string]$_.name, [string]$target.name, [StringComparison]::OrdinalIgnoreCase) -and
                [string]::Equals([string]$_.rootPath, [string]$target.rootPath, [StringComparison]::OrdinalIgnoreCase)
            } | Select-Object -First 1)
            return New-CdpActionResult -Action ($stateText.ToLowerInvariant()) -Target ([string]$target.name) -Status 'succeeded' -Changed $true -Details $updatedProject
        }
    } catch {
        Write-Host "Error: Failed to update project pin." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
        if ($PassThru) {
            $action = if ($Pinned) { 'pin' } else { 'unpin' }
            return New-CdpActionResult -Action $action -Target ([string]$Name) -Status 'failed' -Changed $false -Error $_.Exception.Message
        }
    }
}

function Clear-ProjectPin {
    <#
    .SYNOPSIS
        Remove the pinned state from a cdp project.

    .DESCRIPTION
        Convenience wrapper for Set-ProjectPin -Pinned false.
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    $parameters = @{
        Name = $Name
        ConfigPath = $ConfigPath
        Pinned = $false
        PassThru = $PassThru
    }
    if ($WhatIfPreference) { $parameters.WhatIf = $true }
    if ($PSBoundParameters.ContainsKey('Confirm')) { $parameters.Confirm = $PSBoundParameters['Confirm'] }
    Set-ProjectPin @parameters
}

function Update-CdpProjectStringList {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
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

    try {
        $document = Read-CdpJsonArrayMutationDocument -LiteralPath $ConfigPath
        $projects = @($document.Value)
        $targets = @(Get-CdpProjectMatches -Projects $projects -Query $Name)

        if ($targets.Count -ne 1) {
            Write-Host "Expected one project match, found $($targets.Count)." -ForegroundColor Yellow
            return
        }

        $target = $targets[0]
        $currentValues = @(Get-CdpProjectStringList -Project $target -PropertyName $PropertyName)
        $containsValue = @($currentValues | Where-Object {
            [string]::Equals($_, $Value, [StringComparison]::OrdinalIgnoreCase)
        }).Count -gt 0
        $willChange = if ($Remove) { $containsValue } else { -not $containsValue }
        $metadataKind = if ($PropertyName -eq 'aliases') { 'alias' } else { 'tag' }
        $actionName = if ($Remove) { "remove-$metadataKind" } else { "add-$metadataKind" }
        if (-not $willChange) {
            Write-Host "Project metadata already has the requested state." -ForegroundColor Yellow
            if ($PassThru) {
                return New-CdpActionResult -Action $actionName -Target ([string]$target.name) -Status 'skipped' -Changed $false -Details $target
            }
            return
        }
        $operation = if ($Remove) { "Remove $metadataKind '$Value'" } else { "Add $metadataKind '$Value'" }
        if (-not $PSCmdlet.ShouldProcess([string]$target.name, "$operation in $ConfigPath")) {
            if ($PassThru) {
                $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
                return New-CdpActionResult -Action $actionName -Target ([string]$target.name) -Status $status -Changed $false -Details $target
            }
            return
        }

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

        [void](Write-CdpJsonFile -LiteralPath $ConfigPath -Value @($projects) -ExpectedFingerprint $document.Fingerprint)

        $action = if ($Remove) { "Removed" } else { "Added" }
        Write-Host "$action $PropertyName '$Value' for project: $($target.name)" -ForegroundColor Green

        if ($PassThru) {
            $updatedProject = ($projects | Where-Object {
                [string]::Equals([string]$_.name, [string]$target.name, [StringComparison]::OrdinalIgnoreCase) -and
                [string]::Equals([string]$_.rootPath, [string]$target.rootPath, [StringComparison]::OrdinalIgnoreCase)
            } | Select-Object -First 1)
            return New-CdpActionResult -Action $actionName -Target ([string]$target.name) -Status 'succeeded' -Changed $true -Details $updatedProject
        }
    } catch {
        Write-Host "Error: Failed to update project metadata." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
        if ($PassThru) {
            $metadataKind = if ($PropertyName -eq 'aliases') { 'alias' } else { 'tag' }
            $actionName = if ($Remove) { "remove-$metadataKind" } else { "add-$metadataKind" }
            return New-CdpActionResult -Action $actionName -Target ([string]$Name) -Status 'failed' -Changed $false -Error $_.Exception.Message
        }
    }
}

function Add-ProjectAlias {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param([string]$Name, [string]$Alias, [string]$ConfigPath, [switch]$PassThru)
    $parameters = @{ Name = $Name; Value = $Alias; PropertyName = 'aliases'; ConfigPath = $ConfigPath; PassThru = $PassThru }
    if ($WhatIfPreference) { $parameters.WhatIf = $true }
    if ($PSBoundParameters.ContainsKey('Confirm')) { $parameters.Confirm = $PSBoundParameters['Confirm'] }
    Update-CdpProjectStringList @parameters
}

function Remove-ProjectAlias {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param([string]$Name, [string]$Alias, [string]$ConfigPath, [switch]$PassThru)
    $parameters = @{ Name = $Name; Value = $Alias; PropertyName = 'aliases'; ConfigPath = $ConfigPath; Remove = $true; PassThru = $PassThru }
    if ($WhatIfPreference) { $parameters.WhatIf = $true }
    if ($PSBoundParameters.ContainsKey('Confirm')) { $parameters.Confirm = $PSBoundParameters['Confirm'] }
    Update-CdpProjectStringList @parameters
}

function Add-ProjectTag {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param([string]$Name, [string]$Tag, [string]$ConfigPath, [switch]$PassThru)
    $parameters = @{ Name = $Name; Value = $Tag; PropertyName = 'tags'; ConfigPath = $ConfigPath; PassThru = $PassThru }
    if ($WhatIfPreference) { $parameters.WhatIf = $true }
    if ($PSBoundParameters.ContainsKey('Confirm')) { $parameters.Confirm = $PSBoundParameters['Confirm'] }
    Update-CdpProjectStringList @parameters
}

function Remove-ProjectTag {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param([string]$Name, [string]$Tag, [string]$ConfigPath, [switch]$PassThru)
    $parameters = @{ Name = $Name; Value = $Tag; PropertyName = 'tags'; ConfigPath = $ConfigPath; Remove = $true; PassThru = $PassThru }
    if ($WhatIfPreference) { $parameters.WhatIf = $true }
    if ($PSBoundParameters.ContainsKey('Confirm')) { $parameters.Confirm = $PSBoundParameters['Confirm'] }
    Update-CdpProjectStringList @parameters
}
