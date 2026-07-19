BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:CoverageGate = Join-Path $script:RepoRoot 'scripts/Test-CoverageThreshold.ps1'
}

Describe 'cdp PowerShell coverage quality gate' {
    It 'reports counts and accepts coverage at the threshold' {
        $result = & $script:CoverageGate -CommandsAnalyzed 100 -CommandsExecuted 60 -MinimumPercent 60

        $result.CoveragePercent | Should -Be 60
        $result.CommandsExecuted | Should -Be 60
    }

    It 'rejects a deliberate coverage regression' {
        { & $script:CoverageGate -CommandsAnalyzed 100 -CommandsExecuted 59 -MinimumPercent 60 } |
            Should -Throw '*Coverage threshold failed*'
    }

    It 'rejects invalid command counts' {
        { & $script:CoverageGate -CommandsAnalyzed 10 -CommandsExecuted 11 } |
            Should -Throw '*between zero and the analyzed count*'
    }
}
