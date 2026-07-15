[CmdletBinding(DefaultParameterSetName = 'Revision')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'MessageFile')]
    [ValidateNotNullOrEmpty()]
    [string]$MessageFile,

    [Parameter(ParameterSetName = 'Revision')]
    [ValidateNotNullOrEmpty()]
    [string]$Revision = 'HEAD',

    [Parameter(Mandatory = $true, ParameterSetName = 'All')]
    [switch]$All
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-CdpCommitMessageValidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message
    )

    if ([string]::IsNullOrWhiteSpace($Message)) {
        return [PSCustomObject]@{
            IsValid = $false
            Reason = 'commit message is empty'
        }
    }

    $invalidMatch = [regex]::Match($Message, '[^\x09\x0A\x0D\x20-\x7E]')
    if ($invalidMatch.Success) {
        $codePoint = [int][char]$invalidMatch.Value[0]
        return [PSCustomObject]@{
            IsValid = $false
            Reason = ('contains non-ASCII character U+{0:X4}' -f $codePoint)
        }
    }

    [PSCustomObject]@{
        IsValid = $true
        Reason = $null
    }
}

function Test-CdpCommitMessageFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $message = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8
    $validation = Get-CdpCommitMessageValidation -Message $message
    if (-not $validation.IsValid) {
        throw "Commit message policy failed: $($validation.Reason). Use English ASCII text only."
    }

    Write-Host 'Commit message policy passed.'
}

function Get-CdpCommitMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Commit
    )

    $messageLines = @(& git show --no-patch --format='%B' $Commit)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read commit message for $Commit."
    }

    [string]::Join("`n", $messageLines).TrimEnd()
}

function Test-CdpCommitHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$RevisionArguments
    )

    $commits = @(& git rev-list @RevisionArguments)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to enumerate revisions: $($RevisionArguments -join ' ')."
    }

    $failures = [System.Collections.Generic.List[string]]::new()
    foreach ($commit in $commits) {
        $message = Get-CdpCommitMessage -Commit $commit
        $validation = Get-CdpCommitMessageValidation -Message $message
        if (-not $validation.IsValid) {
            $subject = ($message -split "`r?`n", 2)[0]
            $failures.Add("$commit $($validation.Reason): $subject")
        }
    }

    if ($failures.Count -gt 0) {
        throw "Commit message policy failed:`n- $($failures -join "`n- ")"
    }

    Write-Host "Commit message policy passed for $($commits.Count) commit(s)."
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($PSCmdlet.ParameterSetName -eq 'MessageFile') {
        Test-CdpCommitMessageFile -Path $MessageFile
    } elseif ($PSCmdlet.ParameterSetName -eq 'All') {
        Test-CdpCommitHistory -RevisionArguments @('--all')
    } else {
        Test-CdpCommitHistory -RevisionArguments @($Revision)
    }
}
