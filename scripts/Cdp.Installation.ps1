function ConvertTo-CdpNormalizedPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath
    )

    if ([string]::IsNullOrWhiteSpace($LiteralPath)) {
        throw 'A non-empty path is required.'
    }

    $fullPath = [System.IO.Path]::GetFullPath($LiteralPath)
    $rootPath = [System.IO.Path]::GetPathRoot($fullPath)
    if ($fullPath.Length -gt $rootPath.Length) {
        return $fullPath.TrimEnd([char[]]@('\', '/'))
    }

    $fullPath
}

function Resolve-CdpModuleInstallPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Core', 'Desktop')]
        [string]$Edition = $PSEdition,

        [Parameter(Mandatory = $false)]
        [string]$ModuleName = 'cdp',

        [Parameter(Mandatory = $false)]
        [string]$ModuleSearchPath = $env:PSModulePath,

        [Parameter(Mandatory = $false)]
        [string]$DocumentsPath = [Environment]::GetFolderPath('MyDocuments'),

        [Parameter(Mandatory = $false)]
        [string]$ProgramFilesPath = $env:ProgramFiles
    )

    $editionDirectory = if ($Edition -eq 'Core') { 'PowerShell' } else { 'WindowsPowerShell' }
    $scopeRoot = if ($Scope -eq 'CurrentUser') { $DocumentsPath } else { $ProgramFilesPath }
    $expectedRoot = Join-Path (Join-Path $scopeRoot $editionDirectory) 'Modules'
    $normalizedExpected = ConvertTo-CdpNormalizedPath -LiteralPath $expectedRoot
    $separatorPattern = [regex]::Escape([string][System.IO.Path]::PathSeparator)
    $matchingRoot = $null

    foreach ($searchRoot in @($ModuleSearchPath -split $separatorPattern)) {
        if ([string]::IsNullOrWhiteSpace($searchRoot)) {
            continue
        }

        $normalizedRoot = ConvertTo-CdpNormalizedPath -LiteralPath $searchRoot
        if ($normalizedRoot -eq $normalizedExpected) {
            $matchingRoot = $normalizedRoot
            break
        }
    }

    if (-not $matchingRoot) {
        throw "$Scope $Edition module root '$expectedRoot' is not present in PSModulePath."
    }

    Join-Path $matchingRoot $ModuleName
}

function Select-CdpInstalledModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$AvailableModules,

        [Parameter(Mandatory = $true)]
        [string]$ModulePath,

        [Parameter(Mandatory = $true)]
        [version]$ExpectedVersion
    )

    $normalizedTarget = ConvertTo-CdpNormalizedPath -LiteralPath $ModulePath
    $pathMatches = @($AvailableModules | Where-Object {
        $_ -and $_.ModuleBase -and
        (ConvertTo-CdpNormalizedPath -LiteralPath $_.ModuleBase) -eq $normalizedTarget
    })

    if ($pathMatches.Count -eq 0) {
        throw "Module was not discovered at target path '$ModulePath'."
    }

    $versionMatches = @($pathMatches | Where-Object { [version]$_.Version -eq $ExpectedVersion })
    if ($versionMatches.Count -eq 0) {
        $foundVersions = @($pathMatches | ForEach-Object { $_.Version.ToString() }) -join ', '
        throw "Module at '$ModulePath' has version '$foundVersions'; expected '$ExpectedVersion'."
    }

    $versionMatches | Sort-Object -Property Version -Descending | Select-Object -First 1
}
