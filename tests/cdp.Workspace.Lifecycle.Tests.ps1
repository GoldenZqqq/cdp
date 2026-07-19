BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    Import-Module (Join-Path $script:RepoRoot 'cdp.psd1') -Force
}

Describe 'cdp workspace lifecycle parser' {
    It 'normalizes lifecycle actions and layout options' {
        InModuleScope cdp {
            (ConvertFrom-CdpInvokeArguments -Command workspace -RemainingArgs @('show','team')).WorkspaceAction | Should -Be show
            (ConvertFrom-CdpInvokeArguments -Command workspace -RemainingArgs @('remove','team','--yes')).WorkspaceAction | Should -Be remove
            $edit = ConvertFrom-CdpInvokeArguments -Command workspace -RemainingArgs @('edit','team','api','--layout','split-horizontal','--open','codex')
            $edit.WorkspaceAction | Should -Be edit
            $edit.WorkspaceLayout | Should -Be split-horizontal
            @($edit.Projects) | Should -Be @('api')
            $validate = ConvertFrom-CdpInvokeArguments -Command workspace -RemainingArgs @('validate','team','--fix','--dry-run')
            $validate.WorkspaceAction | Should -Be validate
            $validate.Fix | Should -BeTrue
            $validate.DryRun | Should -BeTrue
        }
    }

    It 'rejects conflicting lifecycle options before dispatch' {
        InModuleScope cdp {
            { ConvertFrom-CdpInvokeArguments -Command workspace -RemainingArgs @('edit','team','--open','codex','--clear-open') } |
                Should -Throw '*cannot be used together*'
            { ConvertFrom-CdpInvokeArguments -Command workspace -RemainingArgs @('validate','team','--dry-run') } |
                Should -Throw '*require --fix*'
            { ConvertFrom-CdpInvokeArguments -Command workspace -RemainingArgs @('show','team','--yes') } |
                Should -Throw '*does not accept safety options*'
        }
    }
}

Describe 'cdp workspace lifecycle persistence' {
    BeforeEach {
        $script:ConfigPath = Join-Path $TestDrive 'projects.json'
        $script:ApiPath = Join-Path $TestDrive 'api'
        $script:WebPath = Join-Path $TestDrive 'web'
        New-Item -ItemType Directory -Path $script:ApiPath, $script:WebPath -Force | Out-Null
        @(
            [PSCustomObject]@{ name='api'; rootPath=$script:ApiPath; enabled=$true },
            [PSCustomObject]@{ name='web'; rootPath=$script:WebPath; enabled=$true }
        ) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:ConfigPath -Encoding UTF8
        Remove-Item -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Force -ErrorAction SilentlyContinue
    }

    It 'creates stable references and supports show edit remove' {
        Invoke-CdpWorkspace -Add team -Projects api,web -Open codex -Layout split-horizontal -ConfigPath $script:ConfigPath -Confirm:$false
        $created = @(Get-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Raw -Encoding UTF8 | ConvertFrom-Json)[0]
        $created.projects[0].rootPath | Should -Be $script:ApiPath
        $created.layout.mode | Should -Be split

        $shown = Invoke-CdpWorkspace -Show team -ConfigPath $script:ConfigPath -PassThru
        $shown.name | Should -Be team

        Invoke-CdpWorkspace -Edit team -Projects web -ClearOpen -Layout tabs -ConfigPath $script:ConfigPath -Confirm:$false
        $edited = @(Get-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Raw -Encoding UTF8 | ConvertFrom-Json)[0]
        @($edited.projects).Count | Should -Be 1
        $edited.projects[0].name | Should -Be web
        $edited.PSObject.Properties['open'] | Should -BeNullOrEmpty
        $edited.layout.mode | Should -Be tabs

        Invoke-CdpWorkspace -Remove team -ConfigPath $script:ConfigPath -Confirm:$false
        @(Get-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Raw -Encoding UTF8 | ConvertFrom-Json).Count | Should -Be 0
    }

    It 'migrates legacy references and refreshes renamed names by raw identity' {
        ConvertTo-Json -InputObject @(
            [PSCustomObject]@{ name='team'; projects=@('api', [PSCustomObject]@{name='old-web';rootPath=$script:WebPath}) }
        ) -Depth 6 | Set-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Encoding UTF8

        $before = @(Invoke-CdpWorkspace -Validate -Name team -ConfigPath $script:ConfigPath -PassThru)
        @($before | Where-Object Status -eq legacy).Count | Should -Be 1
        @($before | Where-Object Status -eq renamed).Count | Should -Be 1

        Invoke-CdpWorkspace -Validate -Fix -Name team -ConfigPath $script:ConfigPath -Confirm:$false | Out-Null
        $workspace = @(Get-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Raw -Encoding UTF8 | ConvertFrom-Json)[0]
        $workspace.projects[0].rootPath | Should -Be $script:ApiPath
        $workspace.projects[1].name | Should -Be web
    }

    It 'does not bind a deleted stable reference to a reused name' {
        ConvertTo-Json -InputObject @(
            [PSCustomObject]@{ name='team'; projects=@([PSCustomObject]@{name='api';rootPath='C:/Deleted/api'}) }
        ) -Depth 6 | Set-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Encoding UTF8

        $results = @(Invoke-CdpWorkspace -Validate -Name team -ConfigPath $script:ConfigPath -PassThru)
        $results[0].Status | Should -Be missing-project
        $results[0].RawPath | Should -Be 'C:/Deleted/api'
    }

    It 'matches stable raw paths exactly instead of folding case' {
        $projects = @([PSCustomObject]@{ name='api'; rootPath='C:/Work/API'; enabled=$true })
        $reference = [PSCustomObject]@{ name='api'; rootPath='C:/Work/api' }

        InModuleScope cdp -Parameters @{ Projects=$projects; Reference=$reference } {
            (Resolve-CdpWorkspaceReference -Reference $Reference -Projects $Projects).Status |
                Should -Be missing-project
        }
    }

    It 'preserves unknown fields while fixing legacy and renamed references' {
        ConvertTo-Json -InputObject @([PSCustomObject]@{
            name='team'
            futureWorkspace='keep-workspace'
            projects=@(
                'api',
                [PSCustomObject]@{
                    name='old-web'
                    rootPath=$script:WebPath
                    open='code'
                    size=40
                    futureReference='keep-reference'
                },
                $null,
                ''
            )
        }) -Depth 8 | Set-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Encoding UTF8

        Invoke-CdpWorkspace -Validate -Fix -Name team -ConfigPath $script:ConfigPath -Confirm:$false | Out-Null
        $workspace = @(Get-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Raw -Encoding UTF8 | ConvertFrom-Json)[0]

        $workspace.futureWorkspace | Should -Be 'keep-workspace'
        $workspace.projects[0].name | Should -Be api
        $workspace.projects[1].name | Should -Be web
        $workspace.projects[1].open | Should -Be code
        $workspace.projects[1].size | Should -Be 40
        $workspace.projects[1].futureReference | Should -Be 'keep-reference'
        @($workspace.projects).Count | Should -Be 4
        $workspace.projects[2] | Should -BeNullOrEmpty
        $workspace.projects[3] | Should -Be ''
    }

    It 'reports invalid reference size launcher and layout without launching them' {
        ConvertTo-Json -InputObject @([PSCustomObject]@{
            name='team'
            open='codex;echo'
            layout=[PSCustomObject]@{ mode='split'; direction='diagonal' }
            projects=@(
                [PSCustomObject]@{ name='api'; rootPath=$script:ApiPath; size=9 },
                [PSCustomObject]@{ name='web'; rootPath=$script:WebPath; size=40.5 },
                [PSCustomObject]@{ name='broken' }
            )
        }) -Depth 8 | Set-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Encoding UTF8

        $results = @(Invoke-CdpWorkspace -Validate -Name team -ConfigPath $script:ConfigPath -PassThru)

        @($results.Status) | Should -Contain invalid-layout
        @($results.Status) | Should -Contain invalid-launcher
        @($results.Status) | Should -Contain invalid-size
        @($results.Status) | Should -Contain invalid-reference
    }

    It 'does not rewrite an already normalized workspace during validate fix' {
        ConvertTo-Json -InputObject @([PSCustomObject]@{
            name='team'
            projects=@(
                [PSCustomObject]@{ name='api'; rootPath=$script:ApiPath },
                [PSCustomObject]@{ name='web'; rootPath=$script:WebPath; size=40 }
            )
        }) -Depth 8 | Set-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Encoding UTF8
        $workspacePath = Join-Path $TestDrive 'workspaces.json'
        $before = [IO.File]::ReadAllBytes($workspacePath)

        $result = Invoke-CdpWorkspace -Validate -Fix -Name team -ConfigPath $script:ConfigPath -Confirm:$false -PassThru

        [Convert]::ToBase64String([IO.File]::ReadAllBytes($workspacePath)) | Should -Be ([Convert]::ToBase64String($before))
        $result.Action | Should -Be validate-workspace
        $result.Status | Should -Be skipped
        $result.Changed | Should -BeFalse
    }

    It 'keeps workspace bytes unchanged for edit remove and validate fix WhatIf previews' {
        Invoke-CdpWorkspace -Add team -Projects api,web -ConfigPath $script:ConfigPath -Confirm:$false
        $workspacePath = Join-Path $TestDrive 'workspaces.json'
        $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($workspacePath))

        $edit = Invoke-CdpWorkspace -Edit team -Projects web -ConfigPath $script:ConfigPath -WhatIf -PassThru
        $remove = Invoke-CdpWorkspace -Remove team -ConfigPath $script:ConfigPath -WhatIf -PassThru
        $fix = Invoke-CdpWorkspace -Validate -Fix -Name team -ConfigPath $script:ConfigPath -WhatIf -PassThru

        [Convert]::ToBase64String([IO.File]::ReadAllBytes($workspacePath)) | Should -Be $before
        @($edit.Status, $remove.Status, $fix.Status) | Should -Be @('preview','preview','skipped')
        @($edit.Changed, $remove.Changed, $fix.Changed) | Should -Be @($false,$false,$false)
    }
}

Describe 'cdp workspace lifecycle launch plan' {
    It 'applies launcher precedence and renders split arguments as argv' {
        $apiPath = Join-Path $TestDrive 'plan-api'
        $webPath = Join-Path $TestDrive 'plan-web'
        New-Item -ItemType Directory -Path $apiPath, $webPath -Force | Out-Null

        InModuleScope cdp -Parameters @{ ApiPath=$apiPath; WebPath=$webPath } {
            $projects = @(
                [PSCustomObject]@{ name='api'; rootPath=$ApiPath; enabled=$true },
                [PSCustomObject]@{ name='web'; rootPath=$WebPath; enabled=$true }
            )
            $workspace = [PSCustomObject]@{
                name='team'
                open='codex'
                layout=[PSCustomObject]@{ mode='split'; direction='horizontal' }
                projects=@(
                    [PSCustomObject]@{ name='old-api'; rootPath=$ApiPath; open='code'; size=40 },
                    [PSCustomObject]@{ name='web'; rootPath=$WebPath }
                )
            }

            $plan = @(New-CdpWorkspaceLaunchPlan -Workspace $workspace -Projects $projects)
            $plan[0].Status | Should -Be renamed
            $plan[0].Name | Should -Be api
            $plan[0].Launcher.Command | Should -Be code
            $plan[1].Launcher.Command | Should -Be codex
            $args = @(Get-CdpWindowsTerminalWorkspaceArguments -Item $plan[0] -Layout $workspace.layout -First $false)
            $args | Should -Be @('-w','0','split-pane','-H','-s','0.4','-d',$ApiPath,'--title','api','--','code','.')

            $override = @(New-CdpWorkspaceLaunchPlan -Workspace $workspace -Projects $projects -OpenOverride cursor)
            @($override.Launcher.Command) | Should -Be @('cursor','cursor')
        }
    }
}
