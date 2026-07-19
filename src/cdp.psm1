<#
.SYNOPSIS
    cdp - A fast project directory switcher for PowerShell.

.DESCRIPTION
    cdp provides a fuzzy-search interface powered by fzf to quickly
    switch between projects. Compatible with Project Manager plugin.

.NOTES
    Name: cdp
    Author: GoldenZqqq
    Version: 2.1.0
    License: MIT
#>

$script:CdpProjectConfigCache = @{}
$script:CdpFzfCommand = $null
$script:CdpStateFingerprint = 'missing'
$script:CdpStateWritable = $true

function New-CdpActionResult {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)]
        [ValidateSet('preview', 'succeeded', 'skipped', 'canceled', 'failed')]
        [string]$Status,
        [Parameter(Mandatory = $true)][bool]$Changed,
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Error = '',
        [Parameter(Mandatory = $false)][object]$Details
    )

    $result = [PSCustomObject][ordered]@{
        Action = $Action
        Target = $Target
        Status = $Status
        Changed = $Changed
        Error = $Error
    }
    if ($null -ne $Details) {
        $result | Add-Member -NotePropertyName Details -NotePropertyValue $Details
        foreach ($property in $Details.PSObject.Properties) {
            if (-not $result.PSObject.Properties[$property.Name]) {
                $result | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
            }
        }
    }
    $result
}

function Read-CdpJsonArrayMutationDocument {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    if (Test-Path -LiteralPath $LiteralPath -PathType Leaf) {
        return Read-CdpJsonDocument -LiteralPath $LiteralPath
    }
    [PSCustomObject]@{
        Path = $LiteralPath
        Fingerprint = 'missing'
        Value = @()
    }
}

function Get-CdpUserHome {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) { return $env:USERPROFILE }
    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) { return $env:HOME }
    (Get-Location).Path
}

function Get-CdpFileFingerprint {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        return 'missing'
    }

    $stream = [System.IO.File]::Open(
        $LiteralPath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite
    )
    try {
        $algorithm = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hash = $algorithm.ComputeHash($stream)
            return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
        } finally {
            $algorithm.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Read-CdpJsonDocument {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        throw "JSON document not found: $LiteralPath"
    }

    $fingerprint = Get-CdpFileFingerprint -LiteralPath $LiteralPath
    $content = Get-Content -LiteralPath $LiteralPath -Raw -Encoding UTF8
    $parsedValue = ConvertFrom-Json -InputObject $content
    $value = if ($content.TrimStart().StartsWith('[')) { @($parsedValue) } else { $parsedValue }
    [PSCustomObject]@{
        Path = $LiteralPath
        Fingerprint = $fingerprint
        Value = $value
    }
}

function Remove-CdpOldJsonBackups {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][int]$Keep
    )

    $directory = Split-Path -Parent $LiteralPath
    $leaf = Split-Path -Leaf $LiteralPath
    $backups = @(Get-ChildItem -LiteralPath $directory -Filter "$leaf.cdp-backup.*" -File -ErrorAction SilentlyContinue |
        Sort-Object -Property Name -Descending)
    if ($backups.Count -le $Keep) { return }
    $backups | Select-Object -Skip $Keep | Remove-Item -Force -ErrorAction SilentlyContinue
}

function Write-CdpJsonTemporaryFile {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][AllowNull()][object]$Value
    )

    $json = ConvertTo-Json -InputObject $Value -Depth 20
    [void](ConvertFrom-Json -InputObject $json)
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $writer = New-Object System.IO.StreamWriter($LiteralPath, $false, $encoding)
    try {
        $writer.WriteLine($json)
        $writer.Flush()
        $writer.BaseStream.Flush($true)
    } finally {
        $writer.Dispose()
    }
}

function Move-CdpJsonTemporaryFile {
    param(
        [Parameter(Mandatory = $true)][string]$TempPath,
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][string]$Leaf
    )

    if (Test-Path -LiteralPath $LiteralPath -PathType Leaf) {
        $stamp = [DateTime]::UtcNow.ToString('yyyyMMddHHmmssfffffff')
        [System.IO.File]::Replace($TempPath, $LiteralPath, (Join-Path $Directory "$Leaf.cdp-backup.$stamp"))
        return
    }
    [System.IO.File]::Move($TempPath, $LiteralPath)
}

function Write-CdpJsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][AllowNull()][object]$Value,
        [Parameter(Mandatory = $false)][string]$ExpectedFingerprint,
        [Parameter(Mandatory = $false)][int]$BackupCount = 3
    )

    $directory = Split-Path -Parent $LiteralPath
    if ([string]::IsNullOrWhiteSpace($directory)) { $directory = (Get-Location).Path }
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $leaf = Split-Path -Leaf $LiteralPath
    $lockPath = Join-Path $directory "$leaf.cdp.lock"
    $tempPath = Join-Path $directory "$leaf.cdp-tmp.$([Guid]::NewGuid().ToString('N'))"
    $lockStream = $null
    $ownsLock = $false
    try {
        try {
            $lockStream = [System.IO.File]::Open(
                $lockPath,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None
            )
            $ownsLock = $true
        } catch {
            throw "JSON document is locked by another cdp process: $LiteralPath"
        }

        $currentFingerprint = Get-CdpFileFingerprint -LiteralPath $LiteralPath
        if (-not [string]::IsNullOrWhiteSpace($ExpectedFingerprint) -and
            $ExpectedFingerprint -ne $currentFingerprint) {
            throw "JSON document changed since it was read: $LiteralPath"
        }

        Write-CdpJsonTemporaryFile -LiteralPath $tempPath -Value $Value
        Move-CdpJsonTemporaryFile -TempPath $tempPath -LiteralPath $LiteralPath -Directory $directory -Leaf $leaf
        Remove-CdpOldJsonBackups -LiteralPath $LiteralPath -Keep $BackupCount
        Clear-CdpProjectConfigCache -ConfigPath $LiteralPath
        return Get-CdpFileFingerprint -LiteralPath $LiteralPath
    } finally {
        if ($lockStream) { $lockStream.Dispose() }
        if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
        if ($ownsLock -and (Test-Path -LiteralPath $lockPath)) {
            Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-CdpValidJsonBackups {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    $directory = Split-Path -Parent $LiteralPath
    $leaf = Split-Path -Leaf $LiteralPath
    @(Get-ChildItem -LiteralPath $directory -Filter "$leaf.cdp-backup.*" -File -ErrorAction SilentlyContinue |
        Sort-Object -Property Name -Descending |
        Where-Object {
            try {
                [void](ConvertFrom-Json -InputObject (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8))
                $true
            } catch {
                $false
            }
        })
}

function Restore-CdpJsonBackup {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][string]$BackupPath
    )

    $validBackups = @(Get-CdpValidJsonBackups -LiteralPath $LiteralPath)
    $backup = @($validBackups | Where-Object { $_.FullName -eq $BackupPath } | Select-Object -First 1)
    if ($backup.Count -ne 1) {
        throw "Backup is missing or invalid: $BackupPath"
    }

    $content = Get-Content -LiteralPath $backup[0].FullName -Raw -Encoding UTF8
    $parsedValue = ConvertFrom-Json -InputObject $content
    $value = if ($content.TrimStart().StartsWith('[')) { @($parsedValue) } else { $parsedValue }
    Write-CdpJsonFile `
        -LiteralPath $LiteralPath `
        -Value $value `
        -ExpectedFingerprint (Get-CdpFileFingerprint -LiteralPath $LiteralPath)
}

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
        AllowHook = $false
        NoHook = $false
        DirtyOnly = $false
        Fix = $false
        Push = $false
        DryRun = $false
        Yes = $false
        TagFilter = $null
        WorkspaceAction = $null
        WorkspaceName = $null
        Projects = @()
        Name = $null
        Value = $null
        RootPath = $null
        MaxDepth = 4
        Count = 10
        HookAction = $null
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
    $allowHook = $false
    $noHook = $false
    $dryRun = $false
    $assumeYes = $false
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
        if ($token -in @('--allow-hook', '-allow-hook')) {
            $allowHook = $true
            continue
        }
        if ($token -in @('--no-hook', '-no-hook')) {
            $noHook = $true
            continue
        }
        if ($token -in @('--dry-run', '-dry-run')) {
            $dryRun = $true
            continue
        }
        if ($token -in @('--yes', '-yes')) {
            $assumeYes = $true
            continue
        }
        $positionals.Add($token)
    }

    if ($allowHook -and $noHook) { throw "The --allow-hook and --no-hook options cannot be used together." }
    if ($dryRun -and $assumeYes) { throw "The --dry-run and --yes options cannot be used together." }

    [PSCustomObject]@{
        Tokens = @($positionals)
        Open = $resolvedOpen
        ConfigPath = $resolvedConfig
        AllowHook = $allowHook
        NoHook = $noHook
        DryRun = $dryRun
        Yes = $assumeYes
    }
}

function Resolve-CdpCommandKind {
    param([string]$Command)

    if ([string]::IsNullOrWhiteSpace($Command)) { return $null }
    switch -Regex ($Command.ToLowerInvariant()) {
        '^(status|st)$' { return 'status' }
        '^(workspace|ws)$' { return 'workspace' }
        '^(hook|hooks)$' { return 'hook' }
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
        '^(add|add-project)$' { return 'add' }
        '^(remove|rm|delete)$' { return 'remove' }
        '^(init|setup)$' { return 'init' }
        '^(scan|import)$' { return 'scan' }
        '^(config|select-config)$' { return 'config' }
        default { return $null }
    }
}

function ConvertFrom-CdpStatusTokens {
    param([string[]]$Tokens, [string]$ConfigPath, [bool]$DryRun, [bool]$Yes)

    $result = New-CdpInvocation -Kind 'status'
    $result.ConfigPath = $ConfigPath
    $result.DryRun = $DryRun
    $result.Yes = $Yes
    foreach ($token in $Tokens) {
        if ($token -in @('--dirty', '-dirty', '-d')) { $result.DirtyOnly = $true; continue }
        if ($token -in @('--fix', '-fix')) { $result.Fix = $true; continue }
        if ($token -in @('--push', '-push')) { $result.Push = $true; continue }
        if ($token -in @('--dry-run', '-dry-run')) { $result.DryRun = $true; continue }
        if ($token -in @('--yes', '-yes')) { $result.Yes = $true; continue }
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
    if ($result.DryRun -and $result.Yes) { throw "The --dry-run and --yes options cannot be used together." }
    if (($result.DryRun -or $result.Yes) -and -not ($result.Fix -or $result.Push)) {
        throw "The --dry-run and --yes options require --fix or --push."
    }
    $result
}

function ConvertFrom-CdpWorkspaceTokens {
    param([string[]]$Tokens, [string]$ConfigPath, [string]$Open, [bool]$DryRun, [bool]$Yes)

    $result = New-CdpInvocation -Kind 'workspace'
    $result.ConfigPath = $ConfigPath
    $result.Open = $Open
    $result.DryRun = $DryRun
    $result.Yes = $Yes
    if ($Tokens.Count -eq 0) {
        if ($DryRun -or $Yes) { throw "Workspace safety options require --add or a workspace name." }
        if ($Open) { throw "The --open option requires a workspace name or --add action." }
        $result.WorkspaceAction = 'usage'
        return $result
    }
    $action = $Tokens[0].ToLowerInvariant()
    if ($action -in @('--list', '-l', 'list')) {
        if ($DryRun -or $Yes) { throw "Workspace --list does not accept safety options." }
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
    param([string]$Kind, [string[]]$Tokens, [string]$ConfigPath, [bool]$DryRun, [bool]$Yes)

    $result = New-CdpInvocation -Kind $Kind
    $result.ConfigPath = $ConfigPath
    $result.DryRun = $DryRun
    $result.Yes = $Yes
    if ($Kind -eq 'doctor') {
        $items = @($Tokens | Where-Object { if ($_ -in @('--fix', '-fix')) { $result.Fix = $true; $false } else { $true } })
        Set-CdpTrailingConfigPath -Result $result -Arguments $items -RequiredCount 0
    } elseif ($Kind -eq 'hook') {
        if ($Tokens.Count -lt 1) { throw "Hook requires list, trust, or revoke." }
        $result.HookAction = $Tokens[0].ToLowerInvariant()
        if ($result.HookAction -notin @('list', 'trust', 'revoke')) { throw "Unknown hook action." }
        if ($result.HookAction -eq 'list') {
            Set-CdpTrailingConfigPath -Result $result -Arguments @($Tokens | Select-Object -Skip 1) -RequiredCount 0
        } else {
            Set-CdpTrailingConfigPath -Result $result -Arguments @($Tokens | Select-Object -Skip 1) -RequiredCount 1
            $result.Name = $Tokens[1]
        }
    } elseif ($Kind -in @('about', 'clean')) {
        Set-CdpTrailingConfigPath -Result $result -Arguments $Tokens -RequiredCount 0
    } elseif ($Kind -eq 'config') {
        if ($Tokens.Count -gt 1) { throw "Config selection accepts one numeric selection." }
        if ($Tokens.Count -eq 1) {
            $selection = 0
            if (-not [int]::TryParse($Tokens[0], [ref]$selection) -or $selection -lt 1) {
                throw "Config selection must be a positive integer."
            }
            $result.Count = $selection
        } else {
            $result.Count = 0
        }
    } elseif ($Kind -eq 'recent') {
        if ($Tokens.Count -gt 1) { throw "Recent count must be a positive integer." }
        if ($Tokens.Count -eq 1) {
            $recentCount = 0
            if (-not [int]::TryParse($Tokens[0], [ref]$recentCount)) { throw "Recent count must be a positive integer." }
            $result.Count = $recentCount
        }
        if ($result.Count -le 0) { throw "Recent count must be a positive integer." }
    } elseif ($Kind -in @('pin', 'unpin', 'remove')) {
        Set-CdpTrailingConfigPath -Result $result -Arguments $Tokens -RequiredCount 1
        $result.Name = $Tokens[0]
    } elseif ($Kind -eq 'add') {
        if ($Tokens.Count -gt 3) { throw "Add accepts a name, path, and optional config path." }
        if ($Tokens.Count -gt 0) { $result.Name = $Tokens[0] }
        if ($Tokens.Count -gt 1) { $result.RootPath = $Tokens[1] }
        if ($Tokens.Count -gt 2) {
            if ($result.ConfigPath) { throw "The config path was specified more than once." }
            $result.ConfigPath = $Tokens[2]
        }
    } elseif ($Kind -in @('alias', 'unalias', 'tag', 'untag')) {
        Set-CdpTrailingConfigPath -Result $result -Arguments $Tokens -RequiredCount 2
        $result.Name = $Tokens[0]
        $result.Value = $Tokens[1]
    } else {
        $result = ConvertFrom-CdpScanTokens -Kind $Kind -Tokens $Tokens -ConfigPath $ConfigPath
    }
    $result.DryRun = $DryRun
    $result.Yes = $Yes
    $isMutation = $Kind -in @('clean', 'add', 'remove', 'pin', 'unpin', 'alias', 'unalias', 'tag', 'untag', 'init', 'scan', 'config')
    if ($Kind -eq 'doctor') { $isMutation = $result.Fix }
    if ($Kind -eq 'hook') { $isMutation = $result.HookAction -in @('trust', 'revoke') }
    if (($DryRun -or $Yes) -and -not $isMutation) {
        throw "Safety options are only valid for mutating commands."
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
    param([string[]]$Tokens, [string]$Query, [string]$ConfigPath, [string]$Open, [bool]$AllowHook, [bool]$NoHook, [bool]$DryRun, [bool]$Yes)

    if ($DryRun -or $Yes) { throw "Safety options are not valid for project switching." }

    $result = New-CdpInvocation -Kind 'switch'
    $result.Query = $Query
    $result.ConfigPath = $ConfigPath
    $result.Open = $Open
    $result.AllowHook = $AllowHook
    $result.NoHook = $NoHook
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
    if ($kind -eq 'hook' -and
        ($tokens.Count -lt 2 -or $tokens[1].ToLowerInvariant() -notin @('list', 'trust', 'revoke'))) {
        $kind = $null
    }
    if ($kind) { $tokens = @($tokens | Select-Object -Skip 1) }

    if ($kind -eq 'status') {
        if ($common.Open) { throw "The --open option is not valid for status." }
        if ($common.AllowHook -or $common.NoHook) { throw "Hook options are only valid for project switching." }
        return ConvertFrom-CdpStatusTokens -Tokens $tokens -ConfigPath $common.ConfigPath -DryRun $common.DryRun -Yes $common.Yes
    }
    if ($kind -eq 'workspace') {
        if ($common.AllowHook -or $common.NoHook) { throw "Hook options are only valid for project switching." }
        return ConvertFrom-CdpWorkspaceTokens -Tokens $tokens -ConfigPath $common.ConfigPath -Open $common.Open -DryRun $common.DryRun -Yes $common.Yes
    }
    if ($kind) {
        if ($common.Open) { throw "The --open option is only valid for project and workspace commands." }
        if ($common.AllowHook -or $common.NoHook) { throw "Hook options are only valid for project switching." }
        return ConvertFrom-CdpManagementTokens -Kind $kind -Tokens $tokens -ConfigPath $common.ConfigPath -DryRun $common.DryRun -Yes $common.Yes
    }
    ConvertFrom-CdpSwitchTokens `
        -Tokens $tokens `
        -Query $Query `
        -ConfigPath $common.ConfigPath `
        -Open $common.Open `
        -AllowHook $common.AllowHook `
        -NoHook $common.NoHook `
        -DryRun $common.DryRun `
        -Yes $common.Yes
}

# Helper function to get stored config choice path
function Get-StoredConfigChoice {
    $configChoiceFile = Join-Path (Get-CdpUserHome) ".cdp\config"
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

    if ($WhatIfPreference) {
        Write-Host "Would save active config choice: $ConfigPath" -ForegroundColor Gray
        return
    }

    $configChoiceFile = Join-Path (Get-CdpUserHome) ".cdp\config"
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
    $customConfigPath = Join-Path (Get-CdpUserHome) ".cdp\projects.json"

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
        $customConfigPath = Join-Path (Get-CdpUserHome) ".cdp\projects.json"
        return $customConfigPath
    }

    # If only one config, use it without mutating the active-choice file.
    if ($availableConfigs.Count -eq 1) {
        return $availableConfigs[0].Path
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
    Write-Host "Use " -ForegroundColor Gray -NoNewline
    Write-Host "cdp-config" -ForegroundColor Cyan -NoNewline
    Write-Host " to persist an active configuration choice." -ForegroundColor Gray
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

                Write-Host "`nUsing: $selectedSource" -ForegroundColor Green
                Write-Host "Path: $selectedPath" -ForegroundColor Gray
                Write-Host "Choice not persisted; use cdp-config to save it." -ForegroundColor Gray
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
        if ($WhatIfPreference) {
            Write-Host "Would create new config file at: $ConfigPath" -ForegroundColor Gray
            return
        }
        [void](Write-CdpJsonFile -LiteralPath $ConfigPath -Value @() -ExpectedFingerprint 'missing')
        Write-Host "Created new config file at: $ConfigPath" -ForegroundColor Green
    }
}

function Get-CdpStatePath {
    if (-not [string]::IsNullOrWhiteSpace($env:CDP_STATE_PATH)) {
        return [Environment]::ExpandEnvironmentVariables($env:CDP_STATE_PATH)
    }

    Join-Path (Get-CdpUserHome) ".cdp\state.json"
}

function New-CdpState {
    [PSCustomObject]@{
        recentProjects = @()
    }
}

function Get-CdpState {
    $statePath = Get-CdpStatePath
    if (-not (Test-Path -LiteralPath $statePath)) {
        $script:CdpStateFingerprint = 'missing'
        $script:CdpStateWritable = $true
        return New-CdpState
    }

    try {
        $document = Read-CdpJsonDocument -LiteralPath $statePath
        $state = $document.Value

        if ($null -eq $state -or $state -is [array]) {
            $script:CdpStateFingerprint = $document.Fingerprint
            $script:CdpStateWritable = $false
            return New-CdpState
        }

        if ($state.PSObject.Properties.Name -notcontains 'recentProjects') {
            $state | Add-Member -MemberType NoteProperty -Name recentProjects -Value @()
        }

        $state.recentProjects = @($state.recentProjects)
        $script:CdpStateFingerprint = $document.Fingerprint
        $script:CdpStateWritable = $true
        return $state
    } catch {
        $script:CdpStateFingerprint = Get-CdpFileFingerprint -LiteralPath $statePath
        $script:CdpStateWritable = $false
        return New-CdpState
    }
}

function Save-CdpState {
    param(
        [Parameter(Mandatory = $true)]
        [object]$State
    )

    $statePath = Get-CdpStatePath
    if (-not $script:CdpStateWritable) {
        throw "Refusing to overwrite an invalid cdp state document: $statePath"
    }
    $script:CdpStateFingerprint = Write-CdpJsonFile `
        -LiteralPath $statePath `
        -Value $State `
        -ExpectedFingerprint $script:CdpStateFingerprint
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
                    $ConfigPath = Join-Path (Get-CdpUserHome) ".cdp\projects.json"
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
        $backupCount = @(Get-CdpValidJsonBackups -LiteralPath $ConfigPath).Count
        $message = if ($backupCount -gt 0) {
            "$($_.Exception.Message); $backupCount valid cdp backup(s) available"
        } else {
            $_.Exception.Message
        }
        $checks += New-CdpHealthCheck -Name "JSON" -Passed $false -Level Error -Message $message
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
        Remote = ""
        Upstream = ""
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
        $upstream = (& git -C $rootPath rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($upstream)) {
            $info.Upstream = [string]$upstream
            $separator = $info.Upstream.IndexOf('/')
            if ($separator -gt 0) {
                $info.Remote = $info.Upstream.Substring(0, $separator)
            }
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
        $projPath = [string]$project.rootPath
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

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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

    $document = $null
    try {
        if ($Fix) {
            $document = Read-CdpJsonDocument -LiteralPath $ConfigPath
            $enabledProjects = @(@($document.Value) | Where-Object { $_.enabled })
        } else {
            $configData = Get-CdpProjectConfig -ConfigPath $ConfigPath
            $enabledProjects = @($configData.EnabledProjects)
        }
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

    if ($Fix) {
        $missingProjects = @($statusList | Where-Object { -not $_.PathExists })
        if ($missingProjects.Count -eq 0) {
            Write-Host "`nNo path-missing projects to remove." -ForegroundColor Green
            if ($PassThru) { return @() }
            return
        }
        Write-Host "`nRemoving $($missingProjects.Count) path-missing projects:" -ForegroundColor Yellow
        foreach ($proj in $missingProjects) {
            Write-Host "  x $($proj.Name)" -ForegroundColor DarkGray -NoNewline
            Write-Host "  $($proj.RootPath)" -ForegroundColor DarkGray
        }
        $resolvedConfig = if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) { $ConfigPath } else { Get-DefaultConfigPath }
        if (-not $PSCmdlet.ShouldProcess($resolvedConfig, "Remove $($missingProjects.Count) missing project entries")) {
            if ($PassThru) {
                $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
                return @($missingProjects | ForEach-Object {
                    New-CdpActionResult -Action 'status-fix' -Target ([string]$_.Name) -Status $status -Changed $false -Details $_
                })
            }
            return
        }
        $allProjects = $document.Value
        $missingPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($project in $missingProjects) {
            [void]$missingPaths.Add((Get-CdpComparablePath -Path $project.RootPath))
        }
        $cleaned = @(@($allProjects) | Where-Object {
            $_.enabled -ne $true -or
                -not $missingPaths.Contains((Get-CdpComparablePath -Path ([string]$_.rootPath)))
        })
        try {
            [void](Write-CdpJsonFile -LiteralPath $resolvedConfig -Value @($cleaned) -ExpectedFingerprint $document.Fingerprint)
        } catch {
            $errorMessage = $_.Exception.Message
            Write-Host "`nFailed to remove missing projects: $errorMessage" -ForegroundColor Red
            if ($PassThru) {
                return @($missingProjects | ForEach-Object {
                    New-CdpActionResult -Action 'status-fix' -Target ([string]$_.Name) -Status 'failed' -Changed $false -Error $errorMessage -Details $_
                })
            }
            throw
        }
        Write-Host "`nRemoved $($missingProjects.Count) projects. $($cleaned.Count) projects remain." -ForegroundColor Green
        if ($PassThru) {
            return @($missingProjects | ForEach-Object {
                New-CdpActionResult -Action 'status-fix' -Target ([string]$_.Name) -Status 'succeeded' -Changed $true -Details $_
            })
        }
        return
    }

    if ($Push) {
        $aheadProjects = @($statusList | Where-Object { $_.AheadCount -gt 0 -and $_.IsGitRepo })
        if ($aheadProjects.Count -eq 0) {
            Write-Host "`nNo repos ahead of remote." -ForegroundColor Green
            if ($PassThru) { return @() }
            return
        }
        Write-Host "`nPushing $($aheadProjects.Count) repos ahead of remote:" -ForegroundColor Yellow
        $pushResults = @()
        $pushFailed = $false
        foreach ($proj in $aheadProjects) {
            $upstreamLabel = if ($proj.Upstream) { "remote=$($proj.Remote), upstream=$($proj.Upstream)" } else { 'configured upstream' }
            Write-Host "  $($proj.Name) (^$($proj.AheadCount), $upstreamLabel)" -ForegroundColor Cyan
            if (-not $PSCmdlet.ShouldProcess("$($proj.Name) [$upstreamLabel]", 'Push commits to configured upstream')) {
                $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
                $pushResults += New-CdpActionResult -Action 'status-push' -Target ([string]$proj.Name) -Status $status -Changed $false -Details $proj
                continue
            }
            Write-Host "    running... " -ForegroundColor DarkGray -NoNewline
            try {
                $pushOutput = @(& git -C $proj.RootPath push --porcelain 2>&1)
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "done" -ForegroundColor Green
                    $pushResults += New-CdpActionResult -Action 'status-push' -Target ([string]$proj.Name) -Status 'succeeded' -Changed $true -Details $proj
                } else {
                    $failure = @($pushOutput | Select-Object -Last 1) -join ''
                    Write-Host "failed: $failure" -ForegroundColor Red
                    $pushFailed = $true
                    $pushResults += New-CdpActionResult -Action 'status-push' -Target ([string]$proj.Name) -Status 'failed' -Changed $false -Error $failure -Details $proj
                }
            } catch {
                Write-Host "failed: $($_.Exception.Message)" -ForegroundColor Red
                $pushFailed = $true
                $pushResults += New-CdpActionResult -Action 'status-push' -Target ([string]$proj.Name) -Status 'failed' -Changed $false -Error $_.Exception.Message -Details $proj
            }
        }
        if ($pushFailed -and -not $PassThru) { $global:LASTEXITCODE = 1 }
        if ($PassThru) { return $pushResults }
        return
    }

    if ($PassThru) {
        if ($DirtyOnly) {
            return @($statusList | Where-Object { $_.NeedsAttention })
        }
        return $statusList
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

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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
        $ConfigPath = Join-Path (Get-CdpUserHome) ".cdp\projects.json"
    }

    $initDetails = [PSCustomObject]@{
        ConfigPath = $ConfigPath
        FzfFound = $null -ne (Resolve-CdpFzfCommand)
        ScanResult = $null
    }
    if (-not $PSCmdlet.ShouldProcess($ConfigPath, 'Initialize cdp configuration and active selection')) {
        if ($PassThru) {
            $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
            return New-CdpActionResult -Action 'initialize-cdp' -Target $ConfigPath -Status $status -Changed $false -Details $initDetails
        }
        return
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
        $scanResult = Import-GitProjects -RootPath $RootPath -ConfigPath $ConfigPath -MaxDepth $MaxDepth -PassThru -Confirm:$false
    }

    if ($PassThru) {
        $initDetails.FzfFound = $fzfFound
        $initDetails.ScanResult = $scanResult
        return New-CdpActionResult -Action 'initialize-cdp' -Target $ConfigPath -Status 'succeeded' -Changed $true -Details $initDetails
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

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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

    try {
        $document = Read-CdpJsonArrayMutationDocument -LiteralPath $ConfigPath
        $parsedProjects = $document.Value
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

    Write-Host "Git repositories found: $($repos.Count)" -ForegroundColor Cyan
    Write-Host "Projects added: $($addedProjects.Count)" -ForegroundColor Green
    Write-Host "Projects skipped: $skippedCount" -ForegroundColor Yellow
    Write-Host "Config: $ConfigPath" -ForegroundColor Gray

    $details = [PSCustomObject]@{
        RootPath = $resolvedRoot.Path
        ConfigPath = $ConfigPath
        FoundCount = $repos.Count
        AddedCount = $addedProjects.Count
        SkippedCount = $skippedCount
        AddedProjects = $addedProjects
    }
    if ($addedProjects.Count -eq 0) {
        if ($PassThru) {
            return New-CdpActionResult -Action 'scan-import' -Target $resolvedRoot.Path -Status 'skipped' -Changed $false -Details $details
        }
        return
    }

    if (-not $PSCmdlet.ShouldProcess($ConfigPath, "Import $($addedProjects.Count) repositories found under $($resolvedRoot.Path)")) {
        if ($PassThru) {
            $status = if ($WhatIfPreference) { 'preview' } else { 'canceled' }
            return New-CdpActionResult -Action 'scan-import' -Target $resolvedRoot.Path -Status $status -Changed $false -Details $details
        }
        return
    }

    try {
        [void](Write-CdpJsonFile -LiteralPath $ConfigPath -Value @($projects) -ExpectedFingerprint $document.Fingerprint)
    } catch {
        Write-Host "Error: Failed to import scanned projects." -ForegroundColor Red
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
        if ($PassThru) {
            return New-CdpActionResult -Action 'scan-import' -Target $resolvedRoot.Path -Status 'failed' -Changed $false -Error $_.Exception.Message -Details $details
        }
        return
    }

    if ($PassThru) {
        return New-CdpActionResult -Action 'scan-import' -Target $resolvedRoot.Path -Status 'succeeded' -Changed $true -Details $details
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

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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
        $parameters = @{ ConfigPath = $ConfigPath; PassThru = $PassThru }
        if ($WhatIfPreference) { $parameters.WhatIf = $true }
        if ($PSBoundParameters.ContainsKey('Confirm')) { $parameters.Confirm = $PSBoundParameters['Confirm'] }
        Repair-ProjectConfig @parameters
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

    $parameters = @{
        ConfigPath = $Invocation.ConfigPath
        DirtyOnly = $Invocation.DirtyOnly
        TagFilter = $Invocation.TagFilter
        Fix = $Invocation.Fix
        Push = $Invocation.Push
    }
    if ($Invocation.DryRun) { $parameters.WhatIf = $true }
    if ($Invocation.Yes) { $parameters.Confirm = $false }
    Show-CdpProjectStatus @parameters
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
                -Open $invocation.Open `
                -AllowHook:$invocation.AllowHook `
                -NoHook:$invocation.NoHook
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
        'status', 'doctor', 'about', 'recent', 'add', 'remove', 'pin', 'unpin',
        'alias', 'unalias', 'tag', 'untag', 'clean', 'init', 'scan', 'config', 'workspace', 'hook'
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
