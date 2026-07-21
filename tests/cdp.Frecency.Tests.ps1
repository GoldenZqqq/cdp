BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ManifestPath = Join-Path $script:RepoRoot 'cdp.psd1'
    $script:FixturePath = Join-Path $script:RepoRoot 'tests/fixtures/frecency-ranking.json'
    Import-Module $script:ManifestPath -Force
}

Describe 'cdp frecency ranking' {
    It 'matches the shared fixed-time ranking fixture' {
        $fixture = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $script:FixturePath -Raw -Encoding UTF8)
        InModuleScope cdp -Parameters @{ Fixture = $fixture } {
            $projects = (ConvertTo-CdpJsonArrayValue -Value $Fixture.projects).Value
            $state = [PSCustomObject]@{ recentProjects = (ConvertTo-CdpJsonArrayValue -Value $Fixture.recentProjects).Value }
            $actual = @(Sort-CdpProjectsForDisplay -Projects $projects -State $state -NowEpoch $Fixture.nowEpoch |
                ForEach-Object { [string]$_.name })
            $actual | Should -Be @($Fixture.expected)
        }
    }

    It 'keeps pin and configuration order when frecency is disabled' {
        $fixture = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $script:FixturePath -Raw -Encoding UTF8)
        InModuleScope cdp -Parameters @{ Fixture = $fixture } {
            $previous = $env:CDP_FRECENCY
            try {
                $env:CDP_FRECENCY = 'false'
                $projects = (ConvertTo-CdpJsonArrayValue -Value $Fixture.projects).Value
                $state = [PSCustomObject]@{ recentProjects = (ConvertTo-CdpJsonArrayValue -Value $Fixture.recentProjects).Value }
                $actual = @(Sort-CdpProjectsForDisplay -Projects $projects -State $state -NowEpoch $Fixture.nowEpoch |
                    ForEach-Object { [string]$_.name })
                $actual | Should -Be @($Fixture.disabledExpected)
            } finally {
                $env:CDP_FRECENCY = $previous
            }
        }
    }

    It 'falls back safely for missing, invalid, and large state history' {
        $fixture = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $script:FixturePath -Raw -Encoding UTF8)
        InModuleScope cdp -Parameters @{ Fixture = $fixture } {
            $projects = (ConvertTo-CdpJsonArrayValue -Value $Fixture.projects).Value
            $invalid = [PSCustomObject]@{ recentProjects = @([PSCustomObject]@{ rootPath = '/fixture/pinned-current'; visitCount = -1 }) }
            $largeEntries = 1..12000 | ForEach-Object {
                [PSCustomObject]@{ rootPath = "/fixture/unknown-$_"; lastVisitedAt = '2026-01-01T00:00:00Z'; visitCount = 1 }
            }
            $large = [PSCustomObject]@{ recentProjects = $largeEntries }
            $expected = @($Fixture.disabledExpected)
            @((Sort-CdpProjectsForDisplay -Projects $projects -State $null -NowEpoch $Fixture.nowEpoch | ForEach-Object name)) | Should -Be $expected
            @((Sort-CdpProjectsForDisplay -Projects $projects -State $invalid -NowEpoch $Fixture.nowEpoch | ForEach-Object name)) | Should -Be $expected
            { Sort-CdpProjectsForDisplay -Projects $projects -State $large -NowEpoch $Fixture.nowEpoch } | Should -Not -Throw
        }
    }

    It 'preserves exact raw path identity while recording visits' {
        $statePath = Join-Path $TestDrive 'identity-state.json'
        $previousStatePath = $env:CDP_STATE_PATH
        $env:CDP_STATE_PATH = $statePath
        try {
            InModuleScope cdp {
                Add-CdpRecentProject -Project ([PSCustomObject]@{ name = 'Upper'; rootPath = 'C:/Repo' })
                Add-CdpRecentProject -Project ([PSCustomObject]@{ name = 'Lower'; rootPath = 'c:/repo' })
            }
            $state = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $statePath -Raw -Encoding UTF8)
            @($state.recentProjects).Count | Should -Be 2
        } finally {
            $env:CDP_STATE_PATH = $previousStatePath
        }
    }
}

Describe 'cdp recent reset' {
    It 'supports preview, preserves unknown fields, and skips empty state' {
        $statePath = Join-Path $TestDrive 'reset-state.json'
        [PSCustomObject]@{
            recentProjects = @([PSCustomObject]@{ name = 'Api'; rootPath = '/api'; lastVisitedAt = '2026-01-01T00:00:00Z'; visitCount = 1 })
            futureField = 'preserve-me'
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath -Encoding UTF8
        $previousStatePath = $env:CDP_STATE_PATH
        $env:CDP_STATE_PATH = $statePath
        try {
            $before = (Get-FileHash -LiteralPath $statePath -Algorithm SHA256).Hash
            $preview = Reset-CdpRecentProjects -WhatIf
            $preview.Status | Should -Be 'preview'
            (Get-FileHash -LiteralPath $statePath -Algorithm SHA256).Hash | Should -Be $before

            $result = Reset-CdpRecentProjects -Confirm:$false
            $result.Status | Should -Be 'succeeded'
            $state = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $statePath -Raw -Encoding UTF8)
            @($state.recentProjects).Count | Should -Be 0
            $state.futureField | Should -Be 'preserve-me'

            $after = (Get-FileHash -LiteralPath $statePath -Algorithm SHA256).Hash
            (Reset-CdpRecentProjects).Status | Should -Be 'skipped'
            (Get-FileHash -LiteralPath $statePath -Algorithm SHA256).Hash | Should -Be $after
        } finally {
            $env:CDP_STATE_PATH = $previousStatePath
        }
    }

    It 'refuses to overwrite invalid state' {
        $statePath = Join-Path $TestDrive 'invalid-reset-state.json'
        Set-Content -LiteralPath $statePath -Value '{invalid' -Encoding UTF8
        $previousStatePath = $env:CDP_STATE_PATH
        $env:CDP_STATE_PATH = $statePath
        try {
            $before = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8
            $result = Reset-CdpRecentProjects -Confirm:$false
            $result.Status | Should -Be 'failed'
            $result.Error | Should -Be 'invalid-state'
            Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | Should -Be $before
        } finally {
            $env:CDP_STATE_PATH = $previousStatePath
        }
    }

    It 'treats a scalar recentProjects field as invalid state' {
        $statePath = Join-Path $TestDrive 'scalar-reset-state.json'
        Set-Content -LiteralPath $statePath -Value '{"recentProjects":{"rootPath":"/api"}}' -Encoding UTF8
        $previousStatePath = $env:CDP_STATE_PATH
        $env:CDP_STATE_PATH = $statePath
        try {
            $before = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8
            $result = Reset-CdpRecentProjects -Confirm:$false
            $result.Status | Should -Be 'failed'
            Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | Should -Be $before
        } finally {
            $env:CDP_STATE_PATH = $previousStatePath
        }
    }

    It 'parses reset as a mutation route' {
        InModuleScope cdp {
            $invocation = ConvertFrom-CdpInvokeArguments -Command 'recent' -ConfigPath $null -Query $null -Open $null -RemainingArgs @('reset', '--dry-run')
            $invocation.RecentAction | Should -Be 'reset'
            $invocation.DryRun | Should -BeTrue
            Test-CdpInvocationMutation -Invocation $invocation | Should -BeTrue
        }
    }

    It 'offers reset and safety options through PowerShell completion' {
        InModuleScope cdp {
            $tokens = $null
            $errors = $null
            $ast = [Management.Automation.Language.Parser]::ParseInput(
                'Invoke-Cdp recent r', [ref]$tokens, [ref]$errors
            )
            $commandAst = @($ast.FindAll({ param($node)
                $node -is [Management.Automation.Language.CommandAst]
            }, $true))[0]
            Get-CdpRecentCompletionValues -CommandAst $commandAst -WordToComplete 'r' |
                Should -Contain 'reset'

            $resetAst = [Management.Automation.Language.Parser]::ParseInput(
                'Invoke-Cdp recent reset --', [ref]$tokens, [ref]$errors
            )
            $resetCommand = @($resetAst.FindAll({ param($node)
                $node -is [Management.Automation.Language.CommandAst]
            }, $true))[0]
            Get-CdpRecentCompletionValues -CommandAst $resetCommand -WordToComplete '--' |
                Should -Contain '--yes'
        }
    }
}
