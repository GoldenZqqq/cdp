BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    Import-Module (Join-Path $script:RepoRoot 'cdp.psd1') -Force
}

Describe 'cdp launcher definition safety' {
    It 'normalizes only supported built-in launcher names' {
        InModuleScope cdp {
            $launcher = Get-CdpWorkspaceLauncher -Open 'VSCode'
            $launcher.Name | Should -Be 'code'
            $launcher.Command | Should -Be 'code'
            @($launcher.Arguments) | Should -Be @('.')

            { Get-CdpWorkspaceLauncher -Open 'codex; Write-Output unsafe' } |
                Should -Throw '*Launcher must be*'
            { Get-CdpWorkspaceLauncher -Open 'custom-tool' } |
                Should -Throw '*Unsupported launcher*'
            { Get-CdpWorkspaceLauncher -Open ' codex ' } |
                Should -Throw '*Launcher must be*'
        }
    }

    It 'keeps paths, titles, commands, and arguments as distinct native argv' {
        InModuleScope cdp {
            $path = "C:\work\project '; `$() ü"
            $name = 'Api; $(unsafe)'
            $item = [PSCustomObject]@{
                Name=$name; ResolvedPath=$path; Status='ok'; Size=$null
                Launcher=Get-CdpWorkspaceLauncher -Open code
            }
            $arguments = @(Get-CdpWindowsTerminalWorkspaceArguments `
                -Item $item -Layout ([PSCustomObject]@{ mode='tabs' }) -First $true)

            $arguments | Should -Contain $path
            $arguments | Should -Contain $name
            $arguments[-3] | Should -Be '--'
            $arguments[-2] | Should -Be 'code'
            $arguments[-1] | Should -Be '.'
            ($arguments -join ' ') | Should -Not -Match 'powershell|pwsh|-Command'
        }
    }
}

Describe 'cdp launcher validation before side effects' {
    It 'rejects an unsafe direct launcher before cwd, recent state, or hooks change' {
        $configPath = Join-Path $TestDrive 'projects.json'
        $projectPath = Join-Path $TestDrive 'project'
        $statePath = Join-Path $TestDrive 'state.json'
        New-Item -ItemType Directory -Path $projectPath | Out-Null
        @([PSCustomObject]@{
            name='Unsafe'; rootPath=$projectPath; enabled=$true
            onEnter=[PSCustomObject]@{ env=[PSCustomObject]@{ CDP_LAUNCHER_GUARD='changed' } }
        }) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8
        $previousState = $env:CDP_STATE_PATH
        $previousGuard = $env:CDP_LAUNCHER_GUARD
        $env:CDP_STATE_PATH = $statePath
        $env:CDP_LAUNCHER_GUARD = 'original'
        Push-Location $TestDrive
        try {
            $before = (Get-Location).Path
            $output = @(& { Invoke-Cdp Unsafe $configPath -Open 'codex; unsafe' } 6>&1) -join "`n"
            (Get-Location).Path | Should -Be $before
            Test-Path -LiteralPath $statePath | Should -BeFalse
            $env:CDP_LAUNCHER_GUARD | Should -Be 'original'
            $output | Should -Match 'Launcher must be'
        } finally {
            Pop-Location
            $env:CDP_STATE_PATH = $previousState
            $env:CDP_LAUNCHER_GUARD = $previousGuard
        }
    }

    It 'rejects an unsafe launcher before workspace persistence' {
        $configPath = Join-Path $TestDrive 'add-projects.json'
        $workspacePath = Join-Path $TestDrive 'workspaces.json'
        '[]' | Set-Content -LiteralPath $configPath -Encoding UTF8

        {
            Invoke-CdpWorkspace -Add unsafe -Projects @('Api') `
                -Open 'codex; Set-Content unsafe' -ConfigPath $configPath -Confirm:$false
        } | Should -Throw '*Launcher must be*'

        Test-Path -LiteralPath $workspacePath | Should -BeFalse
    }

    It 'rejects a stored unsafe launcher before terminal lookup or launch' {
        $configPath = Join-Path $TestDrive 'stored-projects.json'
        $projectPath = Join-Path $TestDrive 'stored-project'
        New-Item -ItemType Directory -Path $projectPath | Out-Null
        ConvertTo-Json -InputObject @(
            [PSCustomObject]@{ name='Api'; rootPath=$projectPath; enabled=$true }
        ) -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8
        ConvertTo-Json -InputObject @(
            [PSCustomObject]@{ name='unsafe'; projects=@('Api'); open='custom-tool' }
        ) -Depth 5 |
            Set-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Encoding UTF8

        $output = InModuleScope cdp -Parameters @{ ConfigPath=$configPath } {
            Mock Get-Command { throw 'Terminal lookup must not run.' } `
                -ParameterFilter { $Name -eq 'wt.exe' }
            @(& {
                Invoke-CdpWorkspace -Name unsafe -ConfigPath $ConfigPath -Confirm:$false
            } 6>&1) -join [Environment]::NewLine
        }

        $output | Should -Match 'invalid-launcher|Unsupported launcher'
    }

    It 'does not launch a process for a workspace WhatIf preview' {
        InModuleScope cdp {
            Mock Get-Command { [PSCustomObject]@{ Source='wt.exe' } } -ParameterFilter { $Name -eq 'wt.exe' }
            Mock Start-Process {}
            $plan = @([PSCustomObject]@{
                Name='Api'; ResolvedPath='C:\work\api'; Status='ok'; Size=$null
                Launcher=Get-CdpWorkspaceLauncher -Open codex
            })

            Invoke-CdpWorkspaceLaunch -Plan $plan -Layout ([PSCustomObject]@{ mode='tabs' }) -WhatIf
            Should -Invoke Start-Process -Times 0 -Exactly
        }
    }
}
