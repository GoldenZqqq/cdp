BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    Import-Module (Join-Path $script:RepoRoot 'cdp.psd1') -Force

    function Invoke-StatusRemoteGit {
        param([string]$Path, [string[]]$Arguments)
        $output = @(& git -C $Path @Arguments 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $($output -join ' ')" }
        ($output -join "`n").Trim()
    }

    function New-StatusRemoteFixture {
        param([string]$Root, [string]$Name)
        $remote = Join-Path $Root "$Name-remote.git"
        $writer = Join-Path $Root "$Name-writer"
        $repository = Join-Path $Root "$Name-repository"
        New-Item -ItemType Directory -Path $remote,$writer | Out-Null
        Invoke-StatusRemoteGit $remote @('init','--quiet','--bare') | Out-Null
        Invoke-StatusRemoteGit $writer @('init','--quiet','-b','main') | Out-Null
        Invoke-StatusRemoteGit $writer @('config','user.email','tests@example.invalid') | Out-Null
        Invoke-StatusRemoteGit $writer @('config','user.name','cdp tests') | Out-Null
        'initial' | Set-Content -LiteralPath (Join-Path $writer 'tracked.txt') -Encoding UTF8
        Invoke-StatusRemoteGit $writer @('add','tracked.txt') | Out-Null
        Invoke-StatusRemoteGit $writer @('commit','--quiet','-m','initial') | Out-Null
        Invoke-StatusRemoteGit $writer @('remote','add','origin',$remote) | Out-Null
        Invoke-StatusRemoteGit $writer @('push','--quiet','-u','origin','main') | Out-Null
        Invoke-StatusRemoteGit $remote @('symbolic-ref','HEAD','refs/heads/main') | Out-Null
        $cloneOutput = @(& git clone --quiet $remote $repository 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "clone failed: $($cloneOutput -join ' ')" }
        Invoke-StatusRemoteGit $repository @('config','user.email','tests@example.invalid') | Out-Null
        Invoke-StatusRemoteGit $repository @('config','user.name','cdp tests') | Out-Null
        [PSCustomObject]@{ RemotePath=$remote; WriterPath=$writer; RepositoryPath=$repository }
    }

    function Initialize-StatusRemoteRepository {
        param([string]$Path)
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Invoke-StatusRemoteGit $Path @('init','--quiet','-b','main') | Out-Null
        Invoke-StatusRemoteGit $Path @('config','user.email','tests@example.invalid') | Out-Null
        Invoke-StatusRemoteGit $Path @('config','user.name','cdp tests') | Out-Null
    }

    function Add-StatusRemoteCommit {
        param([object]$Fixture, [string]$Message)
        Add-Content -LiteralPath (Join-Path $Fixture.WriterPath 'tracked.txt') -Value $Message -Encoding UTF8
        Invoke-StatusRemoteGit $Fixture.WriterPath @('add','tracked.txt') | Out-Null
        Invoke-StatusRemoteGit $Fixture.WriterPath @('commit','--quiet','-m',$Message) | Out-Null
        Invoke-StatusRemoteGit $Fixture.WriterPath @('push','--quiet','origin','main') | Out-Null
    }

    function Write-StatusRemoteConfig {
        param([string]$Path, [object[]]$Projects)
        ConvertTo-Json -InputObject @($Projects) -Depth 5 |
            Set-Content -LiteralPath $Path -Encoding UTF8
    }
}

Describe 'cdp status remote semantics' {
    It 'parses bounded fetch options and rejects invalid combinations' {
        InModuleScope cdp {
            $parsed = ConvertFrom-CdpInvokeArguments -Command status `
                -RemainingArgs @('--fetch','--fetch-jobs','2','--fetch-timeout','20')
            $parsed.Fetch | Should -BeTrue
            $parsed.FetchJobs | Should -Be 2
            $parsed.FetchTimeoutSeconds | Should -Be 20
            { ConvertFrom-CdpInvokeArguments -Command status -RemainingArgs @('--fetch-jobs','2') } |
                Should -Throw '*require --fetch*'
            { ConvertFrom-CdpInvokeArguments -Command status -RemainingArgs @('--fetch','--fix') } |
                Should -Throw '*cannot be used together*'
        }
    }

    It 'completes status fetch options through the registered boundary' {
        $config = Join-Path $TestDrive 'completion.json'
        '[]' | Set-Content -LiteralPath $config -Encoding UTF8
        $previousConfig = $env:CDP_CONFIG
        $env:CDP_CONFIG = $config
        try {
            $line = 'Invoke-Cdp status --f'
            $matches = @(TabExpansion2 $line $line.Length).CompletionMatches.CompletionText
            $matches | Should -Contain '--fetch'
            $matches | Should -Contain '--fetch-jobs'
            $matches | Should -Contain '--fetch-timeout'
            $matches | Should -Contain '--fix'
        } finally { $env:CDP_CONFIG = $previousConfig }
    }

    It 'routes normalized fetch settings to the status command' {
        InModuleScope cdp {
            Mock Show-CdpProjectStatus {}
            Invoke-Cdp status --fetch --fetch-jobs 2 --fetch-timeout 3
            Should -Invoke Show-CdpProjectStatus -Times 1 -Exactly -ParameterFilter {
                $Fetch -and $FetchJobs -eq 2 -and $FetchTimeoutSeconds -eq 3 -and
                    -not $Fix -and -not $Push
            }
        }
    }

    It 'keeps default status cached and refreshes only when explicitly fetched' {
        $fixture = New-StatusRemoteFixture $TestDrive freshness
        Add-StatusRemoteCommit $fixture remote-change
        $config = Join-Path $TestDrive 'freshness.json'
        Write-StatusRemoteConfig $config @([PSCustomObject]@{ name='Freshness'; rootPath=$fixture.RepositoryPath; enabled=$true })
        $before = Invoke-StatusRemoteGit $fixture.RepositoryPath @('rev-parse','refs/remotes/origin/main')

        $cached = @(Show-CdpProjectStatus -ConfigPath $config -PassThru)
        $afterCached = Invoke-StatusRemoteGit $fixture.RepositoryPath @('rev-parse','refs/remotes/origin/main')
        $refreshed = @(Show-CdpProjectStatus -ConfigPath $config -Fetch -PassThru)
        $afterFetch = Invoke-StatusRemoteGit $fixture.RepositoryPath @('rev-parse','refs/remotes/origin/main')

        $cached[0].Freshness | Should -Be 'cached'
        $afterCached | Should -Be $before
        $refreshed[0].Freshness | Should -Be 'refreshed'
        $refreshed[0].FetchSucceeded | Should -BeTrue
        $refreshed[0].BehindCount | Should -Be 1
        $afterFetch | Should -Not -Be $before
    }

    It 'distinguishes no-upstream and not-applicable projects' {
        $standalone = Join-Path $TestDrive 'standalone'
        Initialize-StatusRemoteRepository $standalone
        'initial' | Set-Content -LiteralPath (Join-Path $standalone 'tracked.txt') -Encoding UTF8
        Invoke-StatusRemoteGit $standalone @('add','tracked.txt') | Out-Null
        Invoke-StatusRemoteGit $standalone @('commit','--quiet','-m','initial') | Out-Null
        $detached = Join-Path $TestDrive 'detached'
        $cloneOutput = @(& git clone --quiet $standalone $detached 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "clone failed: $($cloneOutput -join ' ')" }
        Invoke-StatusRemoteGit $detached @('checkout','--quiet','--detach','HEAD') | Out-Null
        $nonGit = Join-Path $TestDrive 'non-git'
        New-Item -ItemType Directory -Path $nonGit | Out-Null
        $config = Join-Path $TestDrive 'states.json'
        Write-StatusRemoteConfig $config @(
            [PSCustomObject]@{ name='Standalone'; rootPath=$standalone; enabled=$true },
            [PSCustomObject]@{ name='Detached'; rootPath=$detached; enabled=$true },
            [PSCustomObject]@{ name='NonGit'; rootPath=$nonGit; enabled=$true },
            [PSCustomObject]@{ name='Missing'; rootPath=(Join-Path $TestDrive 'missing'); enabled=$true }
        )

        $results = @(Show-CdpProjectStatus -ConfigPath $config -Fetch -PassThru)

        ($results | Where-Object Name -eq Standalone).Freshness | Should -Be no-upstream
        ($results | Where-Object Name -eq Detached).Freshness | Should -Be no-upstream
        ($results | Where-Object Name -eq NonGit).Freshness | Should -Be not-applicable
        ($results | Where-Object Name -eq Missing).Freshness | Should -Be not-applicable
    }

    It 'redacts credential-bearing remote URLs from status identity' {
        $fixture = New-StatusRemoteFixture $TestDrive redaction
        Invoke-StatusRemoteGit $fixture.RepositoryPath @(
            'remote','set-url','origin','https://user:secret@example.invalid/repo.git?token=secret'
        ) | Out-Null
        InModuleScope cdp -Parameters @{ Path=$fixture.RepositoryPath } {
            $info = Get-CdpGitProjectInfo -Project ([PSCustomObject]@{ name='Redaction'; rootPath=$Path })
            Update-CdpStatusRemoteIdentity -Info $info
            $info.RemoteUrl | Should -Be 'https://***@example.invalid/repo.git'
            $info.RemoteUrl | Should -Not -Match 'secret|token='
        }
    }

    It 'reports mixed fetch failure without exposing native stderr' {
        $success = New-StatusRemoteFixture $TestDrive success
        $failure = New-StatusRemoteFixture $TestDrive failure
        Add-StatusRemoteCommit $success remote-change
        Invoke-StatusRemoteGit $failure.RepositoryPath @('remote','set-url','origin',(Join-Path $TestDrive 'missing-secret.git')) | Out-Null
        $config = Join-Path $TestDrive 'mixed.json'
        Write-StatusRemoteConfig $config @(
            [PSCustomObject]@{ name='Success'; rootPath=$success.RepositoryPath; enabled=$true },
            [PSCustomObject]@{ name='Failure'; rootPath=$failure.RepositoryPath; enabled=$true }
        )
        $errors = @()
        $results = @(Show-CdpProjectStatus -ConfigPath $config -Fetch -PassThru `
            -ErrorAction SilentlyContinue -ErrorVariable +errors)

        ($results | Where-Object Name -eq Success).Freshness | Should -Be refreshed
        ($results | Where-Object Name -eq Failure).Freshness | Should -Be fetch-failed
        ($results | Where-Object Name -eq Failure).FetchMessage | Should -Match '^fetch failed \(exit \d+\)$'
        ($results | Where-Object Name -eq Failure).FetchMessage | Should -Not -Match 'secret|missing-secret'
        @($errors | Where-Object FullyQualifiedErrorId -Match CdpStatusFetchFailed).Count | Should -BeGreaterOrEqual 1
    }

    It 'propagates aggregate fetch failure to a PowerShell CLI exit status' {
        $fixture = New-StatusRemoteFixture $TestDrive cli-failure
        Invoke-StatusRemoteGit $fixture.RepositoryPath @(
            'remote','set-url','origin',(Join-Path $TestDrive 'missing-cli-remote.git')
        ) | Out-Null
        $config = Join-Path $TestDrive 'cli-failure.json'
        Write-StatusRemoteConfig $config @(
            [PSCustomObject]@{ name='CliFailure'; rootPath=$fixture.RepositoryPath; enabled=$true }
        )
        $manifest = (Join-Path $script:RepoRoot 'cdp.psd1').Replace("'", "''")
        $escapedConfig = $config.Replace("'", "''")
        $childScript = @"
`$ErrorActionPreference = 'Continue'
Import-Module '$manifest' -Force
Invoke-Cdp status --fetch '$escapedConfig'
if (`$?) { exit 0 } else { exit 1 }
"@
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childScript))
        $executable = (Get-Process -Id $PID).Path
        $previousErrorAction = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & $executable -NoLogo -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1 | Out-Null
            $childExitCode = $LASTEXITCODE
        } finally { $ErrorActionPreference = $previousErrorAction }

        $childExitCode | Should -Be 1
    }

    It 'terminates a timed-out fetch process' {
        $executable = (Get-Process -Id $PID).Path
        $process = $null
        try {
            $result = InModuleScope cdp -Parameters @{ Executable=$executable; Root=$TestDrive } {
                $status = New-CdpGitProjectInfo -Project ([PSCustomObject]@{ name='Slow'; rootPath=$Root })
                $status.PathExists=$true; $status.IsGitRepo=$true; $status.Upstream='origin/main'
                $status.RemoteName='origin'; $status.RemoteRef='refs/heads/main'
                Mock Start-CdpStatusFetchProcess {
                    $start = New-Object Diagnostics.ProcessStartInfo
                    $start.FileName=$Executable; $start.Arguments='-NoLogo -NoProfile -Command "Start-Sleep -Seconds 30"'
                    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
                    $child=New-Object Diagnostics.Process; $child.StartInfo=$start; [void]$child.Start()
                    [PSCustomObject]@{ Status=$status; Process=$child; Stopwatch=[Diagnostics.Stopwatch]::StartNew() }
                }
                @(Invoke-CdpStatusFetchPlan -StatusList @($status) -Jobs 1 -TimeoutSeconds 1)[0]
            }
            $process = $result.Process
            $result.FetchTimedOut | Should -BeTrue
            $process.HasExited | Should -BeTrue
        } finally { if ($process -and -not $process.HasExited) { $process.Kill() } }
    }

    It 'terminates the real Git transport tree after a fetch timeout' {
        if ($env:OS -ne 'Windows_NT') {
            Set-ItResult -Skipped -Because 'Git Bash transport fixture is Windows-specific.'
            return
        }
        $fixture = New-StatusRemoteFixture $TestDrive transport-timeout
        $transport = Join-Path $TestDrive 'slow-transport.sh'
        $marker = Join-Path $TestDrive 'transport-orphan-marker'
        $toPosix = {
            param([string]$WindowsPath)
            '/' + $WindowsPath.Substring(0,1).ToLowerInvariant() +
                ($WindowsPath.Substring(2) -replace '\\','/')
        }
        $posixTransport = & $toPosix $transport
        $posixMarker = & $toPosix $marker
        [IO.File]::WriteAllText($transport, "sleep 2`nprintf 'orphaned\n' > ```$CDP_PS_STATUS_TIMEOUT_MARKER`nexit 1`n")
        Invoke-StatusRemoteGit $fixture.RepositoryPath @(
            'remote','set-url','origin',"ext::sh $posixTransport"
        ) | Out-Null
        $config = Join-Path $TestDrive 'transport-timeout.json'
        Write-StatusRemoteConfig $config @(
            [PSCustomObject]@{ name='Timeout'; rootPath=$fixture.RepositoryPath; enabled=$true }
        )
        $previousProtocol = $env:GIT_ALLOW_PROTOCOL
        $previousMarker = $env:CDP_PS_STATUS_TIMEOUT_MARKER
        try {
            $env:GIT_ALLOW_PROTOCOL = 'ext'
            $env:CDP_PS_STATUS_TIMEOUT_MARKER = $posixMarker
            $errors = @()
            $result = @(Show-CdpProjectStatus -ConfigPath $config -Fetch -FetchTimeoutSeconds 1 `
                -PassThru -ErrorAction SilentlyContinue -ErrorVariable +errors)
            $result[0].Freshness | Should -Be fetch-failed
            $result[0].FetchTimedOut | Should -BeTrue
            @($errors | Where-Object FullyQualifiedErrorId -Match CdpStatusFetchFailed).Count |
                Should -BeGreaterOrEqual 1
            Start-Sleep -Milliseconds 1500
            Test-Path -LiteralPath $marker | Should -BeFalse
        } finally {
            $env:GIT_ALLOW_PROTOCOL = $previousProtocol
            $env:CDP_PS_STATUS_TIMEOUT_MARKER = $previousMarker
        }
    }

    It 'pushes the frozen oid and exact target ref' {
        $fixture = New-StatusRemoteFixture $TestDrive snapshot
        'planned' | Set-Content -LiteralPath (Join-Path $fixture.RepositoryPath 'planned.txt') -Encoding UTF8
        Invoke-StatusRemoteGit $fixture.RepositoryPath @('add','planned.txt') | Out-Null
        Invoke-StatusRemoteGit $fixture.RepositoryPath @('commit','--quiet','-m','planned') | Out-Null
        $plannedOid = Invoke-StatusRemoteGit $fixture.RepositoryPath @('rev-parse','HEAD')
        $plan = InModuleScope cdp -Parameters @{ Path=$fixture.RepositoryPath } {
            $info = Get-CdpGitProjectInfo -Project ([PSCustomObject]@{ name='Snapshot'; rootPath=$Path })
            Update-CdpStatusRemoteIdentity -Info $info
            @(Get-CdpStatusPushPlan -StatusList @($info))
        }
        $gate = [PSCustomObject]@{ Path=$fixture.RepositoryPath }
        $gate | Add-Member ScriptMethod ShouldProcess {
            param($target,$action)
            'after' | Set-Content -LiteralPath (Join-Path $this.Path 'after.txt') -Encoding UTF8
            & git -C $this.Path add after.txt 2>&1 | Out-Null
            & git -C $this.Path commit --quiet -m after 2>&1 | Out-Null
            $true
        }
        InModuleScope cdp -Parameters @{ Plan=$plan; Gate=$gate } {
            Invoke-CdpStatusPushPlan -Cmdlet $Gate -PushPlan $Plan
        }

        Invoke-StatusRemoteGit $fixture.RemotePath @('rev-parse','refs/heads/main') | Should -Be $plannedOid
        Invoke-StatusRemoteGit $fixture.RepositoryPath @('rev-parse','HEAD') | Should -Not -Be $plannedOid
    }
}
