BeforeAll {
    $script:ManifestPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'cdp.psd1'
    Import-Module $script:ManifestPath -Force
}

Describe 'cdp atomic JSON persistence' {
    It 'writes atomically, keeps three backups, and rejects stale fingerprints' {
        InModuleScope cdp {
            $path = Join-Path $TestDrive 'projects.json'
            $fingerprint = Write-CdpJsonFile -LiteralPath $path -Value @() -ExpectedFingerprint 'missing'

            1..5 | ForEach-Object {
                $document = Read-CdpJsonDocument -LiteralPath $path
                $fingerprint = Write-CdpJsonFile `
                    -LiteralPath $path `
                    -Value @([PSCustomObject]@{ name = "project-$_" }) `
                    -ExpectedFingerprint $document.Fingerprint
            }

            @(Get-ChildItem -LiteralPath $TestDrive -Filter 'projects.json.cdp-backup.*').Count | Should -Be 3
            { Write-CdpJsonFile -LiteralPath $path -Value @() -ExpectedFingerprint 'stale' } |
                Should -Throw '*changed since it was read*'
            (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)[0].name | Should -Be 'project-5'

            $backup = @(Get-CdpValidJsonBackups -LiteralPath $path)[0]
            [IO.File]::WriteAllText($path, '{')
            [void](Restore-CdpJsonBackup -LiteralPath $path -BackupPath $backup.FullName)
            { Get-Content -LiteralPath $path -Raw | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    It 'rejects invalid JSON candidates and preserves the original' {
        InModuleScope cdp {
            $path = Join-Path $TestDrive 'invalid.json'
            [IO.File]::WriteAllText($path, '[]')
            $before = Get-CdpFileFingerprint -LiteralPath $path
            $invalidValue = @{}
            $invalidValue[[datetime]::UtcNow] = 'not serializable as a JSON object'

            { Write-CdpJsonFile -LiteralPath $path -Value $invalidValue -ExpectedFingerprint $before } |
                Should -Throw
            Get-CdpFileFingerprint -LiteralPath $path | Should -Be $before
            Test-Path -LiteralPath "$path.cdp.lock" | Should -BeFalse
            @(Get-ChildItem -LiteralPath $TestDrive -Filter 'invalid.json.cdp-tmp.*').Count | Should -Be 0
        }
    }

    It 'does not remove a lock owned by another process' {
        InModuleScope cdp {
            $path = Join-Path $TestDrive 'locked.json'
            [IO.File]::WriteAllText($path, '[]')
            $lockPath = "$path.cdp.lock"
            [IO.File]::WriteAllText($lockPath, 'owner')

            { Write-CdpJsonFile -LiteralPath $path -Value @() -ExpectedFingerprint (Get-CdpFileFingerprint $path) } |
                Should -Throw '*locked by another cdp process*'
            Test-Path -LiteralPath $lockPath | Should -BeTrue
        }
    }

    It 'invalidates the project config cache after a write' {
        InModuleScope cdp {
            $path = Join-Path $TestDrive 'cache.json'
            [IO.File]::WriteAllText($path, '[{"name":"one","rootPath":"/one","enabled":true}]')
            (Get-CdpProjectConfig -ConfigPath $path).Projects[0].name | Should -Be 'one'
            $document = Read-CdpJsonDocument -LiteralPath $path

            [void](Write-CdpJsonFile -LiteralPath $path -Value @(
                [PSCustomObject]@{ name = 'two'; rootPath = '/two'; enabled = $true }
            ) -ExpectedFingerprint $document.Fingerprint)

            (Get-CdpProjectConfig -ConfigPath $path).Projects[0].name | Should -Be 'two'
        }
    }

    It 'reports a valid backup when the active config is invalid' {
        InModuleScope cdp {
            $path = Join-Path $TestDrive 'doctor.json'
            [void](Write-CdpJsonFile -LiteralPath $path -Value @() -ExpectedFingerprint 'missing')
            $document = Read-CdpJsonDocument -LiteralPath $path
            [void](Write-CdpJsonFile `
                -LiteralPath $path `
                -Value @([PSCustomObject]@{ name = 'one'; rootPath = '/one'; enabled = $true }) `
                -ExpectedFingerprint $document.Fingerprint)
            [IO.File]::WriteAllText($path, '{')

            $result = Get-CdpConfigParseResult -ConfigPath $path -ConfigSource 'test'
            $jsonCheck = @($result.Checks | Where-Object { $_.Name -eq 'JSON' })[0]

            $result.Parsed | Should -BeFalse
            $jsonCheck.Passed | Should -BeFalse
            $jsonCheck.Message | Should -Match '1 valid cdp backup\(s\) available'
        }
    }

    It 'cleans owned artifacts when replacement fails' {
        InModuleScope cdp {
            $path = Join-Path $TestDrive 'replacement-target'
            New-Item -ItemType Directory -Path $path | Out-Null

            { Write-CdpJsonFile -LiteralPath $path -Value @() -ExpectedFingerprint 'missing' } |
                Should -Throw

            Test-Path -LiteralPath "$path.cdp.lock" | Should -BeFalse
            @(Get-ChildItem -LiteralPath $TestDrive -Filter 'replacement-target.cdp-tmp.*').Count | Should -Be 0
            Test-Path -LiteralPath $path -PathType Container | Should -BeTrue
        }
    }

    It 'rejects a status fix when the config changes during the scan' {
        InModuleScope cdp {
            $path = Join-Path $TestDrive 'status-race.json'
            $missingPath = Join-Path $TestDrive 'status-race-missing'
            [IO.File]::WriteAllText($path, (@(
                [PSCustomObject]@{ name = 'Missing'; rootPath = $missingPath; enabled = $true }
            ) | ConvertTo-Json -Depth 4))

            Mock Get-CdpGitProjectInfoBatch {
                [IO.File]::WriteAllText($path, '[]')
                [PSCustomObject]@{
                    Name = 'Missing'
                    RootPath = $missingPath
                    PathExists = $false
                    IsGitRepo = $false
                    Branch = '-'
                    DirtyCount = 0
                    UntrackedCount = 0
                    AheadCount = 0
                    BehindCount = 0
                    LastCommitRelative = ''
                    StatusLabel = 'path missing'
                    NeedsAttention = $true
                }
            }

            { Show-CdpProjectStatus -ConfigPath $path -Fix -Confirm:$false } |
                Should -Throw '*changed since it was read*'
            (Get-Content -LiteralPath $path -Raw) | Should -BeExactly '[]'
        }
    }
}
