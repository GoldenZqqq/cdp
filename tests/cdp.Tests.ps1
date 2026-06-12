BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ManifestPath = Join-Path $script:RepoRoot 'cdp.psd1'
    Import-Module $script:ManifestPath -Force
}

Describe 'cdp module manifest' {
    It 'has a valid manifest' {
        $manifest = Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop

        $manifest.Name | Should -Be 'cdp'
        $manifest.Version.ToString() | Should -Be '1.3.0'
    }
}

Describe 'cdp public surface' {
    It 'exports the expected commands' {
        $commandNames = (Get-Command -Module cdp).Name

        $commandNames | Should -Contain 'Invoke-Cdp'
        $commandNames | Should -Contain 'Switch-Project'
        $commandNames | Should -Contain 'Get-ProjectList'
        $commandNames | Should -Contain 'Add-Project'
        $commandNames | Should -Contain 'Remove-Project'
        $commandNames | Should -Contain 'Edit-ProjectConfig'
        $commandNames | Should -Contain 'Set-ProjectConfig'
        $commandNames | Should -Contain 'Test-ProjectHealth'
    }

    It 'exports the expected aliases' {
        (Get-Alias cdp).Definition | Should -Be 'Invoke-Cdp'
        (Get-Alias cdp-add).Definition | Should -Be 'Add-Project'
        (Get-Alias cdp-rm).Definition | Should -Be 'Remove-Project'
        (Get-Alias cdp-ls).Definition | Should -Be 'Get-ProjectList'
        (Get-Alias cdp-edit).Definition | Should -Be 'Edit-ProjectConfig'
        (Get-Alias cdp-config).Definition | Should -Be 'Set-ProjectConfig'
        (Get-Alias cdp-doctor).Definition | Should -Be 'Test-ProjectHealth'
    }
}

Describe 'project configuration helpers' {
    It 'adds a project to a custom config file' {
        $configPath = Join-Path $TestDrive 'projects.json'
        $projectPath = Join-Path $TestDrive 'ExampleProject'
        New-Item -ItemType Directory -Path $projectPath | Out-Null
        '[]' | Set-Content -Path $configPath -Encoding UTF8

        Add-Project -Name 'ExampleProject' -Path $projectPath -ConfigPath $configPath

        $projects = @(Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json)
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

        $health = Test-ProjectHealth -ConfigPath $configPath -PassThru

        $health.ConfigPath | Should -Be $configPath
        $health.ProjectCount | Should -Be 2
        $health.EnabledProjectCount | Should -Be 1
        $health.MissingPathCount | Should -Be 0
    }

    It 'routes cdp doctor through Invoke-Cdp' {
        $configPath = Join-Path $TestDrive 'projects.json'
        '[]' | Set-Content -Path $configPath -Encoding UTF8

        { Invoke-Cdp doctor $configPath } | Should -Not -Throw
    }
}
