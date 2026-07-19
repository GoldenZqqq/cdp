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

        $output = @(& { Show-CdpProjectStatus -ConfigPath $configPath -Push -Confirm:$false } 6>&1) -join [Environment]::NewLine

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

        $output = @(& { Show-CdpProjectStatus -ConfigPath $configPath -Push -Confirm:$false } 6>&1) -join [Environment]::NewLine

        $output | Should -Match 'failed:'
        $output | Should -Not -Match '\bdone\b'
    }

    It 'continues later pushes and returns per-target results after a failure' {
        $failedFixture = New-TestUpstreamFixtureV2 -Root $TestDrive -Name 'batch-failed'
        $successFixture = New-TestUpstreamFixtureV2 -Root $TestDrive -Name 'batch-success'
        foreach ($fixture in @($failedFixture, $successFixture)) {
            'ahead' | Add-Content -LiteralPath (Join-Path $fixture.RepositoryPath 'tracked.txt') -Encoding UTF8
            Invoke-TestGitV2 -Path $fixture.RepositoryPath -Arguments @('add', 'tracked.txt') | Out-Null
            Invoke-TestGitV2 -Path $fixture.RepositoryPath -Arguments @('commit', '--quiet', '-m', 'ahead') | Out-Null
        }
        Invoke-TestGitV2 -Path $failedFixture.RepositoryPath -Arguments @(
            'remote', 'set-url', 'origin', (Join-Path $TestDrive 'batch-unavailable.git')
        ) | Out-Null
        $successBefore = Invoke-TestGitV2 -Path $successFixture.RemotePath -Arguments @('rev-parse', 'refs/heads/main')

        $configPath = Join-Path $TestDrive 'batch-push-projects.json'
        Write-TestConfigV2 -Path $configPath -Projects @(
            [PSCustomObject]@{ name = 'Failed'; rootPath = $failedFixture.RepositoryPath; enabled = $true },
            [PSCustomObject]@{ name = 'Success'; rootPath = $successFixture.RepositoryPath; enabled = $true }
        )

        $results = @(Show-CdpProjectStatus -ConfigPath $configPath -Push -Confirm:$false -PassThru)

        $successAfter = Invoke-TestGitV2 -Path $successFixture.RemotePath -Arguments @('rev-parse', 'refs/heads/main')
        $results.Count | Should -Be 2
        @($results | Where-Object Status -eq failed).Target | Should -Be @('Failed')
        @($results | Where-Object Status -eq succeeded).Target | Should -Be @('Success')
        $successAfter | Should -Not -Be $successBefore
    }

    It 'does not mutate status targets during a dry run' {
        $configPath = Join-Path $TestDrive 'status-dry-run-projects.json'
        Write-TestConfigV2 -Path $configPath -Projects @(
            [PSCustomObject]@{
                name = 'Missing'
                rootPath = (Join-Path $TestDrive 'missing-dry-run')
                enabled = $true
            }
        )
        $before = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8

        Show-CdpProjectStatus -ConfigPath $configPath -Fix -WhatIf

        (Get-Content -LiteralPath $configPath -Raw -Encoding UTF8) | Should -BeExactly $before
    }

    It 'parses explicit status safety options' {
        InModuleScope cdp {
            $dryRun = ConvertFrom-CdpInvokeArguments `
                -Command 'status' `
                -ConfigPath '--fix' `
                -RemainingArgs @('--dry-run', 'C:\Temp\projects.json')
            $confirmed = ConvertFrom-CdpInvokeArguments `
                -Command 'status' `
                -ConfigPath '--push' `
                -RemainingArgs @('--yes', 'C:\Temp\projects.json')

            $dryRun.Fix | Should -BeTrue
            $dryRun.DryRun | Should -BeTrue
            $confirmed.Push | Should -BeTrue
            $confirmed.Yes | Should -BeTrue
        }
    }
}

Describe 'cdp v2 workspace behavior' {
    It 'persists and lists workspace projects with a default launcher' {
        $configPath = Join-Path $TestDrive 'workspace-projects.json'
        $workspacesPath = Join-Path $TestDrive 'workspaces.json'
        $apiPath = Join-Path $TestDrive 'workspace-api'
        $webPath = Join-Path $TestDrive 'workspace-web'
        New-Item -ItemType Directory -Path $apiPath, $webPath -Force | Out-Null
        Write-TestConfigV2 -Path $configPath -Projects @(
            [PSCustomObject]@{ name = 'api'; rootPath = $apiPath; enabled = $true },
            [PSCustomObject]@{ name = 'web'; rootPath = $webPath; enabled = $true }
        )

        Invoke-CdpWorkspace -Add 'fullstack' -Projects @('api', 'web') -Open 'codex' -ConfigPath $configPath -Confirm:$false
        $output = @(& { Invoke-CdpWorkspace -List -ConfigPath $configPath } 6>&1) -join [Environment]::NewLine
        $workspaces = @(ConvertFrom-Json -InputObject (Get-Content -LiteralPath $workspacesPath -Raw -Encoding UTF8))

        $workspaces.Count | Should -Be 1
        $workspaces[0].name | Should -Be 'fullstack'
        @($workspaces[0].projects.name) | Should -Be @('api', 'web')
        @($workspaces[0].projects.rootPath) | Should -Be @($apiPath, $webPath)
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
        ConvertTo-Json -InputObject @(
            [PSCustomObject]@{ name = 'team'; projects = @('Api', 'Missing', 'Unknown'); open = 'code' }
        ) -Depth 6 | Set-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Encoding UTF8

        InModuleScope cdp -Parameters @{ ConfigPath = $configPath; ProjectPath = $projectPath } {
            Mock Get-Command { [PSCustomObject]@{ Name = 'wt.exe' } } -ParameterFilter { $Name -eq 'wt.exe' }
            Mock Start-Process {}

            $output = @(& {
                Invoke-CdpWorkspace -Name 'team' -Open 'codex' -ConfigPath $ConfigPath -Confirm:$false
            } 6>&1) -join [Environment]::NewLine

            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq 'wt.exe' -and
                @($ArgumentList).Count -eq 9 -and
                $ArgumentList[4] -eq $ProjectPath -and
                $ArgumentList[6] -eq 'Api' -and
                $ArgumentList[7] -eq '--' -and
                $ArgumentList[8] -eq 'codex'
            }
            $output | Should -Match "Cannot launch 'Missing': missing-path"
            $output | Should -Match "Cannot launch 'Unknown': missing-project"
        }
    }

    It 'rejects workspace launcher command lines' {
        $configPath = Join-Path $TestDrive 'unsafe-launcher-projects.json'
        '[]' | Set-Content -LiteralPath $configPath -Encoding UTF8

        { Invoke-CdpWorkspace -Add 'unsafe' -Projects @('api') -Open 'codex;echo' -ConfigPath $configPath } |
            Should -Throw '*single executable name*'
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
                Invoke-CdpOnEnter -Project $Project -AllowHook
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
                Invoke-CdpOnEnter -Project $Project -AllowHook
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
            @(& { Invoke-CdpOnEnter -Project $Project -AllowHook } 6>&1) -join [Environment]::NewLine
        }

        $output | Should -Match 'onEnter warning: command failed'
        $output | Should -Not -Match 'expected hook failure'
    }

    It 'skips command hooks by default while applying valid env values' {
        $previousEnv = $env:CDP_TEST_ONENTER_SAFE_ENV
        $previousCommand = $env:CDP_TEST_ONENTER_BLOCKED
        $project = [PSCustomObject]@{
            onEnter = [PSCustomObject]@{
                env = [PSCustomObject]@{ CDP_TEST_ONENTER_SAFE_ENV = 'enabled' }
                powershell = '$env:CDP_TEST_ONENTER_BLOCKED = "ran"'
            }
        }

        try {
            $output = InModuleScope cdp -Parameters @{ Project = $project } {
                @(& { Invoke-CdpOnEnter -Project $Project } 6>&1) -join [Environment]::NewLine
            }
            $env:CDP_TEST_ONENTER_SAFE_ENV | Should -Be 'enabled'
            $env:CDP_TEST_ONENTER_BLOCKED | Should -Be $previousCommand
            $output | Should -Match 'command skipped'
            $output | Should -Not -Match 'CDP_TEST_ONENTER_BLOCKED'
        } finally {
            $env:CDP_TEST_ONENTER_SAFE_ENV = $previousEnv
            $env:CDP_TEST_ONENTER_BLOCKED = $previousCommand
        }
    }

    It 'rejects invalid environment variable names without echoing them' {
        $environment = [PSCustomObject]@{}
        $environment | Add-Member -NotePropertyName 'INVALID-NAME' -NotePropertyValue 'blocked'
        $project = [PSCustomObject]@{ onEnter = [PSCustomObject]@{ env = $environment } }

        $output = InModuleScope cdp -Parameters @{ Project = $project } {
            @(& { Invoke-CdpOnEnter -Project $Project } 6>&1) -join [Environment]::NewLine
        }

        $output | Should -Match 'invalid environment variable name skipped'
        $output | Should -Not -Match 'INVALID-NAME'
    }

    It 'routes one-time hook authorization to project switching' {
        InModuleScope cdp {
            Mock Switch-Project {}

            Invoke-Cdp api --allow-hook

            Should -Invoke Switch-Project -Times 1 -Exactly -ParameterFilter {
                $Query -eq 'api' -and $AllowHook
            }
        }
    }

    It 'persists hook trust without exposing command text and invalidates changes' {
        $trustPath = Join-Path $TestDrive 'hook-trust.json'
        $configPath = Join-Path $TestDrive 'trusted-hook-projects.json'
        $projectPath = Join-Path $TestDrive 'trusted-hook-project'
        New-Item -ItemType Directory -Path $projectPath | Out-Null
        $project = [PSCustomObject]@{
            name = 'TrustedHook'
            rootPath = $projectPath
            enabled = $true
            onEnter = [PSCustomObject]@{ powershell = '$env:CDP_TEST_TRUSTED = "ran"' }
        }
        @($project) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8
        $previousTrustPath = $env:CDP_HOOK_TRUST_PATH
        $previousValue = $env:CDP_TEST_TRUSTED
        $env:CDP_HOOK_TRUST_PATH = $trustPath
        Remove-Item Env:CDP_TEST_TRUSTED -ErrorAction SilentlyContinue

        try {
            InModuleScope cdp -Parameters @{ ConfigPath = $configPath } {
                Add-CdpHookTrust -ConfigPath $ConfigPath -Name 'TrustedHook'
            }
            $storedTrust = Get-Content -LiteralPath $trustPath -Raw -Encoding UTF8
            $storedTrust | Should -Not -Match 'CDP_TEST_TRUSTED'
            $storedTrust | Should -Not -Match 'powershell'
            $list = InModuleScope cdp -Parameters @{ ConfigPath = $configPath } {
                @(& { Show-CdpHookTrustList -ConfigPath $ConfigPath } 6>&1) -join [Environment]::NewLine
            }
            $list | Should -Match 'TrustedHook.*trusted'
            $list | Should -Not -Match 'CDP_TEST_TRUSTED'

            InModuleScope cdp -Parameters @{ ConfigPath = $configPath; Project = $project } {
                Invoke-CdpOnEnter -Project $Project -ConfigPath $ConfigPath
            }
            $env:CDP_TEST_TRUSTED | Should -Be 'ran'

            $projectWithTag = [PSCustomObject]@{
                name = 'TrustedHook'; rootPath = $projectPath; enabled = $true; tags = @('changed')
                onEnter = [PSCustomObject]@{ powershell = '$env:CDP_TEST_TRUSTED = "ran"' }
            }
            @($projectWithTag) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8
            Remove-Item Env:CDP_TEST_TRUSTED -ErrorAction SilentlyContinue
            $contentChangeOutput = InModuleScope cdp -Parameters @{ ConfigPath = $configPath; Project = $projectWithTag } {
                @(& { Invoke-CdpOnEnter -Project $Project -ConfigPath $ConfigPath } 6>&1) -join [Environment]::NewLine
            }
            $env:CDP_TEST_TRUSTED | Should -BeNullOrEmpty
            $contentChangeOutput | Should -Match 'command skipped'
            InModuleScope cdp -Parameters @{ ConfigPath = $configPath } {
                Clear-CdpProjectConfigCache -ConfigPath $ConfigPath
                Add-CdpHookTrust -ConfigPath $ConfigPath -Name 'TrustedHook'
            }

            $changed = [PSCustomObject]@{
                name = 'TrustedHook'; rootPath = $projectPath; enabled = $true; tags = @('changed')
                onEnter = [PSCustomObject]@{ powershell = '$env:CDP_TEST_TRUSTED = "changed"' }
            }
            @($changed) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8
            Remove-Item Env:CDP_TEST_TRUSTED -ErrorAction SilentlyContinue
            $output = InModuleScope cdp -Parameters @{ ConfigPath = $configPath; Project = $changed } {
                @(& { Invoke-CdpOnEnter -Project $Project -ConfigPath $ConfigPath } 6>&1) -join [Environment]::NewLine
            }
            $env:CDP_TEST_TRUSTED | Should -BeNullOrEmpty
            $output | Should -Match 'trust this project hook'
            $output | Should -Not -Match 'changed'

            [IO.File]::WriteAllText($trustPath, '{')
            $invalidStoreOutput = InModuleScope cdp -Parameters @{ ConfigPath = $configPath; Project = $changed } {
                @(& { Invoke-CdpOnEnter -Project $Project -ConfigPath $ConfigPath } 6>&1) -join [Environment]::NewLine
            }
            $env:CDP_TEST_TRUSTED | Should -BeNullOrEmpty
            $invalidStoreOutput | Should -Match 'onEnter warning'
            $invalidStoreOutput | Should -Not -Match 'changed'
            (Get-Content -LiteralPath $trustPath -Raw) | Should -BeExactly '{'
        } finally {
            $env:CDP_HOOK_TRUST_PATH = $previousTrustPath
            if ($null -eq $previousValue) { Remove-Item Env:CDP_TEST_TRUSTED -ErrorAction SilentlyContinue }
            else { $env:CDP_TEST_TRUSTED = $previousValue }
        }
    }

    It 'honors no-hook and revokes persistent trust' {
        $trustPath = Join-Path $TestDrive 'hook-nohook-trust.json'
        $configPath = Join-Path $TestDrive 'nohook-projects.json'
        $project = [PSCustomObject]@{
            name = 'NoHookProject'; rootPath = $TestDrive; enabled = $true
            onEnter = [PSCustomObject]@{
                env = [PSCustomObject]@{ CDP_TEST_NOHOOK = 'set' }
                powershell = '$env:CDP_TEST_NOHOOK_COMMAND = "ran"'
            }
        }
        @($project) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8
        $previousTrustPath = $env:CDP_HOOK_TRUST_PATH
        $previousValue = $env:CDP_TEST_NOHOOK
        $env:CDP_HOOK_TRUST_PATH = $trustPath
        Remove-Item Env:CDP_TEST_NOHOOK -ErrorAction SilentlyContinue
        try {
            $output = InModuleScope cdp -Parameters @{ ConfigPath = $configPath; Project = $project } {
                @(& { Invoke-CdpOnEnter -Project $Project -ConfigPath $ConfigPath -NoHook } 6>&1) -join [Environment]::NewLine
            }
            $env:CDP_TEST_NOHOOK | Should -BeNullOrEmpty
            $output | Should -Match '--no-hook'

            InModuleScope cdp -Parameters @{ ConfigPath = $configPath } {
                Add-CdpHookTrust -ConfigPath $ConfigPath -Name 'NoHookProject'
                Remove-CdpHookTrust -ConfigPath $ConfigPath -Name 'NoHookProject'
            }
            $list = InModuleScope cdp -Parameters @{ ConfigPath = $configPath } {
                @(& { Show-CdpHookTrustList -ConfigPath $ConfigPath } 6>&1) -join [Environment]::NewLine
            }
            $list | Should -Match 'NoHookProject.*untrusted'
            if ([System.IO.Path]::DirectorySeparatorChar -ne '\') {
                (& stat -c '%a' $trustPath) | Should -Be '600'
            }
        } finally {
            $env:CDP_HOOK_TRUST_PATH = $previousTrustPath
            if ($null -eq $previousValue) { Remove-Item Env:CDP_TEST_NOHOOK -ErrorAction SilentlyContinue }
            else { $env:CDP_TEST_NOHOOK = $previousValue }
        }
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

    It 'completes workspace lifecycle actions names projects launchers and layouts' {
        $configPath = Join-Path $TestDrive 'workspace-completion-projects.json'
        Write-TestConfigV2 -Path $configPath -Projects @(
            [PSCustomObject]@{ name = 'CompleteApi'; rootPath = $TestDrive; enabled = $true },
            [PSCustomObject]@{ name = 'CompleteHidden'; rootPath = $TestDrive; enabled = $false }
        )
        ConvertTo-Json -InputObject @([PSCustomObject]@{ name='complete-team'; projects=@('CompleteApi') }) -Depth 6 |
            Set-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Encoding UTF8
        $previousConfig = $env:CDP_CONFIG
        $env:CDP_CONFIG = $configPath

        try {
            $actionLine = 'Invoke-Cdp workspace sh'
            $nameLine = 'Invoke-Cdp workspace show complete'
            $projectLine = 'Invoke-Cdp workspace add new Complete'
            $launcherLine = 'Invoke-Cdp workspace open complete-team --open co'
            $layoutLine = 'Invoke-Cdp workspace edit complete-team --layout sp'

            @(TabExpansion2 $actionLine $actionLine.Length).CompletionMatches.CompletionText | Should -Contain show
            @(TabExpansion2 $nameLine $nameLine.Length).CompletionMatches.CompletionText | Should -Contain 'complete-team'
            $projectMatches = @(TabExpansion2 $projectLine $projectLine.Length).CompletionMatches.CompletionText
            $projectMatches | Should -Contain CompleteApi
            $projectMatches | Should -Not -Contain CompleteHidden
            @(TabExpansion2 $launcherLine $launcherLine.Length).CompletionMatches.CompletionText | Should -Contain codex
            @(TabExpansion2 $layoutLine $layoutLine.Length).CompletionMatches.CompletionText | Should -Contain split-horizontal
        } finally {
            $env:CDP_CONFIG = $previousConfig
        }
    }
}
