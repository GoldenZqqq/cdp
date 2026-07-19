# cdp PowerShell domain: Hooks.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function Get-CdpStringFingerprint {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)

    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        $hash = $algorithm.ComputeHash($bytes)
        ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

function Get-CdpHookTrustPath {
    if (-not [string]::IsNullOrWhiteSpace($env:CDP_HOOK_TRUST_PATH)) {
        return [Environment]::ExpandEnvironmentVariables($env:CDP_HOOK_TRUST_PATH)
    }
    Join-Path (Get-CdpUserHome) '.cdp\hook-trust.json'
}

function Get-CdpNormalizedConfigPath {
    param([Parameter(Mandatory = $true)][string]$ConfigPath)

    $fullPath = [System.IO.Path]::GetFullPath($ConfigPath)
    if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
        return $fullPath.ToLowerInvariant()
    }
    $fullPath
}

function Get-CdpHookDescriptor {
    param([Parameter(Mandatory = $true)][object]$Project)

    if (-not $Project.PSObject.Properties['onEnter'] -or $null -eq $Project.onEnter) { return $null }
    $onEnter = $Project.onEnter
    $command = if ($onEnter -is [string]) {
        [string]$onEnter
    } elseif ($onEnter.PSObject.Properties['powershell']) {
        [string]$onEnter.powershell
    } else {
        ''
    }
    if ([string]::IsNullOrWhiteSpace($command)) { return $null }
    [PSCustomObject]@{ Kind = 'powershell'; Command = $command }
}

function Get-CdpHookIdentity {
    param(
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][object]$Project
    )

    $descriptor = Get-CdpHookDescriptor -Project $Project
    if (-not $descriptor) { return $null }
    $nameHash = Get-CdpStringFingerprint -Value ([string]$Project.name)
    $rootHash = Get-CdpStringFingerprint -Value ([string]$Project.rootPath)
    $commandHash = Get-CdpStringFingerprint -Value $descriptor.Command
    $configContentHash = Get-CdpFileFingerprint -LiteralPath $ConfigPath
    [PSCustomObject]@{
        ConfigFingerprint = Get-CdpStringFingerprint -Value (Get-CdpNormalizedConfigPath $ConfigPath)
        ProjectFingerprint = Get-CdpStringFingerprint -Value "name=$nameHash;root=$rootHash"
        HookFingerprint = Get-CdpStringFingerprint -Value "config=$configContentHash;kind=$($descriptor.Kind);command=$commandHash"
        Kind = $descriptor.Kind
    }
}

function Protect-CdpHookTrustStore {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    if ([System.IO.Path]::DirectorySeparatorChar -ne '\') {
        & chmod 600 $LiteralPath
        if ($LASTEXITCODE -ne 0) { throw "Unable to secure the cdp hook trust store." }
        return
    }
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl = New-Object System.Security.AccessControl.FileSecurity
    $acl.SetOwner($identity)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, 'FullControl', 'Allow')
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $LiteralPath -AclObject $acl
}

function Read-CdpHookTrustStore {
    $path = Get-CdpHookTrustPath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return [PSCustomObject]@{
            Path = $path
            Fingerprint = 'missing'
            Value = [PSCustomObject]@{ version = 1; entries = @() }
        }
    }
    Protect-CdpHookTrustStore -LiteralPath $path
    $document = Read-CdpJsonDocument -LiteralPath $path
    $value = $document.Value
    if ($null -eq $value -or $value.version -ne 1 -or -not $value.PSObject.Properties['entries']) {
        throw "Invalid cdp hook trust store."
    }
    $value.entries = @($value.entries)
    [PSCustomObject]@{ Path = $path; Fingerprint = $document.Fingerprint; Value = $value }
}

function Save-CdpHookTrustStore {
    param([Parameter(Mandatory = $true)][object]$Document)

    [void](Write-CdpJsonFile `
        -LiteralPath $Document.Path `
        -Value $Document.Value `
        -ExpectedFingerprint $Document.Fingerprint)
    Protect-CdpHookTrustStore -LiteralPath $Document.Path
}

function Test-CdpHookTrusted {
    param(
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][object]$Project
    )

    $identity = Get-CdpHookIdentity -ConfigPath $ConfigPath -Project $Project
    if (-not $identity) { return $false }
    $store = Read-CdpHookTrustStore
    @($store.Value.entries | Where-Object {
        $_.configFingerprint -eq $identity.ConfigFingerprint -and
        $_.projectFingerprint -eq $identity.ProjectFingerprint -and
        $_.hookFingerprint -eq $identity.HookFingerprint
    }).Count -gt 0
}

function Get-CdpHookProjects {
    param([Parameter(Mandatory = $true)][string]$ConfigPath)

    $document = Read-CdpJsonDocument -LiteralPath $ConfigPath
    @(@($document.Value) | Where-Object {
        $_.enabled -eq $true -and (Get-CdpHookDescriptor -Project $_)
    })
}

function Show-CdpHookTrustList {
    param([Parameter(Mandatory = $true)][string]$ConfigPath)

    $store = Read-CdpHookTrustStore
    $projects = @(Get-CdpHookProjects -ConfigPath $ConfigPath)
    if ($projects.Count -eq 0) { Write-Host 'No command hooks found.' -ForegroundColor Yellow; return }
    Write-Host 'cdp hook trust' -ForegroundColor Cyan
    foreach ($project in $projects) {
        $identity = Get-CdpHookIdentity -ConfigPath $ConfigPath -Project $project
        $projectEntries = @($store.Value.entries | Where-Object {
            $_.configFingerprint -eq $identity.ConfigFingerprint -and
            $_.projectFingerprint -eq $identity.ProjectFingerprint
        })
        $state = if (@($projectEntries | Where-Object { $_.hookFingerprint -eq $identity.HookFingerprint }).Count) {
            'trusted'
        } elseif ($projectEntries.Count -gt 0) {
            'stale'
        } else {
            'untrusted'
        }
        Write-Host "  $($project.name) [$($identity.Kind)] $state"
    }
}

function Add-CdpHookTrust {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param([string]$ConfigPath, [string]$Name)

    $projects = @(Get-CdpHookProjects -ConfigPath $ConfigPath)
    $matches = @(Get-CdpProjectMatches -Projects $projects -Query $Name)
    if ($matches.Count -ne 1) { throw "Hook trust requires one project match; found $($matches.Count)." }
    $identity = Get-CdpHookIdentity -ConfigPath $ConfigPath -Project $matches[0]
    if (-not $PSCmdlet.ShouldProcess([string]$matches[0].name, 'Trust current hook fingerprint')) {
        return
    }
    $store = Read-CdpHookTrustStore
    $entries = @($store.Value.entries | Where-Object {
        -not ($_.configFingerprint -eq $identity.ConfigFingerprint -and
            $_.projectFingerprint -eq $identity.ProjectFingerprint)
    })
    $entries += [PSCustomObject]@{
        configFingerprint = $identity.ConfigFingerprint
        projectFingerprint = $identity.ProjectFingerprint
        hookFingerprint = $identity.HookFingerprint
        trustedAt = [DateTime]::UtcNow.ToString('o')
    }
    $store.Value.entries = @($entries)
    Save-CdpHookTrustStore -Document $store
    Write-Host "Trusted hook for project: $($matches[0].name)" -ForegroundColor Green
}

function Remove-CdpHookTrust {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param([string]$ConfigPath, [string]$Name)

    $store = Read-CdpHookTrustStore
    $configFingerprint = Get-CdpStringFingerprint -Value (Get-CdpNormalizedConfigPath $ConfigPath)
    $projectFingerprint = $null
    if ($Name -ne '--all') {
        $matches = @(Get-CdpProjectMatches -Projects @(Get-CdpHookProjects $ConfigPath) -Query $Name)
        if ($matches.Count -ne 1) { throw "Hook revoke requires one project match; found $($matches.Count)." }
        $projectFingerprint = (Get-CdpHookIdentity -ConfigPath $ConfigPath -Project $matches[0]).ProjectFingerprint
    }
    $target = if ($Name -eq '--all') { 'all hooks for active config' } else { $Name }
    if (-not $PSCmdlet.ShouldProcess($target, 'Revoke hook trust')) {
        return
    }
    $store.Value.entries = @($store.Value.entries | Where-Object {
        $_.configFingerprint -ne $configFingerprint -or
        ($projectFingerprint -and $_.projectFingerprint -ne $projectFingerprint)
    })
    Save-CdpHookTrustStore -Document $store
    Write-Host 'Hook trust revoked.' -ForegroundColor Green
}

function Invoke-CdpHookCommand {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param([string]$Action, [string]$Name, [string]$ConfigPath)

    try {
        if ([string]::IsNullOrWhiteSpace($ConfigPath)) { $ConfigPath = Get-DefaultConfigPath }
        if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { throw "Configuration file not found." }
        switch ($Action) {
            'list' { Show-CdpHookTrustList -ConfigPath $ConfigPath }
            'trust' {
                $parameters = @{ ConfigPath = $ConfigPath; Name = $Name }
                if ($WhatIfPreference) { $parameters.WhatIf = $true }
                if ($PSBoundParameters.ContainsKey('Confirm')) { $parameters.Confirm = $PSBoundParameters['Confirm'] }
                Add-CdpHookTrust @parameters
            }
            'revoke' {
                $parameters = @{ ConfigPath = $ConfigPath; Name = $Name }
                if ($WhatIfPreference) { $parameters.WhatIf = $true }
                if ($PSBoundParameters.ContainsKey('Confirm')) { $parameters.Confirm = $PSBoundParameters['Confirm'] }
                Remove-CdpHookTrust @parameters
            }
            default { throw "Unknown hook action." }
        }
    } catch {
        Write-Host "Error: hook trust operation failed ($($_.Exception.GetType().Name))." -ForegroundColor Red
    }
}

function Set-CdpOnEnterEnvironment {
    param([Parameter(Mandatory = $true)][object]$OnEnter)

    if ($OnEnter -is [string] -or -not $OnEnter.PSObject.Properties['env']) { return }
    $OnEnter.env.PSObject.Properties | ForEach-Object {
        if ($_.Name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            Write-Host "  onEnter warning: invalid environment variable name skipped." -ForegroundColor Yellow
        } else {
            [System.Environment]::SetEnvironmentVariable($_.Name, [string]$_.Value, 'Process')
        }
    }
}

function Get-CdpOnEnterCommand {
    param([Parameter(Mandatory = $true)][object]$OnEnter)

    if ($OnEnter -is [string]) { return [string]$OnEnter }
    if ($OnEnter.PSObject.Properties['powershell']) { return [string]$OnEnter.powershell }
    ''
}

function Invoke-CdpOnEnter {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Project,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$AllowHook,

        [Parameter(Mandatory = $false)]
        [switch]$NoHook
    )

    if (-not $Project.PSObject.Properties['onEnter'] -or $null -eq $Project.onEnter) {
        return
    }

    if ($NoHook) {
        Write-Host "  onEnter skipped by --no-hook." -ForegroundColor Yellow
        return
    }

    $onEnter = $Project.onEnter

    try {
        Set-CdpOnEnterEnvironment -OnEnter $onEnter

        $hookCommand = Get-CdpOnEnterCommand -OnEnter $onEnter

        if ([string]::IsNullOrWhiteSpace($hookCommand)) {
            return
        }

        $trusted = -not [string]::IsNullOrWhiteSpace($ConfigPath) -and
            (Test-CdpHookTrusted -ConfigPath $ConfigPath -Project $Project)
        if (-not $AllowHook -and -not $trusted) {
            Write-Host "  onEnter command skipped: trust this project hook or use -AllowHook once." -ForegroundColor Yellow
            return
        }

        Invoke-Expression $hookCommand
    } catch {
        Write-Host "  onEnter warning: command failed ($($_.Exception.GetType().Name))." -ForegroundColor Yellow
    }
}
