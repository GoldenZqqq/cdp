BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ManifestPath = Join-Path $script:RepoRoot 'cdp.psd1'
    $script:FixturePath = Join-Path $script:RepoRoot 'tests/fixtures/path-profiles.json'
    Import-Module $script:ManifestPath -Force
}

Describe 'cdp path profile resolver' {
    It 'selects the same explicit mapping for all supported profiles' {
        $projects = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $script:FixturePath -Raw -Encoding UTF8)
        InModuleScope cdp -Parameters @{ Project = $projects[0] } {
            (Resolve-CdpProjectPath -Project $Project -Profile windows).ResolvedPath | Should -Be 'C:/Work/api'
            (Resolve-CdpProjectPath -Project $Project -Profile wsl).ResolvedPath | Should -Be '/home/dev/api'
            (Resolve-CdpProjectPath -Project $Project -Profile linux).ResolvedPath | Should -Be '/srv/dev/api'
            (Resolve-CdpProjectPath -Project $Project -Profile macos).ResolvedPath | Should -Be '/Users/dev/api'
        }
    }

    It 'keeps legacy rootPath fallback and WSL conversion compatible' {
        $projects = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $script:FixturePath -Raw -Encoding UTF8)
        InModuleScope cdp -Parameters @{ Project = $projects[1] } {
            $linux = Resolve-CdpProjectPath -Project $Project -Profile linux
            $wsl = Resolve-CdpProjectPath -Project $Project -Profile wsl
            $linux.ResolvedPath | Should -Be 'D:/Code/legacy'
            $linux.Source | Should -Be 'rootPath'
            $wsl.ResolvedPath | Should -Be '/mnt/d/Code/legacy'
            $wsl.Source | Should -Be 'rootPath:wsl-converted'
        }
    }

    It 'never falls back when an explicit current mapping is invalid' {
        $projects = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $script:FixturePath -Raw -Encoding UTF8)
        InModuleScope cdp -Parameters @{ Project = $projects[2] } {
            $resolution = Resolve-CdpProjectPath -Project $Project -Profile linux
            $resolution.IsExplicit | Should -BeTrue
            $resolution.ResolvedPath | Should -BeNullOrEmpty
            $resolution.ErrorCode | Should -Be 'path_profile_invalid'
        }
    }

    It 'supports a case-insensitive environment override and rejects invalid values' {
        InModuleScope cdp {
            $original = $env:CDP_PATH_PROFILE
            try {
                $env:CDP_PATH_PROFILE = 'MaCoS'
                Get-CdpCurrentPathProfile | Should -Be 'macos'
                $env:CDP_PATH_PROFILE = 'solaris'
                { Get-CdpCurrentPathProfile } | Should -Throw '*Invalid CDP_PATH_PROFILE*'
            } finally {
                $env:CDP_PATH_PROFILE = $original
            }
        }
    }

    It 'creates a backward-compatible rootPath plus the current profile mapping' {
        InModuleScope cdp {
            $map = New-CdpProjectPathMap -RootPath '/work/api' -Profile linux
            $map.linux | Should -Be '/work/api'
        }
    }
}

Describe 'cdp path profile integrations' {
    BeforeEach {
        $script:OriginalPathProfile = $env:CDP_PATH_PROFILE
        $env:CDP_PATH_PROFILE = 'linux'
    }

    AfterEach {
        $env:CDP_PATH_PROFILE = $script:OriginalPathProfile
    }

    It 'writes rootPath and the current profile from Add-Project' {
        $configPath = Join-Path $TestDrive 'add-projects.json'
        $projectPath = Join-Path $TestDrive 'added'
        New-Item -ItemType Directory -Path $projectPath | Out-Null

        Add-Project -Name Added -Path $projectPath -ConfigPath $configPath -Confirm:$false | Out-Null
        $project = (ConvertFrom-Json -InputObject (Get-Content -LiteralPath $configPath -Raw -Encoding UTF8))[0]

        $project.rootPath | Should -Be $projectPath
        $project.paths.linux | Should -Be $projectPath
    }

    It 'does not duplicate a local path already declared by another raw identity' {
        $configPath = Join-Path $TestDrive 'mapped-existing.json'
        $projectPath = Join-Path $TestDrive 'mapped-existing'
        New-Item -ItemType Directory -Path $projectPath | Out-Null
        @([PSCustomObject]@{
            name = 'Existing'; rootPath = 'C:/Work/existing'; enabled = $true
            paths = [PSCustomObject]@{ linux = $projectPath }
        }) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8

        Add-Project -Name Duplicate -Path $projectPath -ConfigPath $configPath -Confirm:$false | Out-Null
        (ConvertFrom-Json -InputObject (Get-Content -LiteralPath $configPath -Raw -Encoding UTF8)).Count | Should -Be 1
    }

    It 'uses resolved paths for status JSON while preserving raw identity' {
        $rawPath = 'C:/Unavailable/api'
        $resolvedPath = Join-Path $TestDrive 'status-api'
        New-Item -ItemType Directory -Path $resolvedPath | Out-Null
        $project = [PSCustomObject]@{
            name = 'Api'; rootPath = $rawPath; enabled = $true
            paths = [PSCustomObject]@{ linux = $resolvedPath }
        }
        $configPath = Join-Path $TestDrive 'resolved-status.json'
        @($project) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8

        InModuleScope cdp -Parameters @{ Project = $project } {
            $info = Get-CdpGitProjectInfo -Project $Project
            $json = ConvertTo-CdpStatusProject -Info $info
            $json.rawPath | Should -Be 'C:/Unavailable/api'
            $json.resolvedPath | Should -Be $Project.paths.linux
            $info.PathExists | Should -BeTrue
        }

        $document = (Show-CdpProjectStatus -ConfigPath $configPath -Json | Out-String) | ConvertFrom-Json
        $document.projects[0].rawPath | Should -Be $rawPath
        $document.projects[0].resolvedPath | Should -Be $resolvedPath
    }

    It 'keeps unavailable explicit paths during repair and status fix' {
        $configPath = Join-Path $TestDrive 'explicit-missing.json'
        @([PSCustomObject]@{
            name = 'Shared'; rootPath = 'C:/Work/shared'; enabled = $true; pinned = $false
            aliases = @(); tags = @(); paths = [PSCustomObject]@{ linux = (Join-Path $TestDrive 'missing-linux') }
            futureField = 'keep-me'
        }) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8

        Add-ProjectTag -Name Shared -Tag profile-test -ConfigPath $configPath -Confirm:$false | Out-Null
        Repair-ProjectConfig -ConfigPath $configPath -Confirm:$false | Out-Null
        Show-CdpProjectStatus -ConfigPath $configPath -Fix -Confirm:$false 6>&1 | Out-Null
        $project = (ConvertFrom-Json -InputObject (Get-Content -LiteralPath $configPath -Raw -Encoding UTF8))[0]

        $project.enabled | Should -BeTrue
        $project.paths.linux | Should -Be (Join-Path $TestDrive 'missing-linux')
        $project.futureField | Should -Be 'keep-me'
        @($project.tags) | Should -Contain 'profile-test'
    }

    It 'removes status-fix targets by name plus raw path instead of raw path alone' {
        $configPath = Join-Path $TestDrive 'shared-raw-identity.json'
        $existingPath = Join-Path $TestDrive 'shared-raw-existing'
        New-Item -ItemType Directory -Path $existingPath | Out-Null
        @(
            [PSCustomObject]@{ name = 'LegacyMissing'; rootPath = 'C:/Shared/raw'; enabled = $true },
            [PSCustomObject]@{
                name = 'ExplicitExisting'; rootPath = 'C:/Shared/raw'; enabled = $true
                paths = [PSCustomObject]@{ linux = $existingPath }
            }
        ) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8

        Show-CdpProjectStatus -ConfigPath $configPath -Fix -Confirm:$false 6>&1 | Out-Null
        $projects = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $configPath -Raw -Encoding UTF8)
        @($projects.name) | Should -Be @('ExplicitExisting')
    }

    It 'resolves launcher working directories without rewriting raw paths' {
        $project = [PSCustomObject]@{
            name = 'Api'; rootPath = 'C:/Work/api'
            paths = [PSCustomObject]@{ linux = '/srv/api' }
        }
        InModuleScope cdp -Parameters @{ Project = $project } {
            $original = $env:CDP_OPEN_DRY_RUN
            try {
                $env:CDP_OPEN_DRY_RUN = '1'
                $result = Invoke-CdpWorkspaceLauncher -Project $Project -Open codex
                $result.WorkingDirectory | Should -Be '/srv/api'
            } finally {
                $env:CDP_OPEN_DRY_RUN = $original
            }
        }
    }

    It 'uses fatal JSON diagnostics for an invalid environment override' {
        $configPath = Join-Path $TestDrive 'empty.json'
        '[]' | Set-Content -LiteralPath $configPath -Encoding UTF8
        $env:CDP_PATH_PROFILE = 'solaris'

        $output = Show-CdpProjectStatus -ConfigPath $configPath -Json
        $output | Should -BeNullOrEmpty
        $global:LASTEXITCODE | Should -Be 3
    }

    It 'reports an invalid explicit profile as stable status JSON attention' {
        $configPath = Join-Path $TestDrive 'invalid-profile.json'
        @([PSCustomObject]@{
            name = 'Invalid'; rootPath = 'C:/Work/invalid'; enabled = $true
            paths = [PSCustomObject]@{ linux = '' }
        }) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8

        $document = (Show-CdpProjectStatus -ConfigPath $configPath -Json | Out-String) | ConvertFrom-Json
        $document.summary.exitCode | Should -Be 1
        $document.projects[0].status | Should -Be 'path_profile_invalid'
        @($document.projects[0].attentionReasons) | Should -Be @('path_profile_invalid')
        $document.projects[0].rawPath | Should -Be 'C:/Work/invalid'
        $document.projects[0].resolvedPath | Should -BeNullOrEmpty

        Show-CdpProjectStatus -ConfigPath $configPath -Fix -Confirm:$false 6>&1 | Out-Null
        (ConvertFrom-Json -InputObject (Get-Content -LiteralPath $configPath -Raw -Encoding UTF8)).Count | Should -Be 1
    }
}
