# cdp PowerShell domain: Health.ps1
# Loaded by src/cdp.psm1; do not dot-source peer files.

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
    $invalidPathProfiles = @()
    $missingPaths = @()
    foreach ($project in $enabledProjects) {
        try {
            $resolution = Resolve-CdpProjectPath -Project $project
            if ($resolution.ErrorCode) { $invalidPathProfiles += $project; continue }
            if (-not (Test-Path -LiteralPath $resolution.ResolvedPath)) { $missingPaths += $project }
        } catch {
            $invalidPathProfiles += $project
        }
    }

    @(
        New-CdpHealthCheck -Name "project schema" -Passed ($invalidProjects.Count -eq 0) `
            -Level Error -Message "$($invalidProjects.Count) invalid project entries"
        New-CdpHealthCheck -Name "path profiles" -Passed ($invalidPathProfiles.Count -eq 0) `
            -Level Error -Message "$($invalidPathProfiles.Count) invalid current path profiles"
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
                if ($_.enabled -ne $true) { return $false }
                try {
                    $resolution = Resolve-CdpProjectPath -Project $_
                    return -not $resolution.ErrorCode -and -not (Test-Path -LiteralPath $resolution.ResolvedPath)
                } catch { return $false }
            }).Count
        }
    }
}
