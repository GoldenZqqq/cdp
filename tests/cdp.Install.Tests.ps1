BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:InstallationFunctions = Join-Path $script:RepoRoot 'scripts\Cdp.Installation.ps1'
    $script:MetadataValidator = Join-Path $script:RepoRoot 'scripts\Test-ReleaseMetadata.ps1'
    . $script:InstallationFunctions

    function New-CdpMetadataFixture {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Destination
        )

        $relativeFiles = @(
            'cdp.psd1',
            'CHANGELOG.md',
            'PROGRESS.md',
            'src\cdp.psm1',
            'src\cdp.sh',
            'tests\cdp.Tests.ps1',
            'scoop\cdp.json'
        )

        foreach ($relativeFile in $relativeFiles) {
            $target = Join-Path $Destination $relativeFile
            $targetParent = Split-Path $target -Parent
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $script:RepoRoot $relativeFile) -Destination $target -Force
        }
    }

    function Get-CdpCurrentPowerShellExecutable {
        if ($PSVersionTable.PSEdition -eq 'Desktop') {
            return Join-Path $PSHOME 'powershell.exe'
        }

        Join-Path $PSHOME 'pwsh.exe'
    }
}

Describe 'cdp installer path resolution' {
    BeforeEach {
        $script:DocumentsPath = Join-Path $TestDrive 'Documents'
        $script:ProgramFilesPath = Join-Path $TestDrive 'ProgramFiles'
        $script:ModuleRoots = @(
            (Join-Path $script:DocumentsPath 'PowerShell\Modules'),
            (Join-Path $script:DocumentsPath 'WindowsPowerShell\Modules'),
            (Join-Path $script:ProgramFilesPath 'PowerShell\Modules'),
            (Join-Path $script:ProgramFilesPath 'WindowsPowerShell\Modules')
        )
        $script:ModuleSearchPath = $script:ModuleRoots -join [System.IO.Path]::PathSeparator
    }

    It 'resolves <Edition> <Scope> to the discoverable edition root' -TestCases @(
        @{ Scope = 'CurrentUser'; Edition = 'Core'; RootIndex = 0 }
        @{ Scope = 'CurrentUser'; Edition = 'Desktop'; RootIndex = 1 }
        @{ Scope = 'AllUsers'; Edition = 'Core'; RootIndex = 2 }
        @{ Scope = 'AllUsers'; Edition = 'Desktop'; RootIndex = 3 }
    ) {
        param($Scope, $Edition, $RootIndex)

        $parameters = @{
            Scope = $Scope
            Edition = $Edition
            ModuleName = 'cdp'
            ModuleSearchPath = $script:ModuleSearchPath
            DocumentsPath = $script:DocumentsPath
            ProgramFilesPath = $script:ProgramFilesPath
        }
        $actual = Resolve-CdpModuleInstallPath @parameters

        $actual | Should -Be (Join-Path $script:ModuleRoots[$RootIndex] 'cdp')
    }

    It 'fails when the edition root is not discoverable' {
        $parameters = @{
            Scope = 'CurrentUser'
            Edition = 'Core'
            ModuleSearchPath = (Join-Path $script:DocumentsPath 'WindowsPowerShell\Modules')
            DocumentsPath = $script:DocumentsPath
            ProgramFilesPath = $script:ProgramFilesPath
        }

        { Resolve-CdpModuleInstallPath @parameters } | Should -Throw '*not present in PSModulePath*'
    }
}

Describe 'cdp installer target verification' {
    It 'selects only the module at the exact target path and version' {
        $targetPath = Join-Path $TestDrive 'PowerShell\Modules\cdp'
        $available = @(
            [PSCustomObject]@{ ModuleBase = (Join-Path $TestDrive 'old\cdp'); Version = [version]'9.0.0' }
            [PSCustomObject]@{ ModuleBase = $targetPath; Version = [version]'2.0.4' }
        )

        $parameters = @{
            AvailableModules = $available
            ModulePath = $targetPath
            ExpectedVersion = [version]'2.0.4'
        }
        $actual = Select-CdpInstalledModule @parameters

        $actual.ModuleBase | Should -Be $targetPath
        $actual.Version | Should -Be ([version]'2.0.4')
    }

    It 'rejects an old module found outside the target path' {
        $targetPath = Join-Path $TestDrive 'PowerShell\Modules\cdp'
        $parameters = @{
            AvailableModules = @(
                [PSCustomObject]@{ ModuleBase = (Join-Path $TestDrive 'old\cdp'); Version = [version]'2.0.4' }
            )
            ModulePath = $targetPath
            ExpectedVersion = [version]'2.0.4'
        }

        { Select-CdpInstalledModule @parameters } | Should -Throw '*not discovered at target path*'
    }

    It 'rejects the wrong version at the target path' {
        $targetPath = Join-Path $TestDrive 'PowerShell\Modules\cdp'
        $parameters = @{
            AvailableModules = @(
                [PSCustomObject]@{ ModuleBase = $targetPath; Version = [version]'2.0.3' }
            )
            ModulePath = $targetPath
            ExpectedVersion = [version]'2.0.4'
        }

        { Select-CdpInstalledModule @parameters } | Should -Throw '*expected ''2.0.4''*'
    }
}

Describe 'cdp release metadata validation' {
    It 'accepts the current repository metadata' {
        { & $script:MetadataValidator -RepositoryRoot $script:RepoRoot } | Should -Not -Throw
    }

    It 'returns nonzero and identifies a Scoop version drift' {
        $fixture = Join-Path $TestDrive 'metadata-fixture'
        New-CdpMetadataFixture -Destination $fixture
        $scoopPath = Join-Path $fixture 'scoop\cdp.json'
        $scoop = Get-Content -LiteralPath $scoopPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $scoop.version = '9.9.9'
        $scoop | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $scoopPath -Encoding UTF8

        $hostExecutable = Get-CdpCurrentPowerShellExecutable
        $previousErrorAction = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = @(& $hostExecutable -NoLogo -NoProfile -File $script:MetadataValidator -RepositoryRoot $fixture 2>&1)
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorAction
        }

        $exitCode | Should -Not -Be 0
        ($output -join [Environment]::NewLine) | Should -Match 'scoop\.version'
    }
}
