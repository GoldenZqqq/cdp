# cdp PowerShell domain: Paths.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

function Convert-WindowsPathToWSL {
    param([Parameter(Mandatory = $true)][string]$WindowsPath)

    $normalizedPath = $WindowsPath -replace '\\', '/'
    if ($normalizedPath -match '^([A-Za-z]):(.*)$') {
        return "/mnt/$($matches[1].ToLower())$($matches[2])"
    }
    $normalizedPath
}

function Get-CdpDetectedPathProfile {
    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        return 'windows'
    }

    if (-not [string]::IsNullOrWhiteSpace($env:WSL_DISTRO_NAME) -or
        -not [string]::IsNullOrWhiteSpace($env:WSL_INTEROP)) {
        return 'wsl'
    }

    if (Test-Path -LiteralPath '/proc/version' -PathType Leaf) {
        $kernelVersion = Get-Content -LiteralPath '/proc/version' -Raw -ErrorAction SilentlyContinue
        if ($kernelVersion -match '(?i)microsoft|wsl') { return 'wsl' }
    }

    $systemName = ''
    try { $systemName = (& uname -s 2>$null) } catch {}
    if ([string]::Equals([string]$systemName, 'Darwin', [StringComparison]::OrdinalIgnoreCase)) {
        return 'macos'
    }
    'linux'
}

function Get-CdpCurrentPathProfile {
    param([Parameter(Mandatory = $false)][string]$Profile)

    $candidate = $Profile
    if ([string]::IsNullOrWhiteSpace($candidate)) { $candidate = $env:CDP_PATH_PROFILE }
    if ([string]::IsNullOrWhiteSpace($candidate)) { return Get-CdpDetectedPathProfile }

    $normalized = $candidate.Trim().ToLowerInvariant()
    if ($normalized -notin @('windows', 'wsl', 'linux', 'macos')) {
        throw "Invalid CDP_PATH_PROFILE '$candidate'. Expected windows, wsl, linux, or macos."
    }
    $normalized
}

function Get-CdpProjectPathProperty {
    param(
        [Parameter(Mandatory = $true)][object]$Paths,
        [Parameter(Mandatory = $true)][string]$Profile
    )

    if ($Paths -is [System.Collections.IDictionary]) {
        if (-not $Paths.Contains($Profile)) { return $null }
        return [PSCustomObject]@{ Exists = $true; Value = $Paths[$Profile] }
    }

    $property = $Paths.PSObject.Properties[$Profile]
    if (-not $property) { return $null }
    [PSCustomObject]@{ Exists = $true; Value = $property.Value }
}

function New-CdpPathResolution {
    param(
        [string]$RawPath,
        [string]$ResolvedPath,
        [string]$Profile,
        [string]$Source,
        [bool]$IsExplicit,
        [string]$ErrorCode = '',
        [string]$ErrorMessage = ''
    )

    [PSCustomObject]@{
        RawPath = $RawPath
        ResolvedPath = $ResolvedPath
        Profile = $Profile
        Source = $Source
        IsExplicit = $IsExplicit
        ErrorCode = $ErrorCode
        ErrorMessage = $ErrorMessage
    }
}

function Get-CdpInvalidKnownPathProfile {
    param([Parameter(Mandatory = $true)][object]$Paths)

    foreach ($knownProfile in @('windows', 'wsl', 'linux', 'macos')) {
        $knownValue = Get-CdpProjectPathProperty -Paths $Paths -Profile $knownProfile
        if ($knownValue -and (-not ($knownValue.Value -is [string]) -or
            [string]::IsNullOrWhiteSpace([string]$knownValue.Value))) {
            return $knownProfile
        }
    }
    $null
}

function Resolve-CdpProjectPath {
    param(
        [Parameter(Mandatory = $true)][object]$Project,
        [Parameter(Mandatory = $false)][string]$Profile
    )

    $selectedProfile = Get-CdpCurrentPathProfile -Profile $Profile
    $rawPath = [string]$Project.rootPath
    if ([string]::IsNullOrWhiteSpace($rawPath)) {
        return New-CdpPathResolution -RawPath $rawPath -ResolvedPath '' `
            -Profile $selectedProfile -Source 'rootPath' -IsExplicit $false `
            -ErrorCode 'path_profile_invalid' -ErrorMessage 'Project rootPath must be a non-empty string.'
    }

    $pathsProperty = $Project.PSObject.Properties['paths']
    if ($pathsProperty) {
        $paths = $pathsProperty.Value
        $isObject = $null -ne $paths -and
            ($paths -is [System.Collections.IDictionary] -or $paths -is [PSCustomObject])
        if (-not $isObject) {
            return New-CdpPathResolution -RawPath $rawPath -ResolvedPath '' `
                -Profile $selectedProfile -Source "paths.$selectedProfile" -IsExplicit $true `
                -ErrorCode 'path_profile_invalid' -ErrorMessage 'Project paths must be a JSON object.'
        }

        $invalidProfile = Get-CdpInvalidKnownPathProfile -Paths $paths
        if ($invalidProfile) {
            return New-CdpPathResolution -RawPath $rawPath -ResolvedPath '' `
                -Profile $selectedProfile -Source "paths.$invalidProfile" `
                -IsExplicit ($invalidProfile -eq $selectedProfile) `
                -ErrorCode 'path_profile_invalid' `
                -ErrorMessage "Project paths.$invalidProfile must be a non-empty string."
        }

        $selected = Get-CdpProjectPathProperty -Paths $paths -Profile $selectedProfile
        if ($selected) {
            return New-CdpPathResolution -RawPath $rawPath -ResolvedPath ([string]$selected.Value) `
                -Profile $selectedProfile -Source "paths.$selectedProfile" -IsExplicit $true
        }
    }

    if ($selectedProfile -eq 'wsl') {
        return New-CdpPathResolution -RawPath $rawPath `
            -ResolvedPath (Convert-WindowsPathToWSL -WindowsPath $rawPath) `
            -Profile $selectedProfile -Source 'rootPath:wsl-converted' -IsExplicit $false
    }
    New-CdpPathResolution -RawPath $rawPath -ResolvedPath $rawPath `
        -Profile $selectedProfile -Source 'rootPath' -IsExplicit $false
}

function New-CdpProjectPathMap {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $false)][string]$Profile
    )

    $selectedProfile = Get-CdpCurrentPathProfile -Profile $Profile
    $values = [ordered]@{}
    $values[$selectedProfile] = $RootPath
    [PSCustomObject]$values
}

function Find-CdpProjectByLocalPath {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Projects,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $target = Get-CdpComparablePath -Path $Path
    foreach ($project in $Projects) {
        $resolution = Resolve-CdpProjectPath -Project $project
        if ($resolution.ErrorCode) { continue }
        if ((Get-CdpComparablePath -Path $resolution.ResolvedPath) -eq $target) {
            return $project
        }
    }
    $null
}
