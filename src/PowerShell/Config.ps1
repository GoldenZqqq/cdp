# cdp PowerShell domain: Config.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

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
    $projects = (ConvertTo-CdpJsonArrayValue -Value $allProjects).Value

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
        $profilePaths = @()
        if ($_.PSObject.Properties['paths'] -and $null -ne $_.paths) {
            $profilePaths = @($_.paths.PSObject.Properties | Where-Object {
                $_.Value -is [string]
            } | ForEach-Object { [string]$_.Value })
        }
        $projectAliases = @(Get-CdpProjectStringList -Project $_ -PropertyName 'aliases')
        $projectTags = @(Get-CdpProjectStringList -Project $_ -PropertyName 'tags')

        $projectName.IndexOf($Query, $comparison) -ge 0 -or
            $projectPath.IndexOf($Query, $comparison) -ge 0 -or
            @($profilePaths | Where-Object { $_.IndexOf($Query, $comparison) -ge 0 }).Count -gt 0 -or
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
