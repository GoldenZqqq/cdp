# cdp PowerShell domain: Picker.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

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
