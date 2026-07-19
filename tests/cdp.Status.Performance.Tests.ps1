BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ManifestPath = Join-Path $script:RepoRoot 'cdp.psd1'
    Import-Module $script:ManifestPath -Force
}

Describe 'cdp porcelain v2 status collection' {
    It 'parses branch, upstream, sync, tracked, and untracked fields' {
        InModuleScope cdp {
            $project = [PSCustomObject]@{ name = 'Api'; rootPath = '/tmp/api'; enabled = $true }
            $info = New-CdpGitProjectInfo -Project $project
            $lines = @(
                '# branch.oid 0123456789abcdef'
                '# branch.head main'
                '# branch.upstream origin/main'
                '# branch.ab +2 -1'
                '1 .M N... 100644 100644 100644 abc abc tracked.txt'
                '2 R. N... 100644 100644 100644 abc abc R100 old.txt`tnew.txt'
                '? untracked.txt'
            )

            [void](ConvertFrom-CdpGitStatusPorcelainV2 -Lines $lines -Info $info)
            Set-CdpGitProjectStatusLabel -Info $info

            $info.Branch | Should -Be 'main'
            $info.Remote | Should -Be 'origin'
            $info.Upstream | Should -Be 'origin/main'
            $info.AheadCount | Should -Be 2
            $info.BehindCount | Should -Be 1
            $info.DirtyCount | Should -Be 2
            $info.UntrackedCount | Should -Be 1
            $info.NeedsAttention | Should -BeTrue
        }
    }

    It 'uses only status and log Git processes for a committed repository' {
        $projectPath = Join-Path $TestDrive 'process-count'
        New-Item -ItemType Directory -Path $projectPath | Out-Null

        InModuleScope cdp -Parameters @{ ProjectPath = $projectPath } {
            $script:GitCalls = New-Object 'System.Collections.Generic.List[string]'
            Mock git {
                $script:GitCalls.Add(($args -join ' '))
                $global:LASTEXITCODE = 0
                if ($args -contains 'status') {
                    return @('# branch.oid 0123456789abcdef', '# branch.head main')
                }
                if ($args -contains 'log') { return '2 minutes ago' }
            }

            $result = Get-CdpGitProjectInfo -Project ([PSCustomObject]@{
                name = 'Api'
                rootPath = $ProjectPath
                enabled = $true
            })

            $result.IsGitRepo | Should -BeTrue
            $result.LastCommitRelative | Should -Be '2 minutes ago'
            $script:GitCalls.Count | Should -Be 2
            ($script:GitCalls -join "`n") | Should -Not -Match 'rev-parse|rev-list|branch --show-current'
        }
    }

    It 'parses refresh and bounded jobs options' {
        InModuleScope cdp {
            $result = ConvertFrom-CdpInvokeArguments `
                -Command status `
                -RemainingArgs @('--refresh', '--jobs', '3')

            $result.Refresh | Should -BeTrue
            $result.ThrottleLimit | Should -Be 3
            { ConvertFrom-CdpInvokeArguments -Command status -RemainingArgs @('--jobs', '17') } |
                Should -Throw '*between 1 and 16*'
        }
    }
}

Describe 'cdp bounded status batching' {
    It 'runs collectors concurrently while preserving project order' {
        InModuleScope cdp {
            $projects = @(1..4 | ForEach-Object {
                [PSCustomObject]@{ name = "Repo$_"; rootPath = "/tmp/repo-$_"; enabled = $true }
            })
            $collector = {
                param($Project)
                $started = [DateTime]::UtcNow
                Start-Sleep -Milliseconds 250
                [PSCustomObject]@{
                    Name = $Project.name
                    RootPath = $Project.rootPath
                    Started = $started
                    Ended = [DateTime]::UtcNow
                }
            }

            $results = @(Get-CdpGitProjectInfoBatch `
                -Projects $projects `
                -ThrottleLimit 2 `
                -TimeoutSeconds 3 `
                -Refresh `
                -CollectorScript $collector)

            $results.Name | Should -Be @('Repo1', 'Repo2', 'Repo3', 'Repo4')
            $results[1].Started | Should -BeLessThan $results[0].Ended
            $results[3].Started | Should -BeLessThan $results[2].Ended
        }
    }

    It 'times out one collector without dropping later results' {
        InModuleScope cdp {
            $projects = @(
                [PSCustomObject]@{ name = 'Slow'; rootPath = '/tmp/slow'; enabled = $true },
                [PSCustomObject]@{ name = 'Fast'; rootPath = '/tmp/fast'; enabled = $true }
            )
            $collector = {
                param($Project)
                if ($Project.name -eq 'Slow') { Start-Sleep -Seconds 2 }
                [PSCustomObject]@{ Name = $Project.name; StatusLabel = 'clean'; NeedsAttention = $false }
            }

            $results = @(Get-CdpGitProjectInfoBatch `
                -Projects $projects `
                -ThrottleLimit 2 `
                -TimeoutSeconds 1 `
                -Refresh `
                -CollectorScript $collector)

            $results.Count | Should -Be 2
            $results[0].StatusLabel | Should -Be 'status timed out'
            $results[1].Name | Should -Be 'Fast'
        }
    }

    It 'enforces timeout with a single worker' {
        InModuleScope cdp {
            $project = [PSCustomObject]@{ name = 'Slow'; rootPath = '/tmp/slow'; enabled = $true }
            $collector = {
                param($Project)
                Start-Sleep -Seconds 2
                [PSCustomObject]@{ Name = $Project.name; StatusLabel = 'clean' }
            }

            $result = @(Get-CdpGitProjectInfoBatch -Projects @($project) -ThrottleLimit 1 `
                -TimeoutSeconds 1 -Refresh -CollectorScript $collector)

            $result.Count | Should -Be 1
            $result[0].StatusLabel | Should -Be 'status timed out'
        }
    }

    It 'uses an explicit TTL cache and refresh bypass' {
        $counterPath = Join-Path $TestDrive 'collector-count.txt'
        $projectPath = Join-Path $TestDrive 'cache-project'
        New-Item -ItemType Directory -Path $projectPath | Out-Null

        InModuleScope cdp -Parameters @{ CounterPath = $counterPath; ProjectPath = $projectPath } {
            $previousTtl = $env:CDP_STATUS_CACHE_TTL
            try {
                $env:CDP_STATUS_CACHE_TTL = '30'
                $script:CdpStatusCache = @{}
                $project = [PSCustomObject]@{
                    name = 'Cached'
                    rootPath = $ProjectPath
                    CounterPath = $CounterPath
                    enabled = $true
                }
                $collector = {
                    param($Project)
                    [IO.File]::AppendAllText($Project.CounterPath, 'x')
                    [PSCustomObject]@{ Name = $Project.name; RootPath = $Project.rootPath; StatusLabel = 'clean' }
                }

                [void]@(Get-CdpGitProjectInfoBatch -Projects @($project) -ThrottleLimit 1 -CollectorScript $collector)
                [void]@(Get-CdpGitProjectInfoBatch -Projects @($project) -ThrottleLimit 1 -CollectorScript $collector)
                (Get-Content -LiteralPath $CounterPath -Raw).Length | Should -Be 1

                [void]@(Get-CdpGitProjectInfoBatch -Projects @($project) -ThrottleLimit 1 -Refresh -CollectorScript $collector)
                (Get-Content -LiteralPath $CounterPath -Raw).Length | Should -Be 2
            } finally {
                $env:CDP_STATUS_CACHE_TTL = $previousTtl
                $script:CdpStatusCache = @{}
            }
        }
    }
}
