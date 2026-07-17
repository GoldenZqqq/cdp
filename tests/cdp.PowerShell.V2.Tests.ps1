BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ManifestPath = Join-Path $script:RepoRoot 'cdp.psd1'
    Import-Module $script:ManifestPath -Force

    function Invoke-TestGitV2 {
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

    function New-TestGitRepositoryV2 {
        param([Parameter(Mandatory = $true)][string]$Path)

        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Invoke-TestGitV2 -Path $Path -Arguments @('init', '--quiet', '-b', 'main') | Out-Null
        Invoke-TestGitV2 -Path $Path -Arguments @('config', 'user.email', 'tests@example.invalid') | Out-Null
        Invoke-TestGitV2 -Path $Path -Arguments @('config', 'user.name', 'cdp tests') | Out-Null
    }

    function New-TestUpstreamFixtureV2 {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [Parameter(Mandatory = $true)]
            [string]$Name
        )

        $repoPath = Join-Path $Root $Name
        $remotePath = Join-Path $Root "$Name.git"
        New-TestGitRepositoryV2 -Path $repoPath
        'initial' | Set-Content -LiteralPath (Join-Path $repoPath 'tracked.txt') -Encoding UTF8
        Invoke-TestGitV2 -Path $repoPath -Arguments @('add', 'tracked.txt') | Out-Null
        Invoke-TestGitV2 -Path $repoPath -Arguments @('commit', '--quiet', '-m', 'initial') | Out-Null
        & git init --bare --quiet $remotePath
        if ($LASTEXITCODE -ne 0) { throw "Failed to create bare remote: $remotePath" }
        Invoke-TestGitV2 -Path $remotePath -Arguments @('symbolic-ref', 'HEAD', 'refs/heads/main') | Out-Null
        Invoke-TestGitV2 -Path $repoPath -Arguments @('remote', 'add', 'origin', $remotePath) | Out-Null
        Invoke-TestGitV2 -Path $repoPath -Arguments @('push', '--quiet', '-u', 'origin', 'main') | Out-Null

        [PSCustomObject]@{
            RepositoryPath = $repoPath
            RemotePath = $remotePath
        }
    }

    function Write-TestConfigV2 {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [object[]]$Projects
        )

        ConvertTo-Json -InputObject @($Projects) -Depth 6 |
            Set-Content -LiteralPath $Path -Encoding UTF8
    }
}

Describe 'cdp v2 status filters and actions' {
    It 'filters structured status results by tag and attention state' {
        $dirtyFixture = New-TestUpstreamFixtureV2 -Root $TestDrive -Name 'dirty-repo'
        $cleanPath = Join-Path $TestDrive 'clean-repo'
        New-TestGitRepositoryV2 -Path $cleanPath
        'initial' | Set-Content -LiteralPath (Join-Path $cleanPath 'tracked.txt') -Encoding UTF8
        Invoke-TestGitV2 -Path $cleanPath -Arguments @('add', 'tracked.txt') | Out-Null
        Invoke-TestGitV2 -Path $cleanPath -Arguments @('commit', '--quiet', '-m', 'initial') | Out-Null
        'changed' | Set-Content -LiteralPath (Join-Path $dirtyFixture.RepositoryPath 'tracked.txt') -Encoding UTF8

        $configPath = Join-Path $TestDrive 'status-filter-projects.json'
        Write-TestConfigV2 -Path $configPath -Projects @(
            [PSCustomObject]@{
                name = 'DirtyWork'
                rootPath = $dirtyFixture.RepositoryPath
                enabled = $true
                tags = @('work')
            },
            [PSCustomObject]@{
                name = 'CleanPersonal'
                rootPath = $cleanPath
                enabled = $true
                tags = @('personal')
            }
        )

        $tagged = @(Show-CdpProjectStatus -ConfigPath $configPath -TagFilter '@work' -PassThru)
        $attention = @(Show-CdpProjectStatus -ConfigPath $configPath -DirtyOnly -PassThru)

        $tagged.Count | Should -Be 1
        $tagged[0].Name | Should -Be 'DirtyWork'
        $attention.Count | Should -Be 1
        $attention[0].Name | Should -Be 'DirtyWork'
        $attention[0].NeedsAttention | Should -BeTrue
    }

    It 'pushes only repositories with an upstream-derived ahead count' {
        $aheadFixture = New-TestUpstreamFixtureV2 -Root $TestDrive -Name 'ahead-repo'
        $standalonePath = Join-Path $TestDrive 'standalone-repo'
        New-TestGitRepositoryV2 -Path $standalonePath
        'initial' | Set-Content -LiteralPath (Join-Path $standalonePath 'tracked.txt') -Encoding UTF8
        Invoke-TestGitV2 -Path $standalonePath -Arguments @('add', 'tracked.txt') | Out-Null
        Invoke-TestGitV2 -Path $standalonePath -Arguments @('commit', '--quiet', '-m', 'initial') | Out-Null

        'ahead' | Add-Content -LiteralPath (Join-Path $aheadFixture.RepositoryPath 'tracked.txt') -Encoding UTF8
        Invoke-TestGitV2 -Path $aheadFixture.RepositoryPath -Arguments @('add', 'tracked.txt') | Out-Null
        Invoke-TestGitV2 -Path $aheadFixture.RepositoryPath -Arguments @('commit', '--quiet', '-m', 'ahead') | Out-Null
        $remoteBefore = Invoke-TestGitV2 -Path $aheadFixture.RemotePath -Arguments @('rev-parse', 'refs/heads/main')

        $configPath = Join-Path $TestDrive 'status-push-projects.json'
        Write-TestConfigV2 -Path $configPath -Projects @(
            [PSCustomObject]@{ name = 'Ahead'; rootPath = $aheadFixture.RepositoryPath; enabled = $true },
            [PSCustomObject]@{ name = 'NoUpstream'; rootPath = $standalonePath; enabled = $true }
        )

        $output = @(& { Show-CdpProjectStatus -ConfigPath $configPath -Push } 6>&1) -join [Environment]::NewLine

        $remoteAfter = Invoke-TestGitV2 -Path $aheadFixture.RemotePath -Arguments @('rev-parse', 'refs/heads/main')
        $localHead = Invoke-TestGitV2 -Path $aheadFixture.RepositoryPath -Arguments @('rev-parse', 'HEAD')
        $remoteAfter | Should -Not -Be $remoteBefore
        $remoteAfter | Should -Be $localHead
        $output | Should -Match '\bdone\b'
        $output | Should -Not -Match 'failed:'
    }

    It 'reports a failed native push instead of printing done' {
        $fixture = New-TestUpstreamFixtureV2 -Root $TestDrive -Name 'failed-push-repo'
        'ahead' | Add-Content -LiteralPath (Join-Path $fixture.RepositoryPath 'tracked.txt') -Encoding UTF8
        Invoke-TestGitV2 -Path $fixture.RepositoryPath -Arguments @('add', 'tracked.txt') | Out-Null
        Invoke-TestGitV2 -Path $fixture.RepositoryPath -Arguments @('commit', '--quiet', '-m', 'ahead') | Out-Null
        Invoke-TestGitV2 -Path $fixture.RepositoryPath -Arguments @(
            'remote', 'set-url', 'origin', (Join-Path $TestDrive 'unavailable-remote.git')
        ) | Out-Null

        $configPath = Join-Path $TestDrive 'failed-push-projects.json'
        Write-TestConfigV2 -Path $configPath -Projects @(
            [PSCustomObject]@{ name = 'FailedPush'; rootPath = $fixture.RepositoryPath; enabled = $true }
        )

        $output = @(& { Show-CdpProjectStatus -ConfigPath $configPath -Push } 6>&1) -join [Environment]::NewLine

        $output | Should -Match 'failed:'
        $output | Should -Not -Match '\bdone\b'
    }
}

Describe 'cdp v2 workspace behavior' {
    It 'persists and lists workspace projects with a default launcher' {
        $configPath = Join-Path $TestDrive 'workspace-projects.json'
        $workspacesPath = Join-Path $TestDrive 'workspaces.json'
        '[]' | Set-Content -LiteralPath $configPath -Encoding UTF8

        Invoke-CdpWorkspace -Add 'fullstack' -Projects @('api', 'web') -Open 'codex' -ConfigPath $configPath
        $output = @(& { Invoke-CdpWorkspace -List -ConfigPath $configPath } 6>&1) -join [Environment]::NewLine
        $workspaces = @(ConvertFrom-Json -InputObject (Get-Content -LiteralPath $workspacesPath -Raw -Encoding UTF8))

        $workspaces.Count | Should -Be 1
        $workspaces[0].name | Should -Be 'fullstack'
        @($workspaces[0].projects) | Should -Be @('api', 'web')
        $workspaces[0].open | Should -Be 'codex'
        $output | Should -Match 'fullstack'
        $output | Should -Match '\[codex\]'
    }

    It 'launches existing projects with spaced paths and skips missing entries' {
        $configPath = Join-Path $TestDrive 'launch-projects.json'
        $projectPath = Join-Path $TestDrive 'project with spaces'
        $missingPath = Join-Path $TestDrive 'missing project'
        New-Item -ItemType Directory -Path $projectPath | Out-Null
        Write-TestConfigV2 -Path $configPath -Projects @(
            [PSCustomObject]@{ name = 'Api'; rootPath = $projectPath; enabled = $true },
            [PSCustomObject]@{ name = 'Missing'; rootPath = $missingPath; enabled = $true }
        )
        @(
            [PSCustomObject]@{ name = 'team'; projects = @('Api', 'Missing', 'Unknown'); open = 'code' }
        ) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Encoding UTF8

        InModuleScope cdp -Parameters @{ ConfigPath = $configPath; ProjectPath = $projectPath } {
            Mock Get-Command { [PSCustomObject]@{ Name = 'wt.exe' } } -ParameterFilter { $Name -eq 'wt.exe' }
            Mock Start-Process {}

            $output = @(& {
                Invoke-CdpWorkspace -Name 'team' -Open 'codex' -ConfigPath $ConfigPath
            } 6>&1) -join [Environment]::NewLine

            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq 'wt.exe' -and
                @($ArgumentList).Count -eq 12 -and
                $ArgumentList[4] -eq $ProjectPath -and
                $ArgumentList[6] -eq 'Api' -and
                $ArgumentList[11] -match [regex]::Escape($ProjectPath) -and
                $ArgumentList[11] -match 'codex'
            }
            $output | Should -Match "Path missing for 'Missing'"
            $output | Should -Match "Project 'Unknown' not found"
        }
    }
}

Describe 'cdp v2 onEnter isolation' {
    It 'applies env values and a controlled PowerShell hook' {
        $previousEnv = $env:CDP_TEST_ONENTER_ENV
        $previousPowerShell = $env:CDP_TEST_ONENTER_PS
        $project = [PSCustomObject]@{
            onEnter = [PSCustomObject]@{
                env = [PSCustomObject]@{ CDP_TEST_ONENTER_ENV = 'enabled' }
                powershell = '$env:CDP_TEST_ONENTER_PS = "ran"'
            }
        }

        try {
            InModuleScope cdp -Parameters @{ Project = $project } {
                Invoke-CdpOnEnter -Project $Project
            }

            $env:CDP_TEST_ONENTER_ENV | Should -Be 'enabled'
            $env:CDP_TEST_ONENTER_PS | Should -Be 'ran'
        } finally {
            $env:CDP_TEST_ONENTER_ENV = $previousEnv
            $env:CDP_TEST_ONENTER_PS = $previousPowerShell
        }
    }

    It 'supports a controlled legacy string hook' {
        $previousValue = $env:CDP_TEST_ONENTER_LEGACY
        $project = [PSCustomObject]@{
            onEnter = '$env:CDP_TEST_ONENTER_LEGACY = "ran"'
        }

        try {
            InModuleScope cdp -Parameters @{ Project = $project } {
                Invoke-CdpOnEnter -Project $Project
            }
            $env:CDP_TEST_ONENTER_LEGACY | Should -Be 'ran'
        } finally {
            $env:CDP_TEST_ONENTER_LEGACY = $previousValue
        }
    }

    It 'isolates hook failures and returns a warning' {
        $project = [PSCustomObject]@{
            onEnter = [PSCustomObject]@{ powershell = 'throw "expected hook failure"' }
        }

        $output = InModuleScope cdp -Parameters @{ Project = $project } {
            @(& { Invoke-CdpOnEnter -Project $Project } 6>&1) -join [Environment]::NewLine
        }

        $output | Should -Match 'onEnter warning: expected hook failure'
    }
}

Describe 'cdp v2 argument completers' {
    It 'completes subcommands and launcher names' {
        $commandLine = 'Invoke-Cdp st'
        $commandMatches = @(TabExpansion2 $commandLine $commandLine.Length).CompletionMatches.CompletionText
        $launcherLine = 'Invoke-Cdp api -Open co'
        $launcherMatches = @(TabExpansion2 $launcherLine $launcherLine.Length).CompletionMatches.CompletionText

        $commandMatches | Should -Contain 'status'
        $launcherMatches | Should -Contain 'code'
        $launcherMatches | Should -Contain 'codex'
    }

    It 'completes enabled project names from an isolated config' {
        $configPath = Join-Path $TestDrive 'completion-projects.json'
        Write-TestConfigV2 -Path $configPath -Projects @(
            [PSCustomObject]@{ name = 'V2ApiProject'; rootPath = $TestDrive; enabled = $true },
            [PSCustomObject]@{ name = 'V2HiddenProject'; rootPath = $TestDrive; enabled = $false }
        )
        $previousConfig = $env:CDP_CONFIG
        $env:CDP_CONFIG = $configPath

        try {
            InModuleScope cdp -Parameters @{ ConfigPath = $configPath } {
                Clear-CdpProjectConfigCache -ConfigPath $ConfigPath
            }
            $line = 'Invoke-Cdp V2'
            $matches = @(TabExpansion2 $line $line.Length).CompletionMatches.CompletionText

            $matches | Should -Contain 'V2ApiProject'
            $matches | Should -Not -Contain 'V2HiddenProject'
        } finally {
            $env:CDP_CONFIG = $previousConfig
            InModuleScope cdp -Parameters @{ ConfigPath = $configPath } {
                Clear-CdpProjectConfigCache -ConfigPath $ConfigPath
            }
        }
    }
}
