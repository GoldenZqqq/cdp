BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:PolicyScript = Join-Path $script:RepoRoot 'scripts/Test-CommitMessages.ps1'
    . $script:PolicyScript
}

Describe 'commit message policy' {
    It 'accepts English printable ASCII subjects and bodies' {
        $message = "feat: add project search`n`n- support aliases`n- preserve paths"

        $result = Get-CdpCommitMessageValidation -Message $message

        $result.IsValid | Should -BeTrue
        $result.Reason | Should -BeNullOrEmpty
    }

    It 'accepts tabs and Windows line endings' {
        $message = "fix: align columns`r`n`r`nname`tstatus"

        (Get-CdpCommitMessageValidation -Message $message).IsValid | Should -BeTrue
    }

    It 'rejects Chinese text' {
        $result = Get-CdpCommitMessageValidation -Message 'docs: update English docs and 中文 mirror'

        $result.IsValid | Should -BeFalse
        $result.Reason | Should -Match 'U\+[0-9A-F]{4}'
    }

    It 'rejects typographic punctuation and emoji' -ForEach @(
        @{ Message = 'release: cdp v2.0.0 — Project Workbench' },
        @{ Message = 'docs: polish landing page 🚀' }
    ) {
        (Get-CdpCommitMessageValidation -Message $Message).IsValid | Should -BeFalse
    }

    It 'rejects empty messages' {
        (Get-CdpCommitMessageValidation -Message '').IsValid | Should -BeFalse
    }

    It 'validates a commit message file' {
        $messagePath = Join-Path $TestDrive 'COMMIT_EDITMSG'
        'chore: enforce English commit messages' | Set-Content -Path $messagePath -Encoding UTF8

        { Test-CdpCommitMessageFile -Path $messagePath } | Should -Not -Throw
    }

    It 'rejects a non-English commit message file' {
        $messagePath = Join-Path $TestDrive 'COMMIT_EDITMSG'
        'fix: 修复提交信息' | Set-Content -Path $messagePath -Encoding UTF8

        { Test-CdpCommitMessageFile -Path $messagePath } | Should -Throw '*English ASCII*'
    }
}
