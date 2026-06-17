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
}

Describe 'cdp module manifest' {
    It 'has a valid manifest' {
        $manifest = Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop

        $manifest.Name | Should -Be 'cdp'
        $manifest.Version.ToString() | Should -Be '1.5.0'
    }
}

Describe 'cdp public surface' {
    It 'exports the expected commands' {
        $commandNames = (Get-Command -Module cdp).Name

        $commandNames | Should -Contain 'Invoke-Cdp'
        $commandNames | Should -Contain 'Switch-Project'
        $commandNames | Should -Contain 'Get-ProjectList'
        $commandNames | Should -Contain 'Add-Project'
        $commandNames | Should -Contain 'Import-GitProjects'
        $commandNames | Should -Contain 'Remove-Project'
        $commandNames | Should -Contain 'Edit-ProjectConfig'
        $commandNames | Should -Contain 'Set-ProjectConfig'
        $commandNames | Should -Contain 'Test-ProjectHealth'
        $commandNames | Should -Contain 'Show-CdpAbout'
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
        $about.Version | Should -Be '1.5.0'
        $about.ConfigPath | Should -Be $configPath
        $about.ProjectCount | Should -Be 1
        $about.EnabledProjectCount | Should -Be 1
        $about.UpgradeCommand | Should -Be 'Update-Module -Name cdp -Scope CurrentUser -Force'
    }

    It 'reports an upgrade command when a newer version is available' {
        InModuleScope cdp {
            $check = Get-CdpUpdateHealthChecks -CurrentVersion ([version]'1.4.1') -LatestVersion ([version]'1.5.0')

            $check.Name | Should -Be 'updates'
            $check.Passed | Should -BeFalse
            $check.Level | Should -Be 'Warning'
            $check.Message | Should -Match '1\.4\.1 -> 1\.5\.0'
            $check.Message | Should -Match 'Update-Module -Name cdp -Scope CurrentUser -Force'
        }
    }

    It 'switches directly when a query has one match' {
        $configPath = Join-Path $TestDrive 'projects.json'
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

        Push-Location $TestDrive
        try {
            Invoke-Cdp Api $configPath

            (Get-Location).Path | Should -Be $apiPath
        } finally {
            Pop-Location
        }
    }

    It 'refreshes cached project config after adding a project' {
        $configPath = Join-Path $TestDrive 'cached-projects.json'
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

        Push-Location $TestDrive
        try {
            Invoke-Cdp CachedApi $configPath
            Add-Project -Name 'CachedWebProject' -Path $webPath -ConfigPath $configPath
            Invoke-Cdp CachedWeb $configPath

            (Get-Location).Path | Should -Be $webPath
        } finally {
            Pop-Location
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

        $result = Import-GitProjects -RootPath $scanRoot -ConfigPath $configPath -MaxDepth 3 -PassThru
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
            Invoke-Cdp scan $scanRoot
        } finally {
            $env:CDP_CONFIG = $previousConfig
        }

        $projects = @(Read-TestProjects -Path $configPath)
        $projects.Count | Should -Be 1
        $projects[0].rootPath | Should -Be $repoPath
    }
}
