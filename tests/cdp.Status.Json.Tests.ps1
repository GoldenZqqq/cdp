BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ManifestPath = Join-Path $script:RepoRoot 'cdp.psd1'
    $script:ContractPath = Join-Path $script:RepoRoot 'tests/fixtures/status-json-contract-v1.json'
    Import-Module $script:ManifestPath -Force
}

Describe 'cdp status JSON parser contract' {
    It 'parses structured output flags and rejects unsafe combinations' {
        InModuleScope cdp {
            $json = ConvertFrom-CdpInvokeArguments -Command status -RemainingArgs @('--json', '--dirty', '--refresh')
            $plain = ConvertFrom-CdpInvokeArguments -Command status -RemainingArgs @('--no-color')

            $json.Json | Should -BeTrue
            $json.DirtyOnly | Should -BeTrue
            $json.Refresh | Should -BeTrue
            $plain.NoColor | Should -BeTrue
            { ConvertFrom-CdpInvokeArguments -Command status -RemainingArgs @('--json', '--no-color') } |
                Should -Throw '*cannot be used together*'
            { ConvertFrom-CdpInvokeArguments -Command status -RemainingArgs @('--json', '--fix') } |
                Should -Throw '*read-only status*'
            { ConvertFrom-CdpInvokeArguments -Command status -RemainingArgs @('--no-color', '--push') } |
                Should -Throw '*read-only status*'
        }
    }
}

Describe 'cdp status JSON schema version 1' {
    It 'matches the shared cross-runtime contract fixture' {
        $expected = Get-Content -LiteralPath $script:ContractPath -Raw -Encoding UTF8 | ConvertFrom-Json
        InModuleScope cdp -Parameters @{ Expected = $expected } {
            $states = @(
                [PSCustomObject]@{ Name='Clean'; RootPath='C:\Clean'; PathExists=$true; IsGitRepo=$true; Branch='main'; DirtyCount=0; UntrackedCount=0; AheadCount=0; BehindCount=0; LastCommitRelative='now'; StatusLabel='clean'; NeedsAttention=$false },
                [PSCustomObject]@{ Name='Dirty'; RootPath='C:\Dirty'; PathExists=$true; IsGitRepo=$true; Branch='main'; DirtyCount=1; UntrackedCount=1; AheadCount=0; BehindCount=0; LastCommitRelative='now'; StatusLabel='1 dirty + 1 untracked'; NeedsAttention=$true },
                [PSCustomObject]@{ Name='Plain'; RootPath='C:\Plain'; PathExists=$true; IsGitRepo=$false; Branch=''; DirtyCount=0; UntrackedCount=0; AheadCount=0; BehindCount=0; LastCommitRelative=''; StatusLabel='not a git repo'; NeedsAttention=$false },
                [PSCustomObject]@{ Name='Missing'; RootPath='C:\Missing'; PathExists=$false; IsGitRepo=$false; Branch=''; DirtyCount=0; UntrackedCount=0; AheadCount=0; BehindCount=0; LastCommitRelative=''; StatusLabel='path missing'; NeedsAttention=$true }
            )
            $actual = @($states | ForEach-Object { ConvertTo-CdpStatusProject -Info $_ })

            $Expected.schemaVersion | Should -Be 1
            for ($index = 0; $index -lt $Expected.projects.Count; $index++) {
                $actual[$index].name | Should -Be $Expected.projects[$index].name
                $actual[$index].status | Should -Be $Expected.projects[$index].status
                $actual[$index].needsAttention | Should -Be $Expected.projects[$index].needsAttention
                @($actual[$index].attentionReasons) | Should -Be @($Expected.projects[$index].attentionReasons)
                $actual[$index].error | Should -BeNullOrEmpty
                $actual[$index].git.isRepository | Should -Be $Expected.projects[$index].isRepository
                $actual[$index].git.dirtyCount | Should -Be $Expected.projects[$index].dirtyCount
                $actual[$index].git.untrackedCount | Should -Be $Expected.projects[$index].untrackedCount
                $actual[$index].git.aheadCount | Should -Be $Expected.projects[$index].aheadCount
                $actual[$index].git.behindCount | Should -Be $Expected.projects[$index].behindCount
            }
        }
    }

    It 'keeps empty project collections as JSON arrays' {
        InModuleScope cdp {
            $json = New-CdpStatusDocument -AllStatus @() -VisibleStatus @() -DurationMs 0 |
                ConvertTo-Json -Depth 7 | ConvertFrom-Json

            $json.summary.total | Should -Be 0
            $json.summary.exitCode | Should -Be 0
            @($json.projects).Count | Should -Be 0
        }
    }

    It 'projects stable fields, reasons, errors, and exit precedence' {
        InModuleScope cdp {
            $changed = [PSCustomObject]@{
                Name = 'Api'; RootPath = 'C:\Work\api'; PathExists = $true; IsGitRepo = $true
                Branch = 'main'; DirtyCount = 1; UntrackedCount = 1; AheadCount = 0; BehindCount = 2
                LastCommitRelative = '2 hours ago'; StatusLabel = '1 dirty + 1 untracked'; NeedsAttention = $true
            }
            $failed = [PSCustomObject]@{
                Name = 'Broken'; RootPath = 'C:\Work\broken'; PathExists = $true; IsGitRepo = $false
                Branch = ''; DirtyCount = 0; UntrackedCount = 0; AheadCount = 0; BehindCount = 0
                LastCommitRelative = ''; StatusLabel = 'status failed'; NeedsAttention = $true
            }
            $timed = [PSCustomObject]@{
                Name = 'Slow'; RootPath = 'C:\Work\slow'; PathExists = $true; IsGitRepo = $false
                Branch = ''; DirtyCount = 0; UntrackedCount = 0; AheadCount = 0; BehindCount = 0
                LastCommitRelative = ''; StatusLabel = 'status timed out'; NeedsAttention = $true
            }

            $document = New-CdpStatusDocument -AllStatus @($changed, $failed, $timed) `
                -VisibleStatus @($changed, $failed, $timed) -DurationMs 25 -Refresh
            $json = $document | ConvertTo-Json -Depth 7 | ConvertFrom-Json

            $json.schemaVersion | Should -Be 1
            $json.durationMs | Should -Be 25
            $json.summary.total | Should -Be 3
            $json.summary.attention | Should -Be 3
            $json.summary.partialFailures | Should -Be 2
            $json.summary.exitCode | Should -Be 2
            $json.projects[0].rawPath | Should -Be 'C:\Work\api'
            $json.projects[0].resolvedPath | Should -Be 'C:\Work\api'
            @($json.projects[0].attentionReasons) | Should -Be @('dirty', 'untracked', 'behind')
            $json.projects[0].git.behindCount | Should -Be 2
            $json.projects[1].status | Should -Be 'scan_failed'
            $json.projects[1].error.code | Should -Be 'scan_failed'
            $json.projects[2].status | Should -Be 'scan_timeout'
            $json.projects[2].error.code | Should -Be 'scan_timeout'
        }
    }

    It 'serializes one JSON document without progress output' {
        $configPath = Join-Path $TestDrive 'projects.json'
        '[]' | Set-Content -LiteralPath $configPath -Encoding UTF8

        $output = InModuleScope cdp -Parameters @{ ConfigPath = $configPath } {
            Mock Get-CdpProjectConfig {
                [PSCustomObject]@{ EnabledProjects = @(
                    [PSCustomObject]@{ name = 'Missing'; rootPath = 'C:\Missing'; enabled = $true }
                ) }
            }
            Mock Get-CdpGitProjectInfoBatch {
                [PSCustomObject]@{
                    Name = 'Missing'; RootPath = 'C:\Missing'; PathExists = $false; IsGitRepo = $false
                    Branch = ''; DirtyCount = 0; UntrackedCount = 0; AheadCount = 0; BehindCount = 0
                    LastCommitRelative = ''; StatusLabel = 'path missing'; NeedsAttention = $true
                }
            }

            Show-CdpProjectStatus -ConfigPath $ConfigPath -Json
        }

        $document = ($output -join [Environment]::NewLine) | ConvertFrom-Json
        $document.summary.exitCode | Should -Be 1
        $document.projects.Count | Should -Be 1
        $document.projects[0].attentionReasons | Should -Be 'path_missing'
    }

    It 'renders an ANSI-free plain table' {
        $configPath = Join-Path $TestDrive 'plain-projects.json'
        '[]' | Set-Content -LiteralPath $configPath -Encoding UTF8

        $output = InModuleScope cdp -Parameters @{ ConfigPath = $configPath } {
            Mock Get-CdpProjectConfig {
                [PSCustomObject]@{ EnabledProjects = @(
                    [PSCustomObject]@{ name = 'Plain'; rootPath = 'C:\Plain'; enabled = $true }
                ) }
            }
            Mock Get-CdpGitProjectInfoBatch {
                [PSCustomObject]@{
                    Name = 'Plain'; RootPath = 'C:\Plain'; PathExists = $true; IsGitRepo = $false
                    Branch = ''; DirtyCount = 0; UntrackedCount = 0; AheadCount = 0; BehindCount = 0
                    LastCommitRelative = ''; StatusLabel = 'not a git repo'; NeedsAttention = $false
                }
            }

            Show-CdpProjectStatus -ConfigPath $ConfigPath -NoColor 6>&1
        }

        ($output -join [Environment]::NewLine) | Should -Match 'cdp project status'
        ($output -join [Environment]::NewLine) | Should -Not -Match ([char]27)
    }
}
