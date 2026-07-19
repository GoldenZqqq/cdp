BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ManifestPath = Join-Path $script:RepoRoot 'cdp.psd1'
    $script:BootstrapPath = Join-Path $script:RepoRoot 'src/cdp.psm1'
    $script:DomainRoot = Join-Path $script:RepoRoot 'src/PowerShell'
}

Describe 'cdp PowerShell module layout' {
    It 'keeps the bootstrap free of function definitions and parse errors' {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:BootstrapPath,
            [ref]$tokens,
            [ref]$errors
        )

        @($errors).Count | Should -Be 0
        @($ast.FindAll({ param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true)).Count | Should -Be 0
    }

    It 'loads every domain file from the explicit bootstrap list' {
        $bootstrap = Get-Content -LiteralPath $script:BootstrapPath -Raw -Encoding UTF8
        $domainFiles = @(Get-ChildItem -LiteralPath $script:DomainRoot -Filter '*.ps1' -File)

        $domainFiles.Count | Should -BeGreaterThan 0
        foreach ($domainFile in $domainFiles) {
            $bootstrap | Should -Match ([regex]::Escape($domainFile.Name))
        }
    }

    It 'keeps every domain file within the project file limit' {
        $oversized = @(
            Get-ChildItem -LiteralPath $script:DomainRoot -Filter '*.ps1' -File |
                Where-Object { @(Get-Content -LiteralPath $_.FullName).Count -gt 600 }
        )

        $oversized | Should -BeNullOrEmpty
    }

    It 'does not allow domain files to dot-source each other' {
        $violations = @(
            Get-ChildItem -LiteralPath $script:DomainRoot -Filter '*.ps1' -File |
                Select-String -Pattern '(?m)^\s*\.\s+' -SimpleMatch:$false
        )

        $violations | Should -BeNullOrEmpty
    }

    It 'parses every PowerShell source file without errors' {
        $sourceFiles = @(
            Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'src') -Recurse -File |
                Where-Object { $_.Extension -in @('.ps1', '.psm1') }
        )

        foreach ($sourceFile in $sourceFiles) {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile(
                $sourceFile.FullName,
                [ref]$tokens,
                [ref]$errors
            )
            @($errors).Count | Should -Be 0 -Because $sourceFile.FullName
        }
    }
}

Describe 'cdp PowerShell module compatibility' {
    BeforeAll {
        Import-Module $script:ManifestPath -Force
        $script:Manifest = Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop
    }

    It 'preserves the manifest function and alias export surfaces' {
        $actualFunctions = @(Get-Command -Module cdp -CommandType Function).Name | Sort-Object
        $expectedFunctions = @($script:Manifest.ExportedFunctions.Keys) | Sort-Object
        $actualAliases = @(Get-Command -Module cdp -CommandType Alias).Name | Sort-Object
        $expectedAliases = @($script:Manifest.ExportedAliases.Keys) | Sort-Object

        $actualFunctions | Should -Be $expectedFunctions
        $actualAliases | Should -Be $expectedAliases
    }

    It 'imports within the module startup smoke threshold' {
        $elapsed = (Measure-Command {
            Import-Module $script:ManifestPath -Force
        }).TotalSeconds

        $elapsed | Should -BeLessThan 5
    }

    It 'ships recursive source files through every module packaging path' {
        $installScript = Get-Content (Join-Path $script:RepoRoot 'Install.ps1') -Raw
        $publishScript = Get-Content (Join-Path $script:RepoRoot 'Publish-ToGallery.ps1') -Raw
        $publishAltScript = Get-Content (Join-Path $script:RepoRoot 'Publish-ToGallery-Alt.ps1') -Raw
        $scoopScript = Get-Content (Join-Path $script:RepoRoot 'scripts/New-ScoopPackage.sh') -Raw

        $installScript | Should -Match '(?s)Copy-Item.*Join-Path.*"src".*-Recurse'
        $publishScript | Should -Match '(?s)Join-Path.*"src".*Copy-Item.*-Recurse'
        $publishAltScript | Should -Match '(?s)Copy-Item.*"src".*-Recurse'
        $scoopScript | Should -Match 'cp -R "\$repo_root/src/\." "\$package_root/src/"'
    }
}
