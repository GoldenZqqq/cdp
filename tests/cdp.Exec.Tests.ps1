BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:PowerShellExecutable = (Get-Process -Id $PID).Path
    Import-Module (Join-Path $script:RepoRoot 'cdp.psd1') -Force
}

Describe 'cdp exec parser' {
    It 'keeps every token after the command boundary as argv' {
        InModuleScope cdp {
            $invocation = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @(
                'api', 'web', '--jobs', '2', '--timeout', '30', '--fail-fast', '--json',
                '--', 'tool', '--config', 'path with spaces', ';touch', ''
            )

            $invocation.Kind | Should -Be exec
            $invocation.ExecSelectorKind | Should -Be projects
            @($invocation.ExecProjectNames) | Should -Be @('api','web')
            $invocation.ThrottleLimit | Should -Be 2
            $invocation.TimeoutSeconds | Should -Be 30
            $invocation.FailFast | Should -BeTrue
            $invocation.Json | Should -BeTrue
            $invocation.ExecCommand | Should -Be tool
            @($invocation.ExecArguments) | Should -Be @('--config','path with spaces',';touch','')
        }
    }

    It 'normalizes tag workspace and all selectors' {
        InModuleScope cdp {
            (ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('@work','--','git','status')).ExecSelectorKind | Should -Be tag
            (ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('--workspace','team','--','git','status')).ExecSelectorKind | Should -Be workspace
            (ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('--all','--','git','status')).ExecSelectorKind | Should -Be all
        }
    }

    It 'rejects missing boundaries empty selectors conflicts and invalid bounds' {
        InModuleScope cdp {
            { ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('api','git','status') } | Should -Throw '*requires --*'
            { ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('--','git','status') } | Should -Throw '*requires projects*'
            { ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('','--','git') } | Should -Throw '*selector cannot be empty*'
            { ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('--workspace','','--','git') } | Should -Throw '*workspace selector cannot be empty*'
            { ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('api','--config','','--','git') } | Should -Throw '*config path cannot be empty*'
            { ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('api','--','') } | Should -Throw '*non-empty command*'
            { ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('api','@work','--','git') } | Should -Throw '*cannot be combined*'
            { ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('--all','--workspace','team','--','git') } | Should -Throw '*cannot be combined*'
            { ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('api','--jobs','17','--','git') } | Should -Throw '*between 1 and 16*'
            { ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('api','--fail-fast','--continue','--','git') } | Should -Throw '*cannot be used together*'
            { ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('api','--dry-run','--yes','--','git') } | Should -Throw '*cannot be used together*'
        }
    }

    It 'detects json mode only before the exec command boundary' {
        InModuleScope cdp {
            Test-CdpJsonRequested -Command exec -RemainingArgs @('api','--json','--','tool') | Should -BeTrue
            Test-CdpJsonRequested -Command exec -RemainingArgs @('api','--','tool','--json') | Should -BeFalse
            Test-CdpJsonRequested -Command status -RemainingArgs @('--json') | Should -BeTrue
        }
    }

    It 'routes exec without treating command argv json as cdp json mode' {
        InModuleScope cdp {
            Mock Invoke-CdpExecInvocation {}

            Invoke-Cdp -Command exec -RemainingArgs @('api','--dry-run','--','tool','--json')

            Should -Invoke Invoke-CdpExecInvocation -Times 1 -ParameterFilter {
                $Invocation.Kind -eq 'exec' -and -not $Invocation.Json -and
                $Invocation.DryRun -and $Invocation.ExecArguments[0] -eq '--json'
            }
        }
    }
}

Describe 'cdp exec selection plans' {
    BeforeEach {
        $script:ConfigPath = Join-Path $TestDrive 'projects.json'
        $script:ApiPath = Join-Path $TestDrive 'api'
        $script:WebPath = Join-Path $TestDrive 'web'
        $script:DisabledPath = Join-Path $TestDrive 'disabled'
        New-Item -ItemType Directory -Path $script:ApiPath,$script:WebPath,$script:DisabledPath -Force | Out-Null
        @(
            [PSCustomObject]@{ name='api'; rootPath=$script:ApiPath; enabled=$true; tags=@('Work') },
            [PSCustomObject]@{ name='web'; rootPath=$script:WebPath; enabled=$true; tags=@('work') },
            [PSCustomObject]@{ name='disabled'; rootPath=$script:DisabledPath; enabled=$false; tags=@('work') }
        ) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:ConfigPath -Encoding UTF8
    }

    It 'preserves explicit order and deduplicates by exact raw identity' {
        InModuleScope cdp -Parameters @{ ConfigPath=$script:ConfigPath; HostExe=$script:PowerShellExecutable } {
            $invocation = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @(
                'api','web','api','--config',$ConfigPath,'--',$HostExe,'-NoLogo','-NoProfile','-Command','exit 0'
            )
            $plan = New-CdpExecPlan -Invocation $invocation

            @($plan.Items.Name) | Should -Be @('api','web')
            @($plan.Items.Status) | Should -Be @('planned','planned')
            $plan.Selector.kind | Should -Be projects
            @($plan.Selector.value) | Should -Be @('api','web','api')
        }
    }

    It 'selects tags case-insensitively and all projects in config order' {
        InModuleScope cdp -Parameters @{ ConfigPath=$script:ConfigPath; HostExe=$script:PowerShellExecutable } {
            $tag = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('@wOrK','--config',$ConfigPath,'--',$HostExe,'-NoProfile','-Command','exit 0')
            $all = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('--all','--config',$ConfigPath,'--',$HostExe,'-NoProfile','-Command','exit 0')

            @(New-CdpExecPlan -Invocation $tag).Items.Name | Should -Be @('api','web')
            @(New-CdpExecPlan -Invocation $all).Items.Name | Should -Be @('api','web')
        }
    }

    It 'reuses stable workspace references and isolates unavailable targets' {
        $missingPath = Join-Path $TestDrive 'missing-path'
        $invalidPath = Join-Path $TestDrive 'invalid-path'
        $ambiguousPath = Join-Path $TestDrive 'ambiguous'
        @(
            [PSCustomObject]@{ name='renamed'; rootPath=$script:ApiPath; enabled=$true },
            [PSCustomObject]@{ name='legacy'; rootPath=$script:WebPath; enabled=$true },
            [PSCustomObject]@{ name='disabled'; rootPath=$script:DisabledPath; enabled=$false },
            [PSCustomObject]@{ name='missingPath'; rootPath=$missingPath; enabled=$true },
            [PSCustomObject]@{ name='invalidPath'; rootPath=$invalidPath; enabled=$true; paths=[PSCustomObject]@{ linux='' } },
            [PSCustomObject]@{ name='duplicateA'; rootPath=$ambiguousPath; enabled=$true },
            [PSCustomObject]@{ name='duplicateB'; rootPath=$ambiguousPath; enabled=$true }
        ) | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $script:ConfigPath -Encoding UTF8
        ConvertTo-Json -InputObject @([PSCustomObject]@{
            name='team'
            projects=@(
                [PSCustomObject]@{ name='old'; rootPath=$script:ApiPath; size=9; open='bad;launcher' },
                'legacy',
                [PSCustomObject]@{ name='gone'; rootPath='raw/missing' },
                [PSCustomObject]@{ name='duplicate'; rootPath=$ambiguousPath },
                [PSCustomObject]@{ name='disabled'; rootPath=$script:DisabledPath },
                [PSCustomObject]@{ name='invalidPath'; rootPath=$invalidPath },
                [PSCustomObject]@{ name='missingPath'; rootPath=$missingPath },
                [PSCustomObject]@{ name='again'; rootPath=$script:ApiPath }
            )
        }) -Depth 8 | Set-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Encoding UTF8

        InModuleScope cdp -Parameters @{ ConfigPath=$script:ConfigPath; HostExe=$script:PowerShellExecutable } {
            $invocation = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('--workspace','team','--config',$ConfigPath,'--',$HostExe,'-NoProfile','-Command','exit 0')
            $plan = New-CdpExecPlan -Invocation $invocation

            @($plan.Items.Name) | Should -Be @('renamed','legacy','gone','duplicate','disabled','invalidPath','missingPath')
            @($plan.Items.Status) | Should -Be @(
                'planned','planned','missing_project','ambiguous_project','disabled_project','path_profile_invalid','path_missing'
            )
        }
    }

    It 'fails before execution for unknown explicit selectors and missing executables' {
        InModuleScope cdp -Parameters @{ ConfigPath=$script:ConfigPath; HostExe=$script:PowerShellExecutable } {
            $unknown = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('gone','--config',$ConfigPath,'--',$HostExe)
            $missingCommand = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('api','--config',$ConfigPath,'--','cdp-no-such-executable')

            { New-CdpExecPlan -Invocation $unknown } | Should -Throw '*not found*'
            { New-CdpExecPlan -Invocation $missingCommand } | Should -Throw '*native executable*'
        }
    }

    It 'rejects non-array project and workspace documents before execution' {
        $objectConfig = Join-Path $TestDrive 'object-projects.json'
        [PSCustomObject]@{ name='api'; rootPath=$script:ApiPath; enabled=$true } |
            ConvertTo-Json | Set-Content -LiteralPath $objectConfig -Encoding UTF8
        ConvertTo-Json -InputObject @([PSCustomObject]@{ name='broken'; projects=[PSCustomObject]@{ name='api'; rootPath=$script:ApiPath } }) -Depth 5 |
            Set-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Encoding UTF8

        InModuleScope cdp -Parameters @{ ObjectConfig=$objectConfig; ConfigPath=$script:ConfigPath; HostExe=$script:PowerShellExecutable } {
            $projectInvocation = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('api','--config',$ObjectConfig,'--',$HostExe)
            $workspaceInvocation = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @('--workspace','broken','--config',$ConfigPath,'--',$HostExe)

            { New-CdpExecPlan -Invocation $projectInvocation } | Should -Throw '*JSON array*'
            { New-CdpExecPlan -Invocation $workspaceInvocation } | Should -Throw '*JSON array*'
        }
    }

    It 'completes exec projects tags workspaces and stops after the command boundary' {
        ConvertTo-Json -InputObject @([PSCustomObject]@{ name='team'; projects=@('api') }) -Depth 5 |
            Set-Content -LiteralPath (Join-Path $TestDrive 'workspaces.json') -Encoding UTF8
        $previous = $env:CDP_CONFIG
        $env:CDP_CONFIG = $script:ConfigPath
        try {
            InModuleScope cdp {
                function New-TestCommandAst([string[]]$Tokens) {
                    [PSCustomObject]@{ CommandElements=@($Tokens | ForEach-Object {
                        [PSCustomObject]@{ Extent=[PSCustomObject]@{ Text=$_ } }
                    }) }
                }
                $projects = @(Get-CdpExecCompletionValues -CommandAst (New-TestCommandAst @('cdp','exec','a')) -WordToComplete a)
                $workspaces = @(Get-CdpExecCompletionValues -CommandAst (New-TestCommandAst @('cdp','exec','--workspace','te')) -WordToComplete te)
                $afterBoundary = @(Get-CdpExecCompletionValues -CommandAst (New-TestCommandAst @('cdp','exec','api','--','sh','--j')) -WordToComplete '--j')

                $projects | Should -Contain api
                $projects | Should -Contain '@Work'
                $workspaces | Should -Contain team
                $afterBoundary | Should -BeNullOrEmpty
            }
        } finally { $env:CDP_CONFIG = $previous }
    }
}

Describe 'cdp exec native execution' {
    BeforeEach {
        $script:ConfigPath = Join-Path $TestDrive 'projects.json'
        $script:FirstPath = Join-Path $TestDrive 'first'
        $script:SecondPath = Join-Path $TestDrive 'second'
        $script:ThirdPath = Join-Path $TestDrive 'third'
        New-Item -ItemType Directory -Path $script:FirstPath,$script:SecondPath,$script:ThirdPath -Force | Out-Null
        @(
            [PSCustomObject]@{ name='first'; rootPath=$script:FirstPath; enabled=$true },
            [PSCustomObject]@{ name='second'; rootPath=$script:SecondPath; enabled=$true },
            [PSCustomObject]@{ name='third'; rootPath=$script:ThirdPath; enabled=$true }
        ) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:ConfigPath -Encoding UTF8
        $script:CaptureProbe = Join-Path $TestDrive 'capture-probe.ps1'
        $script:ExitProbe = Join-Path $TestDrive 'exit-probe.ps1'
        $script:SleepProbe = Join-Path $TestDrive 'sleep-probe.ps1'
        '[Console]::Out.Write($PWD.Path); [Console]::Error.Write("warn")' |
            Set-Content -LiteralPath $script:CaptureProbe -Encoding UTF8
        'if ((Split-Path -Leaf $PWD.Path) -eq $args[0]) { exit [int]$args[1] } else { exit 0 }' |
            Set-Content -LiteralPath $script:ExitProbe -Encoding UTF8
        'Start-Sleep -Seconds 2' | Set-Content -LiteralPath $script:SleepProbe -Encoding UTF8
    }

    It 'captures ordered stdout stderr exit codes and working directories' {
        InModuleScope cdp -Parameters @{ ConfigPath=$script:ConfigPath; HostExe=$script:PowerShellExecutable; Probe=$script:CaptureProbe } {
            $invocation = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @(
                '--all','--config',$ConfigPath,'--jobs','2','--yes','--',$HostExe,
                '-NoLogo','-NoProfile','-File',$Probe
            )
            $plan = New-CdpExecPlan -Invocation $invocation
            Invoke-CdpExecWorkers -Plan $plan

            @($plan.Items.Name) | Should -Be @('first','second','third')
            @($plan.Items.Status) | Should -Be @('succeeded','succeeded','succeeded')
            @($plan.Items.ExitCode) | Should -Be @(0,0,0)
            @($plan.Items.Stdout) | Should -Be @($plan.Items.ResolvedPath)
            @($plan.Items.Stderr) | Should -Be @('warn','warn','warn')
        }
    }

    It 'passes metacharacters spaces and empty arguments without evaluation' {
        $probe = Join-Path $TestDrive 'argv-probe.ps1'
        $marker = Join-Path $TestDrive 'injected.txt'
        @'
'cwd=' + $PWD.Path
'count=' + $args.Count
foreach ($value in $args) { '<' + $value + '>' }
'@ | Set-Content -LiteralPath $probe -Encoding UTF8

        InModuleScope cdp -Parameters @{ ConfigPath=$script:ConfigPath; Probe=$probe; Marker=$marker; HostExe=$script:PowerShellExecutable } {
            $invocation = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @(
                'first','--config',$ConfigPath,'--yes','--',$HostExe,'-NoLogo','-NoProfile','-File',$Probe,
                'path with spaces',";touch $Marker"
            )
            $plan = New-CdpExecPlan -Invocation $invocation
            Invoke-CdpExecWorkers -Plan $plan

            $plan.Items[0].Status | Should -Be succeeded
            $plan.Items[0].Stdout | Should -Be (@(
                "cwd=$($plan.Items[0].ResolvedPath)", 'count=2', '<path with spaces>', "<;touch $Marker>"
            ) -join [Environment]::NewLine)
            Test-Path -LiteralPath $Marker | Should -BeFalse
        }
    }

    It 'continues after failures and fail-fast cancels future batches' {
        InModuleScope cdp -Parameters @{ ConfigPath=$script:ConfigPath; HostExe=$script:PowerShellExecutable; Probe=$script:ExitProbe } {
            $continueInvocation = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @(
                '--all','--config',$ConfigPath,'--jobs','1','--yes','--',$HostExe,
                '-NoLogo','-NoProfile','-File',$Probe,'first','7'
            )
            $continuePlan = New-CdpExecPlan -Invocation $continueInvocation
            Invoke-CdpExecWorkers -Plan $continuePlan
            @($continuePlan.Items.Status) | Should -Be @('failed','succeeded','succeeded')

            $fastInvocation = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @(
                '--all','--config',$ConfigPath,'--jobs','1','--fail-fast','--yes','--',$HostExe,
                '-NoLogo','-NoProfile','-File',$Probe,'first','7'
            )
            $fastPlan = New-CdpExecPlan -Invocation $fastInvocation
            Invoke-CdpExecWorkers -Plan $fastPlan
            @($fastPlan.Items.Status) | Should -Be @('failed','canceled','canceled')
            (New-CdpExecDocument -Plan $fastPlan -DurationMs 1).summary.exitCode | Should -Be 2
        }
    }

    It 'times out commands and dry-run creates no process side effect' {
        $marker = Join-Path $TestDrive 'marker.txt'
        InModuleScope cdp -Parameters @{ ConfigPath=$script:ConfigPath; Marker=$marker; HostExe=$script:PowerShellExecutable; Probe=$script:SleepProbe } {
            $timeoutInvocation = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @(
                'first','--config',$ConfigPath,'--timeout','1','--yes','--',$HostExe,
                '-NoLogo','-NoProfile','-File',$Probe
            )
            $timeoutPlan = New-CdpExecPlan -Invocation $timeoutInvocation
            Invoke-CdpExecWorkers -Plan $timeoutPlan
            $timeoutPlan.Items[0].Status | Should -Be timed_out

            $dryInvocation = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @(
                'first','--config',$ConfigPath,'--dry-run','--',$HostExe,'-NoLogo','-NoProfile','-Command',
                '[IO.File]::WriteAllText($args[0], "x")',$Marker
            )
            $dryPlan = New-CdpExecPlan -Invocation $dryInvocation
            Invoke-CdpExecPlan -Plan $dryPlan -Json | Out-Null
            Test-Path -LiteralPath $Marker | Should -BeFalse
            $dryPlan.Items[0].Status | Should -Be planned
        }
    }

    It 'emits one schema document with stable ordered results and exit code' {
        InModuleScope cdp -Parameters @{ ConfigPath=$script:ConfigPath; HostExe=$script:PowerShellExecutable; Probe=$script:ExitProbe } {
            $invocation = ConvertFrom-CdpInvokeArguments -Command exec -RemainingArgs @(
                '--all','--config',$ConfigPath,'--jobs','1','--json','--yes','--',$HostExe,
                '-NoLogo','-NoProfile','-File',$Probe,'second','5'
            )
            $plan = New-CdpExecPlan -Invocation $invocation
            Invoke-CdpExecWorkers -Plan $plan
            $document = New-CdpExecDocument -Plan $plan -DurationMs 12
            $json = $document | ConvertTo-Json -Depth 8 | ConvertFrom-Json

            $json.schemaVersion | Should -Be 1
            @($json.results.name) | Should -Be @('first','second','third')
            @($json.results.status) | Should -Be @('succeeded','failed','succeeded')
            $json.command.arguments[0] | Should -Be '-NoLogo'
            $json.summary.exitCode | Should -Be 1
        }
    }

    It 'routes a dry-run through Invoke-Cdp without leaking command options' {
        $output = @(Invoke-Cdp -Command exec -RemainingArgs @(
            'first','--config',$script:ConfigPath,'--json','--dry-run','--',$script:PowerShellExecutable,
            '-NoLogo','-NoProfile','-Command','exit 0','--json',''
        ))
        $document = ($output -join [Environment]::NewLine) | ConvertFrom-Json

        $document.results[0].status | Should -Be planned
        @($document.command.arguments | Select-Object -Last 2) | Should -Be @('--json','')
        $document.summary.exitCode | Should -Be 0
        $global:LASTEXITCODE | Should -Be 0
    }
}
