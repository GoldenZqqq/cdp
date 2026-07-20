# cdp PowerShell domain: Core.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

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

function ConvertTo-CdpJsonArrayValue {
    param([Parameter(Mandatory = $false)][AllowNull()][object]$Value)

    $items = if ($null -eq $Value) {
        [object[]]@()
    } elseif ($Value -is [System.Array]) {
        [object[]]$Value.Clone()
    } else {
        [object[]]@($Value)
    }
    [PSCustomObject]@{ Value = $items }
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
    $value = if ($content.TrimStart().StartsWith('[')) {
        (ConvertTo-CdpJsonArrayValue -Value $parsedValue).Value
    } else { $parsedValue }
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
    $value = if ($content.TrimStart().StartsWith('[')) {
        (ConvertTo-CdpJsonArrayValue -Value $parsedValue).Value
    } else { $parsedValue }
    Write-CdpJsonFile `
        -LiteralPath $LiteralPath `
        -Value $value `
        -ExpectedFingerprint (Get-CdpFileFingerprint -LiteralPath $LiteralPath)
}
