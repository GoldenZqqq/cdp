BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ManifestPath = Join-Path $script:RepoRoot 'cdp.psd1'
    Import-Module $script:ManifestPath -Force

    function Read-TestProjects {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path
        )

        $jsonContent = Get-Content -Path $Path -Raw -Encoding UTF8
        $projects = ConvertFrom-Json -InputObject $jsonContent
        @($projects)
    }

    function Invoke-TestGit {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string[]]$Arguments
        )

        $output = @(& git -C $Path @Arguments 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "git -C $Path $($Arguments -join ' ') failed: $($output -join [Environment]::NewLine)"
        }
        $output
    }

    function New-TestGitRepository {
        param([Parameter(Mandatory = $true)][string]$Path)

        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Invoke-TestGit -Path $Path -Arguments @('init', '--quiet', '-b', 'main') | Out-Null
        Invoke-TestGit -Path $Path -Arguments @('config', 'user.email', 'tests@example.invalid') | Out-Null
        Invoke-TestGit -Path $Path -Arguments @('config', 'user.name', 'cdp tests') | Out-Null
    }
}

Describe 'cdp module manifest' {
    It 'has a valid manifest' {
        $manifest = Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop

        $manifest.Name | Should -Be 'cdp'
        $manifest.Version.ToString() | Should -Be '2.3.0'
    }
}

Describe 'cdp public surface' {
    It 'exports the expected commands' {
        $commandNames = (Get-Command -Module cdp).Name

        $commandNames | Should -Contain 'Invoke-Cdp'
        $commandNames | Should -Contain 'Switch-Project'
        $commandNames | Should -Contain 'Get-ProjectList'
        $commandNames | Should -Contain 'Add-Project'
        $commandNames | Should -Contain 'Set-ProjectPin'
        $commandNames | Should -Contain 'Clear-ProjectPin'
        $commandNames | Should -Contain 'Repair-ProjectConfig'
        $commandNames | Should -Contain 'Initialize-Cdp'
        $commandNames | Should -Contain 'Add-ProjectAlias'
        $commandNames | Should -Contain 'Remove-ProjectAlias'
        $commandNames | Should -Contain 'Add-ProjectTag'
        $commandNames | Should -Contain 'Remove-ProjectTag'
        $commandNames | Should -Contain 'Import-GitProjects'
        $commandNames | Should -Contain 'Remove-Project'
        $commandNames | Should -Contain 'Edit-ProjectConfig'
        $commandNames | Should -Contain 'Set-ProjectConfig'
        $commandNames | Should -Contain 'Test-ProjectHealth'
        $commandNames | Should -Contain 'Show-CdpAbout'
        $commandNames | Should -Contain 'Get-CdpRecentProjects'
    }

    It 'exports the expected aliases' {
        (Get-Alias cdp).Definition | Should -Be 'Invoke-Cdp'
        (Get-Alias cdp-add).Definition | Should -Be 'Add-Project'
        (Get-Alias cdp-rm).Definition | Should -Be 'Remove-Project'
        (Get-Alias cdp-ls).Definition | Should -Be 'Get-ProjectList'
        (Get-Alias cdp-edit).Definition | Should -Be 'Edit-ProjectConfig'
        (Get-Alias cdp-config).Definition | Should -Be 'Set-ProjectConfig'
        (Get-Alias cdp-doctor).Definition | Should -Be 'Test-ProjectHealth'
        (Get-Alias cdp-scan).Definition | Should -Be 'Import-GitProjects'
        (Get-Alias cdp-recent).Definition | Should -Be 'Get-CdpRecentProjects'
        (Get-Alias cdp-pin).Definition | Should -Be 'Set-ProjectPin'
        (Get-Alias cdp-unpin).Definition | Should -Be 'Clear-ProjectPin'
        (Get-Alias cdp-clean).Definition | Should -Be 'Repair-ProjectConfig'
        (Get-Alias cdp-init).Definition | Should -Be 'Initialize-Cdp'
        (Get-Alias cdp-alias).Definition | Should -Be 'Add-ProjectAlias'
        (Get-Alias cdp-unalias).Definition | Should -Be 'Remove-ProjectAlias'
        (Get-Alias cdp-tag).Definition | Should -Be 'Add-ProjectTag'
        (Get-Alias cdp-untag).Definition | Should -Be 'Remove-ProjectTag'
    }
}

Describe 'project configuration helpers' {
    It 'adds a project to a custom config file' {
        $configPath = Join-Path $TestDrive 'projects.json'
        $projectPath = Join-Path $TestDrive 'ExampleProject'
        New-Item -ItemType Directory -Path $projectPath | Out-Null
        '[]' | Set-Content -Path $configPath -Encoding UTF8

        Add-Project -Name 'ExampleProject' -Path $projectPath -ConfigPath $configPath

        $projects = @(Read-TestProjects -Path $configPath)
        $projects.Count | Should -Be 1
        $projects[0].name | Should -Be 'ExampleProject'
        $projects[0].rootPath | Should -Be $projectPath
        $projects[0].enabled | Should -BeTrue
        $projects[0].pinned | Should -BeFalse
        @($projects[0].aliases).Count | Should -Be 0
        @($projects[0].tags).Count | Should -Be 0
    }

    It 'reports health details for a valid custom config file' {
        $configPath = Join-Path $TestDrive 'projects.json'
        $projectPath = Join-Path $TestDrive 'HealthyProject'
        New-Item -ItemType Directory -Path $projectPath | Out-Null

        @(
            [PSCustomObject]@{
                name = 'HealthyProject'
                rootPath = $projectPath
                enabled = $true
            },
            [PSCustomObject]@{
                name = 'DisabledProject'
                rootPath = Join-Path $TestDrive 'DisabledProject'
                enabled = $false
            }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        $health = Test-ProjectHealth -ConfigPath $configPath -PassThru -SkipUpdateCheck

        $health.ConfigPath | Should -Be $configPath
        $health.ProjectCount | Should -Be 2
        $health.EnabledProjectCount | Should -Be 1
        $health.MissingPathCount | Should -Be 0
    }

    It 'pins projects and sorts pinned projects first' {
        $configPath = Join-Path $TestDrive 'pin-projects.json'
        $apiPath = Join-Path $TestDrive 'PinApiProject'
        $webPath = Join-Path $TestDrive 'PinWebProject'
        New-Item -ItemType Directory -Path $apiPath | Out-Null
        New-Item -ItemType Directory -Path $webPath | Out-Null

        @(
            [PSCustomObject]@{
                name = 'PinApiProject'
                rootPath = $apiPath
                enabled = $true
            },
            [PSCustomObject]@{
                name = 'PinWebProject'
                rootPath = $webPath
                enabled = $true
            }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        $pinned = Set-ProjectPin -Name 'PinWeb' -ConfigPath $configPath -PassThru
        $pinned.name | Should -Be 'PinWebProject'
        $pinned.pinned | Should -BeTrue

        InModuleScope cdp -Parameters @{ ConfigPath = $configPath } {
            $configData = Get-CdpProjectConfig -ConfigPath $ConfigPath
            $sortedProjects = @(Sort-CdpProjectsForDisplay -Projects @($configData.EnabledProjects))

            $sortedProjects[0].name | Should -Be 'PinWebProject'
            $sortedProjects[1].name | Should -Be 'PinApiProject'
        }

        $unpinned = Clear-ProjectPin -Name 'PinWeb' -ConfigPath $configPath -PassThru
        $unpinned.pinned | Should -BeFalse
    }

    It 'routes cdp pin and unpin through Invoke-Cdp' {
        $configPath = Join-Path $TestDrive 'pin-route-projects.json'
        $apiPath = Join-Path $TestDrive 'PinRouteApiProject'
        New-Item -ItemType Directory -Path $apiPath | Out-Null

        @(
            [PSCustomObject]@{
                name = 'PinRouteApiProject'
                rootPath = $apiPath
                enabled = $true
            }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        $previousConfig = $env:CDP_CONFIG
        $env:CDP_CONFIG = $configPath
        try {
            Invoke-Cdp pin PinRoute
            $projects = @(Read-TestProjects -Path $configPath)
            $projects[0].pinned | Should -BeTrue

            Invoke-Cdp unpin PinRoute
            $projects = @(Read-TestProjects -Path $configPath)
            $projects[0].pinned | Should -BeFalse
        } finally {
            $env:CDP_CONFIG = $previousConfig
        }
    }

    It 'repairs invalid, duplicate, and stale project config entries' {
        $configPath = Join-Path $TestDrive 'repair-projects.json'
        $apiPath = Join-Path $TestDrive 'RepairApiProject'
        $webPath = Join-Path $TestDrive 'RepairWebProject'
        $badEnabledPath = Join-Path $TestDrive 'RepairBadEnabledProject'
        $missingPath = Join-Path $TestDrive 'RepairMissingProject'
        New-Item -ItemType Directory -Path $apiPath | Out-Null
        New-Item -ItemType Directory -Path $webPath | Out-Null
        New-Item -ItemType Directory -Path $badEnabledPath | Out-Null

        @(
            [PSCustomObject]@{ name = 'RepairApi'; rootPath = $apiPath; enabled = $true },
            [PSCustomObject]@{ name = 'RepairApi'; rootPath = $webPath; enabled = $true },
            [PSCustomObject]@{ name = 'RepairDuplicatePath'; rootPath = $apiPath; enabled = $true },
            [PSCustomObject]@{ name = 'RepairMissing'; rootPath = $missingPath; enabled = $true },
            [PSCustomObject]@{ name = 'RepairBadEnabled'; rootPath = $badEnabledPath; enabled = 'yes' },
            [PSCustomObject]@{ name = ''; rootPath = ''; enabled = $true }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        $summary = Repair-ProjectConfig -ConfigPath $configPath -PassThru -Confirm:$false
        $projects = @(Read-TestProjects -Path $configPath)

        $summary.ProjectCount | Should -Be 4
        $summary.RemovedInvalid | Should -Be 1
        $summary.RemovedDuplicatePaths | Should -Be 1
        $summary.RenamedDuplicates | Should -Be 1
        $summary.DisabledMissingPaths | Should -Be 1
        $summary.FixedEnabledFields | Should -Be 1
        $projects.name | Should -Contain 'RepairApi'
        $projects.name | Should -Contain 'RepairApi-2'
        ($projects | Where-Object name -eq 'RepairMissing').enabled | Should -BeFalse
        ($projects | Where-Object name -eq 'RepairBadEnabled').enabled | Should -BeFalse
        @($projects | Where-Object { $null -eq $_.pinned }).Count | Should -Be 0
    }

    It 'routes cdp clean through Invoke-Cdp' {
        $configPath = Join-Path $TestDrive 'clean-route-projects.json'
        $apiPath = Join-Path $TestDrive 'CleanRouteApiProject'
        New-Item -ItemType Directory -Path $apiPath | Out-Null

        @(
            [PSCustomObject]@{ name = 'CleanRouteApi'; rootPath = $apiPath; enabled = $true },
            [PSCustomObject]@{ name = 'CleanRouteDuplicate'; rootPath = $apiPath; enabled = $true }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        $previousConfig = $env:CDP_CONFIG
        $env:CDP_CONFIG = $configPath
        try {
            Invoke-Cdp clean --yes

            $projects = @(Read-TestProjects -Path $configPath)
            $projects.Count | Should -Be 1
            $projects[0].name | Should -Be 'CleanRouteApi'
        } finally {
            $env:CDP_CONFIG = $previousConfig
        }
    }

    It 'initializes cdp and scans Git repositories' {
        $configPath = Join-Path $TestDrive 'init-projects.json'
        $scanRoot = Join-Path $TestDrive 'InitRepos'
        $repoPath = Join-Path $scanRoot 'InitApiProject'
        New-Item -ItemType Directory -Path (Join-Path $repoPath '.git') -Force | Out-Null

        $result = Initialize-Cdp -RootPath $scanRoot -ConfigPath $configPath -PassThru -Confirm:$false
        $projects = @(Read-TestProjects -Path $configPath)

        $result.ConfigPath | Should -Be $configPath
        $projects.Count | Should -Be 1
        $projects[0].name | Should -Be 'InitApiProject'
        $projects[0].pinned | Should -BeFalse
    }

    It 'routes cdp init through Invoke-Cdp' {
        $scanRoot = Join-Path $TestDrive 'InitRouteRepos'
        $repoPath = Join-Path $scanRoot 'InitRouteApiProject'
        New-Item -ItemType Directory -Path (Join-Path $repoPath '.git') -Force | Out-Null

        $previousUserProfile = $env:USERPROFILE
        $env:USERPROFILE = $TestDrive
        try {
            Invoke-Cdp init $scanRoot --yes

            $configPath = Join-Path $TestDrive '.cdp\projects.json'
            $projects = @(Read-TestProjects -Path $configPath)
            $projects.Count | Should -Be 1
            $projects[0].rootPath | Should -Be $repoPath
        } finally {
            $env:USERPROFILE = $previousUserProfile
        }
    }

    It 'matches projects by alias and tag metadata' {
        $configPath = Join-Path $TestDrive 'metadata-projects.json'
        $statePath = Join-Path $TestDrive 'metadata-state.json'
        $apiPath = Join-Path $TestDrive 'MetadataApiProject'
        New-Item -ItemType Directory -Path $apiPath | Out-Null

        @(
            [PSCustomObject]@{
                name = 'MetadataApiProject'
                rootPath = $apiPath
                enabled = $true
                aliases = @()
                tags = @()
            }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        $project = Add-ProjectAlias -Name 'MetadataApi' -Alias 'mapi' -ConfigPath $configPath -PassThru
        @($project.aliases) | Should -Contain 'mapi'

        $project = Add-ProjectTag -Name 'MetadataApi' -Tag 'work' -ConfigPath $configPath -PassThru
        @($project.tags) | Should -Contain 'work'

        $previousStatePath = $env:CDP_STATE_PATH
        $env:CDP_STATE_PATH = $statePath
        Push-Location $TestDrive
        try {
            Invoke-Cdp mapi $configPath
            (Get-Location).Path | Should -Be $apiPath

            Pop-Location
            Push-Location $TestDrive
            Invoke-Cdp '@work' $configPath
            (Get-Location).Path | Should -Be $apiPath
        } finally {
            Pop-Location
            $env:CDP_STATE_PATH = $previousStatePath
        }
    }

    It 'routes alias and tag commands through Invoke-Cdp' {
        $configPath = Join-Path $TestDrive 'metadata-route-projects.json'
        $apiPath = Join-Path $TestDrive 'MetadataRouteApiProject'
        New-Item -ItemType Directory -Path $apiPath | Out-Null

        @(
            [PSCustomObject]@{
                name = 'MetadataRouteApiProject'
                rootPath = $apiPath
                enabled = $true
            }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        $previousConfig = $env:CDP_CONFIG
        $env:CDP_CONFIG = $configPath
        try {
            Invoke-Cdp alias MetadataRoute route-api
            Invoke-Cdp tag MetadataRoute work
            $projects = @(Read-TestProjects -Path $configPath)
            @($projects[0].aliases) | Should -Contain 'route-api'
            @($projects[0].tags) | Should -Contain 'work'

            Invoke-Cdp unalias MetadataRoute route-api
            Invoke-Cdp untag MetadataRoute work
            $projects = @(Read-TestProjects -Path $configPath)
            @($projects[0].aliases) | Should -Not -Contain 'route-api'
            @($projects[0].tags) | Should -Not -Contain 'work'
        } finally {
            $env:CDP_CONFIG = $previousConfig
        }
    }

    It 'routes cdp doctor through Invoke-Cdp' {
        $configPath = Join-Path $TestDrive 'projects.json'
        '[]' | Set-Content -Path $configPath -Encoding UTF8

        $previousSkipUpdateCheck = $env:CDP_SKIP_UPDATE_CHECK
        $env:CDP_SKIP_UPDATE_CHECK = '1'
        try {
            { Invoke-Cdp doctor $configPath } | Should -Not -Throw
        } finally {
            $env:CDP_SKIP_UPDATE_CHECK = $previousSkipUpdateCheck
        }
    }

    It 'shows about information through the version subcommand' {
        $configPath = Join-Path $TestDrive 'about-projects.json'
        $projectPath = Join-Path $TestDrive 'AboutProject'
        New-Item -ItemType Directory -Path $projectPath | Out-Null

        @(
            [PSCustomObject]@{
                name = 'AboutProject'
                rootPath = $projectPath
                enabled = $true
            }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        { Invoke-Cdp version $configPath } | Should -Not -Throw

        $about = Show-CdpAbout -ConfigPath $configPath -PassThru
        $about.Name | Should -Be 'cdp'
        $about.Version | Should -Be '2.3.0'
        $about.ConfigPath | Should -Be $configPath
        $about.ProjectCount | Should -Be 1
        $about.EnabledProjectCount | Should -Be 1
        $about.UpgradeCommand | Should -Be 'Update-Module -Name cdp -Scope CurrentUser -Force'
    }

    It 'reports an upgrade command when a newer version is available' {
        InModuleScope cdp {
            $check = Get-CdpUpdateHealthChecks -CurrentVersion ([version]'1.7.0') -LatestVersion ([version]'1.8.0')

            $check.Name | Should -Be 'updates'
            $check.Passed | Should -BeFalse
            $check.Level | Should -Be 'Warning'
            $check.Message | Should -Match '1\.7\.0 -> 1\.8\.0'
            $check.Message | Should -Match 'Update-Module -Name cdp -Scope CurrentUser -Force'
        }
    }

    It 'switches directly when a query has one match' {
        $configPath = Join-Path $TestDrive 'projects.json'
        $statePath = Join-Path $TestDrive 'direct-state.json'
        $apiPath = Join-Path $TestDrive 'ApiProject'
        $webPath = Join-Path $TestDrive 'WebProject'
        New-Item -ItemType Directory -Path $apiPath | Out-Null
        New-Item -ItemType Directory -Path $webPath | Out-Null

        @(
            [PSCustomObject]@{
                name = 'ApiProject'
                rootPath = $apiPath
                enabled = $true
            },
            [PSCustomObject]@{
                name = 'WebProject'
                rootPath = $webPath
                enabled = $true
            }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        $previousStatePath = $env:CDP_STATE_PATH
        $env:CDP_STATE_PATH = $statePath
        Push-Location $TestDrive
        try {
            Invoke-Cdp Api $configPath

            (Get-Location).Path | Should -Be $apiPath
        } finally {
            Pop-Location
            $env:CDP_STATE_PATH = $previousStatePath
        }
    }

    It 'opens a launcher after a successful direct switch' {
        $configPath = Join-Path $TestDrive 'open-projects.json'
        $statePath = Join-Path $TestDrive 'open-state.json'
        $apiPath = Join-Path $TestDrive 'OpenApiProject'
        New-Item -ItemType Directory -Path $apiPath | Out-Null

        @(
            [PSCustomObject]@{
                name = 'OpenApiProject'
                rootPath = $apiPath
                enabled = $true
            }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        $previousStatePath = $env:CDP_STATE_PATH
        $previousDryRun = $env:CDP_OPEN_DRY_RUN
        $env:CDP_STATE_PATH = $statePath
        $env:CDP_OPEN_DRY_RUN = '1'
        Push-Location $TestDrive
        try {
            $result = Invoke-Cdp OpenApi $configPath -Open code

            (Get-Location).Path | Should -Be $apiPath
            $result.ProjectName | Should -Be 'OpenApiProject'
            $result.Command | Should -Be 'code'
            @($result.Arguments)[0] | Should -Be '.'
            $result.WorkingDirectory | Should -Be $apiPath
        } finally {
            Pop-Location
            $env:CDP_STATE_PATH = $previousStatePath
            $env:CDP_OPEN_DRY_RUN = $previousDryRun
        }
    }

    It 'accepts GNU-style --open syntax through Invoke-Cdp' {
        $configPath = Join-Path $TestDrive 'gnu-open-projects.json'
        $statePath = Join-Path $TestDrive 'gnu-open-state.json'
        $apiPath = Join-Path $TestDrive 'GnuOpenApiProject'
        New-Item -ItemType Directory -Path $apiPath | Out-Null

        @(
            [PSCustomObject]@{
                name = 'GnuOpenApiProject'
                rootPath = $apiPath
                enabled = $true
            }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        $previousStatePath = $env:CDP_STATE_PATH
        $previousDryRun = $env:CDP_OPEN_DRY_RUN
        $env:CDP_STATE_PATH = $statePath
        $env:CDP_OPEN_DRY_RUN = '1'
        Push-Location $TestDrive
        try {
            $result = Invoke-Cdp GnuOpen $configPath --open codex

            (Get-Location).Path | Should -Be $apiPath
            $result.Command | Should -Be 'codex'
            $result.Label | Should -Be 'Codex'
        } finally {
            Pop-Location
            $env:CDP_STATE_PATH = $previousStatePath
            $env:CDP_OPEN_DRY_RUN = $previousDryRun
        }
    }

    It 'records recent projects after a successful switch' {
        $configPath = Join-Path $TestDrive 'recent-projects.json'
        $statePath = Join-Path $TestDrive 'state.json'
        $apiPath = Join-Path $TestDrive 'RecentApiProject'
        New-Item -ItemType Directory -Path $apiPath | Out-Null

        @(
            [PSCustomObject]@{
                name = 'RecentApiProject'
                rootPath = $apiPath
                enabled = $true
            }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        $previousStatePath = $env:CDP_STATE_PATH
        $env:CDP_STATE_PATH = $statePath
        Push-Location $TestDrive
        try {
            Invoke-Cdp RecentApi $configPath
            Invoke-Cdp RecentApi $configPath

            $recent = @(Get-CdpRecentProjects -PassThru)
            $recent.Count | Should -Be 1
            $recent[0].name | Should -Be 'RecentApiProject'
            $recent[0].rootPath | Should -Be $apiPath
            $recent[0].visitCount | Should -Be 2
        } finally {
            Pop-Location
            $env:CDP_STATE_PATH = $previousStatePath
        }
    }

    It 'routes cdp recent through Invoke-Cdp' {
        $statePath = Join-Path $TestDrive 'state-route.json'
        $projectPath = Join-Path $TestDrive 'RouteRecentProject'
        New-Item -ItemType Directory -Path $projectPath | Out-Null

        [PSCustomObject]@{
            recentProjects = @(
                [PSCustomObject]@{
                    name = 'RouteRecentProject'
                    rootPath = $projectPath
                    lastVisitedAt = '2026-07-04T00:00:00Z'
                    visitCount = 1
                }
            )
        } | ConvertTo-Json -Depth 4 | Set-Content -Path $statePath -Encoding UTF8

        $previousStatePath = $env:CDP_STATE_PATH
        $env:CDP_STATE_PATH = $statePath
        try {
            { Invoke-Cdp recent 1 } | Should -Not -Throw

            $recent = @(Get-CdpRecentProjects -Count 1 -PassThru)
            $recent.Count | Should -Be 1
            $recent[0].name | Should -Be 'RouteRecentProject'
        } finally {
            $env:CDP_STATE_PATH = $previousStatePath
        }
    }

    It 'refreshes cached project config after adding a project' {
        $configPath = Join-Path $TestDrive 'cached-projects.json'
        $statePath = Join-Path $TestDrive 'cached-state.json'
        $apiPath = Join-Path $TestDrive 'CachedApiProject'
        $webPath = Join-Path $TestDrive 'CachedWebProject'
        New-Item -ItemType Directory -Path $apiPath | Out-Null
        New-Item -ItemType Directory -Path $webPath | Out-Null

        @(
            [PSCustomObject]@{
                name = 'CachedApiProject'
                rootPath = $apiPath
                enabled = $true
            }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        $previousStatePath = $env:CDP_STATE_PATH
        $env:CDP_STATE_PATH = $statePath
        Push-Location $TestDrive
        try {
            Invoke-Cdp CachedApi $configPath
            Add-Project -Name 'CachedWebProject' -Path $webPath -ConfigPath $configPath
            Invoke-Cdp CachedWeb $configPath

            (Get-Location).Path | Should -Be $webPath
        } finally {
            Pop-Location
            $env:CDP_STATE_PATH = $previousStatePath
        }
    }

    It 'imports Git repositories from a scan root' {
        $configPath = Join-Path $TestDrive 'projects.json'
        $scanRoot = Join-Path $TestDrive 'Repos'
        $apiPath = Join-Path $scanRoot 'ApiProject'
        $webPath = Join-Path (Join-Path $scanRoot 'Nested') 'WebProject'
        New-Item -ItemType Directory -Path (Join-Path $apiPath '.git') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $webPath '.git') -Force | Out-Null

        @(
            [PSCustomObject]@{
                name = 'ApiProject'
                rootPath = $apiPath
                enabled = $true
            }
        ) | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8

        $result = Import-GitProjects -RootPath $scanRoot -ConfigPath $configPath -MaxDepth 3 -PassThru -Confirm:$false
        $projects = @(Read-TestProjects -Path $configPath)

        $result.FoundCount | Should -Be 2
        $result.AddedCount | Should -Be 1
        $result.SkippedCount | Should -Be 1
        $projects.Count | Should -Be 2
        $projects.rootPath | Should -Contain $webPath
    }

    It 'routes cdp scan through Invoke-Cdp' {
        $configPath = Join-Path $TestDrive 'scan-route-projects.json'
        $scanRoot = Join-Path $TestDrive 'ScanRoute'
        $repoPath = Join-Path $scanRoot 'RouteProject'
        New-Item -ItemType Directory -Path (Join-Path $repoPath '.git') -Force | Out-Null
        '[]' | Set-Content -Path $configPath -Encoding UTF8

        $previousConfig = $env:CDP_CONFIG
        $env:CDP_CONFIG = $configPath
        try {
            Invoke-Cdp scan $scanRoot --yes
        } finally {
            $env:CDP_CONFIG = $previousConfig
        }

        $projects = @(Read-TestProjects -Path $configPath)
        $projects.Count | Should -Be 1
        $projects[0].rootPath | Should -Be $repoPath
    }
}

Describe 'cdp invocation parser' {
    It 'parses status filters independently of argument order' {
        InModuleScope cdp {
            $configPath = 'C:\Temp\projects.json'
            $first = ConvertFrom-CdpInvokeArguments `
                -Command 'status' `
                -ConfigPath '--dirty' `
                -RemainingArgs @('@work', $configPath)
            $second = ConvertFrom-CdpInvokeArguments `
                -Command 'status' `
                -ConfigPath '@work' `
                -RemainingArgs @($configPath, '--dirty')

            $first.Kind | Should -Be 'status'
            $first.DirtyOnly | Should -BeTrue
            $first.TagFilter | Should -Be '@work'
            $first.ConfigPath | Should -Be $configPath
            $second.DirtyOnly | Should -BeTrue
            $second.TagFilter | Should -Be '@work'
            $second.ConfigPath | Should -Be $configPath
        }
    }

    It 'consumes workspace open options instead of treating them as projects' {
        InModuleScope cdp {
            $parsed = ConvertFrom-CdpInvokeArguments `
                -Command 'workspace' `
                -ConfigPath '--add' `
                -RemainingArgs @('team', 'api', 'web', '--open', 'codex')

            $parsed.Kind | Should -Be 'workspace'
            $parsed.WorkspaceAction | Should -Be 'add'
            $parsed.WorkspaceName | Should -Be 'team'
            @($parsed.Projects) | Should -Be @('api', 'web')
            $parsed.Open | Should -Be 'codex'
        }
    }

    It 'passes custom config paths through management commands' {
        InModuleScope cdp {
            $configPath = 'C:\Temp\projects.json'
            $pin = ConvertFrom-CdpInvokeArguments `
                -Command 'pin' `
                -ConfigPath 'api' `
                -RemainingArgs @($configPath)
            $metadata = ConvertFrom-CdpInvokeArguments `
                -Command 'alias' `
                -ConfigPath 'api' `
                -RemainingArgs @('backend', $configPath)
            $scan = ConvertFrom-CdpInvokeArguments `
                -Command 'scan' `
                -ConfigPath 'C:\Repos' `
                -RemainingArgs @($configPath, '3')

            $pin.Name | Should -Be 'api'
            $pin.ConfigPath | Should -Be $configPath
            $metadata.Name | Should -Be 'api'
            $metadata.Value | Should -Be 'backend'
            $metadata.ConfigPath | Should -Be $configPath
            $scan.RootPath | Should -Be 'C:\Repos'
            $scan.ConfigPath | Should -Be $configPath
            $scan.MaxDepth | Should -Be 3
        }
    }

    It 'rejects conflicting actions and incomplete options' {
        InModuleScope cdp {
            {
                ConvertFrom-CdpInvokeArguments `
                    -Command 'status' `
                    -ConfigPath '--fix' `
                    -RemainingArgs @('--push')
            } | Should -Throw '*cannot be used together*'

            {
                ConvertFrom-CdpInvokeArguments `
                    -Command 'workspace' `
                    -ConfigPath '--add' `
                    -RemainingArgs @('team', '--open')
            } | Should -Throw '*Missing value after --open*'

            {
                ConvertFrom-CdpInvokeArguments `
                    -Command 'status' `
                    -ConfigPath '--unknown'
            } | Should -Throw '*Unknown status option*'

            {
                ConvertFrom-CdpInvokeArguments `
                    -Command 'workspace' `
                    -ConfigPath '--list' `
                    -RemainingArgs @('--open', 'codex')
            } | Should -Throw '*not valid with workspace --list*'
        }
    }

    It 'keeps classic switch syntax compatible' {
        InModuleScope cdp {
            $configPath = 'C:\Temp\projects.json'
            $parsed = ConvertFrom-CdpInvokeArguments `
                -Command 'api' `
                -ConfigPath $configPath `
                -RemainingArgs @('--open', 'codex')

            $parsed.Kind | Should -Be 'switch'
            $parsed.Query | Should -Be 'api'
            $parsed.ConfigPath | Should -Be $configPath
            $parsed.Open | Should -Be 'codex'
        }
    }

    It 'parses hook management and no-hook without stealing a hook project query' {
        InModuleScope cdp {
            $configPath = 'C:\Temp\projects.json'
            $management = ConvertFrom-CdpInvokeArguments `
                -Command 'hook' `
                -ConfigPath 'trust' `
                -RemainingArgs @('api', '--config', $configPath)
            $switch = ConvertFrom-CdpInvokeArguments `
                -Command 'hook' `
                -ConfigPath $configPath `
                -RemainingArgs @('--no-hook')

            $management.Kind | Should -Be 'hook'
            $management.HookAction | Should -Be 'trust'
            $management.Name | Should -Be 'api'
            $management.ConfigPath | Should -Be $configPath
            $switch.Kind | Should -Be 'switch'
            $switch.Query | Should -Be 'hook'
            $switch.NoHook | Should -BeTrue

            {
                ConvertFrom-CdpInvokeArguments `
                    -Command 'api' `
                    -RemainingArgs @('--allow-hook', '--no-hook')
            } | Should -Throw '*cannot be used together*'
        }
    }

    It 'routes hook management to the trust command' {
        InModuleScope cdp {
            Mock Invoke-CdpHookCommand {}
            Invoke-Cdp hook trust api --config 'C:\Temp\projects.json'
            Should -Invoke Invoke-CdpHookCommand -Times 1 -Exactly -ParameterFilter {
                $Action -eq 'trust' -and $Name -eq 'api' -and $ConfigPath -eq 'C:\Temp\projects.json'
            }
        }
    }

    It 'routes combined status filters to the status command' {
        InModuleScope cdp {
            Mock Show-CdpProjectStatus {}
            $configPath = 'C:\Temp\projects.json'

            Invoke-Cdp status --dirty '@work' $configPath

            Should -Invoke Show-CdpProjectStatus -Times 1 -Exactly -ParameterFilter {
                $DirtyOnly -and
                $TagFilter -eq '@work' -and
                $ConfigPath -eq 'C:\Temp\projects.json' -and
                -not $Fix -and
                -not $Push
            }
        }
    }

    It 'routes workspace options without leaking option tokens into projects' {
        InModuleScope cdp {
            Mock Invoke-CdpWorkspace {}

            Invoke-Cdp workspace --add team api web --open codex --config 'C:\Temp\projects.json'

            Should -Invoke Invoke-CdpWorkspace -Times 1 -Exactly -ParameterFilter {
                $Add -eq 'team' -and
                @($Projects).Count -eq 2 -and
                $Projects[0] -eq 'api' -and
                $Projects[1] -eq 'web' -and
                $Open -eq 'codex' -and
                $ConfigPath -eq 'C:\Temp\projects.json'
            }
        }
    }

    It 'routes custom config paths to management commands' {
        InModuleScope cdp {
            Mock Set-ProjectPin {}

            Invoke-Cdp pin api 'C:\Temp\projects.json'

            Should -Invoke Set-ProjectPin -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'api' -and $ConfigPath -eq 'C:\Temp\projects.json'
            }
        }
    }
}

Describe 'cdp project status correctness' {
    It 'recognizes linked Git worktrees' {
        $repoPath = Join-Path $TestDrive 'worktree-source'
        $worktreePath = Join-Path $TestDrive 'linked-worktree'
        New-TestGitRepository -Path $repoPath
        'initial' | Set-Content -LiteralPath (Join-Path $repoPath 'tracked.txt') -Encoding UTF8
        Invoke-TestGit -Path $repoPath -Arguments @('add', 'tracked.txt') | Out-Null
        Invoke-TestGit -Path $repoPath -Arguments @('commit', '--quiet', '-m', 'initial') | Out-Null
        Invoke-TestGit -Path $repoPath -Arguments @('worktree', 'add', '--quiet', '-b', 'linked', $worktreePath) | Out-Null

        $project = [PSCustomObject]@{ name = 'LinkedWorktree'; rootPath = $worktreePath; enabled = $true }
        $status = InModuleScope cdp -Parameters @{ Project = $project } {
            Get-CdpGitProjectInfo -Project $Project
        }

        $status.IsGitRepo | Should -BeTrue
        $status.Branch | Should -Be 'linked'
        $status.StatusLabel | Should -Be 'clean'
    }

    It 'reports tracked and untracked changes together' {
        $repoPath = Join-Path $TestDrive 'mixed-changes'
        New-TestGitRepository -Path $repoPath
        'initial' | Set-Content -LiteralPath (Join-Path $repoPath 'tracked.txt') -Encoding UTF8
        Invoke-TestGit -Path $repoPath -Arguments @('add', 'tracked.txt') | Out-Null
        Invoke-TestGit -Path $repoPath -Arguments @('commit', '--quiet', '-m', 'initial') | Out-Null
        'changed' | Set-Content -LiteralPath (Join-Path $repoPath 'tracked.txt') -Encoding UTF8
        'new' | Set-Content -LiteralPath (Join-Path $repoPath 'untracked.txt') -Encoding UTF8

        $project = [PSCustomObject]@{ name = 'MixedChanges'; rootPath = $repoPath; enabled = $true }
        $status = InModuleScope cdp -Parameters @{ Project = $project } {
            Get-CdpGitProjectInfo -Project $Project
        }

        $status.DirtyCount | Should -Be 1
        $status.UntrackedCount | Should -Be 1
        $status.StatusLabel | Should -Be '1 dirty + 1 untracked'
        $status.NeedsAttention | Should -BeTrue
    }

    It 'reports behind-only repositories as needing attention' {
        $remotePath = Join-Path $TestDrive 'remote.git'
        $seedPath = Join-Path $TestDrive 'seed'
        $followerPath = Join-Path $TestDrive 'follower'
        New-TestGitRepository -Path $seedPath
        'initial' | Set-Content -LiteralPath (Join-Path $seedPath 'tracked.txt') -Encoding UTF8
        Invoke-TestGit -Path $seedPath -Arguments @('add', 'tracked.txt') | Out-Null
        Invoke-TestGit -Path $seedPath -Arguments @('commit', '--quiet', '-m', 'initial') | Out-Null
        & git init --bare --quiet $remotePath
        if ($LASTEXITCODE -ne 0) { throw 'Failed to create test bare remote.' }
        Invoke-TestGit -Path $remotePath -Arguments @('symbolic-ref', 'HEAD', 'refs/heads/main') | Out-Null
        Invoke-TestGit -Path $seedPath -Arguments @('remote', 'add', 'origin', $remotePath) | Out-Null
        Invoke-TestGit -Path $seedPath -Arguments @('push', '--quiet', '-u', 'origin', 'main') | Out-Null
        & git clone --quiet $remotePath $followerPath
        if ($LASTEXITCODE -ne 0) { throw 'Failed to clone test remote.' }
        'second' | Add-Content -LiteralPath (Join-Path $seedPath 'tracked.txt') -Encoding UTF8
        Invoke-TestGit -Path $seedPath -Arguments @('add', 'tracked.txt') | Out-Null
        Invoke-TestGit -Path $seedPath -Arguments @('commit', '--quiet', '-m', 'second') | Out-Null
        Invoke-TestGit -Path $seedPath -Arguments @('push', '--quiet') | Out-Null
        Invoke-TestGit -Path $followerPath -Arguments @('fetch', '--quiet') | Out-Null

        $project = [PSCustomObject]@{ name = 'BehindOnly'; rootPath = $followerPath; enabled = $true }
        $status = InModuleScope cdp -Parameters @{ Project = $project } {
            Get-CdpGitProjectInfo -Project $Project
        }

        $status.DirtyCount | Should -Be 0
        $status.UntrackedCount | Should -Be 0
        $status.BehindCount | Should -Be 1
        $status.NeedsAttention | Should -BeTrue

        Invoke-TestGit -Path $followerPath -Arguments @('config', 'user.email', 'tests@example.invalid') | Out-Null
        Invoke-TestGit -Path $followerPath -Arguments @('config', 'user.name', 'cdp tests') | Out-Null
        'local' | Set-Content -LiteralPath (Join-Path $followerPath 'local.txt') -Encoding UTF8
        Invoke-TestGit -Path $followerPath -Arguments @('add', 'local.txt') | Out-Null
        Invoke-TestGit -Path $followerPath -Arguments @('commit', '--quiet', '-m', 'local') | Out-Null
        $diverged = InModuleScope cdp -Parameters @{ Project = $project } {
            Get-CdpGitProjectInfo -Project $Project
        }
        $diverged.AheadCount | Should -Be 1
        $diverged.BehindCount | Should -Be 1
    }

    It 'keeps disabled missing entries when status fix removes scanned missing projects' {
        $configPath = Join-Path $TestDrive 'status-fix-projects.json'
        $existingPath = Join-Path $TestDrive 'existing-project'
        $missingPath = Join-Path $TestDrive 'shared-missing'
        New-Item -ItemType Directory -Path $existingPath | Out-Null
        @(
            [PSCustomObject]@{ name = 'Existing'; rootPath = $existingPath; enabled = $true },
            [PSCustomObject]@{ name = 'EnabledMissing'; rootPath = $missingPath; enabled = $true },
            [PSCustomObject]@{ name = 'DisabledMissing'; rootPath = $missingPath; enabled = $false }
        ) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configPath -Encoding UTF8

        Show-CdpProjectStatus -ConfigPath $configPath -Fix -Confirm:$false
        $projects = @(Read-TestProjects -Path $configPath)

        $projects.name | Should -Contain 'Existing'
        $projects.name | Should -Not -Contain 'EnabledMissing'
        $projects.name | Should -Contain 'DisabledMissing'
    }

    It 'handles detached and no-upstream repositories without false sync counts' {
        $repoPath = Join-Path $TestDrive 'detached-repo'
        New-TestGitRepository -Path $repoPath
        'initial' | Set-Content -LiteralPath (Join-Path $repoPath 'tracked.txt') -Encoding UTF8
        Invoke-TestGit -Path $repoPath -Arguments @('add', 'tracked.txt') | Out-Null
        Invoke-TestGit -Path $repoPath -Arguments @('commit', '--quiet', '-m', 'initial') | Out-Null
        Invoke-TestGit -Path $repoPath -Arguments @('checkout', '--quiet', '--detach') | Out-Null

        $project = [PSCustomObject]@{ name = 'Detached'; rootPath = $repoPath; enabled = $true }
        $status = InModuleScope cdp -Parameters @{ Project = $project } {
            Get-CdpGitProjectInfo -Project $Project
        }

        $status.IsGitRepo | Should -BeTrue
        $status.Branch | Should -Not -BeNullOrEmpty
        $status.AheadCount | Should -Be 0
        $status.BehindCount | Should -Be 0
    }

    It 'distinguishes missing paths and non-Git directories' {
        $plainPath = Join-Path $TestDrive 'plain-directory'
        New-Item -ItemType Directory -Path $plainPath | Out-Null
        $plain = [PSCustomObject]@{ name = 'Plain'; rootPath = $plainPath; enabled = $true }
        $missing = [PSCustomObject]@{ name = 'Missing'; rootPath = (Join-Path $TestDrive 'missing'); enabled = $true }

        $plainStatus = InModuleScope cdp -Parameters @{ Project = $plain } { Get-CdpGitProjectInfo -Project $Project }
        $missingStatus = InModuleScope cdp -Parameters @{ Project = $missing } { Get-CdpGitProjectInfo -Project $Project }

        $plainStatus.IsGitRepo | Should -BeFalse
        $plainStatus.StatusLabel | Should -Be 'not a git repo'
        $missingStatus.PathExists | Should -BeFalse
        $missingStatus.StatusLabel | Should -Be 'path missing'
    }
}
