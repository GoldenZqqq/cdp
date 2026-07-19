BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\cdp.psd1'
    Import-Module $modulePath -Force
    function Get-TestFileHash {
        param([string]$Path)
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

Describe 'cdp safe mutation contracts' {
    It 'keeps project config bytes unchanged for low-risk WhatIf actions' {
        $projectPath = Join-Path $TestDrive 'low-project'
        $newPath = Join-Path $TestDrive 'low-new-project'
        $configPath = Join-Path $TestDrive 'low-projects.json'
        New-Item -ItemType Directory -Path $projectPath, $newPath | Out-Null
        @([PSCustomObject]@{
            name = 'Project'; rootPath = $projectPath; enabled = $true
            pinned = $false; aliases = @(); tags = @()
        }) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8
        $before = Get-TestFileHash $configPath

        $add = Add-Project -Name New -Path $newPath -ConfigPath $configPath -WhatIf -PassThru
        $pin = Set-ProjectPin -Name Project -ConfigPath $configPath -WhatIf -PassThru
        $tag = Add-ProjectTag -Name Project -Tag work -ConfigPath $configPath -WhatIf -PassThru

        $add.Status | Should -Be 'preview'
        $pin.Status | Should -Be 'preview'
        $tag.Status | Should -Be 'preview'
        (Get-TestFileHash $configPath) | Should -Be $before
    }

    It 'keeps config bytes unchanged for repair scan and remove WhatIf actions' {
        $projectPath = Join-Path $TestDrive 'high-project'
        $scanRoot = Join-Path $TestDrive 'high-scan'
        $repoPath = Join-Path $scanRoot 'api'
        $configPath = Join-Path $TestDrive 'high-projects.json'
        New-Item -ItemType Directory -Path $projectPath | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $repoPath '.git') -Force | Out-Null
        @([PSCustomObject]@{ name = 'Project'; rootPath = $projectPath; enabled = $true }) |
            ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8
        $before = Get-TestFileHash $configPath

        $repair = Repair-ProjectConfig -ConfigPath $configPath -WhatIf -PassThru
        $scan = Import-GitProjects -RootPath $scanRoot -ConfigPath $configPath -WhatIf -PassThru
        $remove = Remove-Project -Name Project -ConfigPath $configPath -WhatIf -PassThru

        $repair.Status | Should -Be 'preview'
        $scan.Status | Should -Be 'preview'
        $remove.Status | Should -Be 'preview'
        (Get-TestFileHash $configPath) | Should -Be $before
    }

    It 'does not start workspace processes under WhatIf' {
        $projectPath = Join-Path $TestDrive 'preview-project'
        $configPath = Join-Path $TestDrive 'preview-projects.json'
        $workspacePath = Join-Path $TestDrive 'workspaces.json'
        New-Item -ItemType Directory -Path $projectPath | Out-Null
        @([PSCustomObject]@{ name = 'Api'; rootPath = $projectPath; enabled = $true }) |
            ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8
        @([PSCustomObject]@{ name = 'team'; projects = @('Api') }) |
            ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $workspacePath -Encoding UTF8

        InModuleScope cdp -Parameters @{ ConfigPath = $configPath } {
            Mock Get-Command { [PSCustomObject]@{ Name = 'wt.exe' } } -ParameterFilter { $Name -eq 'wt.exe' }
            Mock Start-Process {}

            $results = @(Invoke-CdpWorkspace -Name team -ConfigPath $ConfigPath -WhatIf -PassThru)

            Should -Invoke Start-Process -Times 0
            $results.Count | Should -Be 1
            $results[0].Status | Should -Be 'preview'
        }
    }

    It 'continues workspace targets after a process failure' {
        $firstPath = Join-Path $TestDrive 'first'
        $secondPath = Join-Path $TestDrive 'second'
        $configPath = Join-Path $TestDrive 'projects.json'
        $workspacePath = Join-Path $TestDrive 'workspaces.json'
        New-Item -ItemType Directory -Path $firstPath, $secondPath | Out-Null
        @(
            [PSCustomObject]@{ name = 'First'; rootPath = $firstPath; enabled = $true },
            [PSCustomObject]@{ name = 'Second'; rootPath = $secondPath; enabled = $true }
        ) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8
        @([PSCustomObject]@{ name = 'team'; projects = @('First', 'Second') }) |
            ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $workspacePath -Encoding UTF8

        InModuleScope cdp -Parameters @{ ConfigPath = $configPath } {
            $script:launchCount = 0
            Mock Get-Command { [PSCustomObject]@{ Name = 'wt.exe' } } -ParameterFilter { $Name -eq 'wt.exe' }
            Mock Start-Process {
                $script:launchCount++
                if ($script:launchCount -eq 1) { throw 'first failed' }
            }

            $results = @(Invoke-CdpWorkspace -Name team -ConfigPath $ConfigPath -Confirm:$false -PassThru)

            Should -Invoke Start-Process -Times 2
            @($results | Where-Object Status -eq failed).Count | Should -Be 1
            @($results | Where-Object Status -eq succeeded).Count | Should -Be 1
        }
    }
}
