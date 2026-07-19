[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$CommandsAnalyzed,

    [Parameter(Mandatory = $true)]
    [int]$CommandsExecuted,

    [ValidateRange(0, 100)]
    [double]$MinimumPercent = 60
)

if ($CommandsAnalyzed -le 0) {
    throw 'Coverage requires at least one analyzed command.'
}
if ($CommandsExecuted -lt 0 -or $CommandsExecuted -gt $CommandsAnalyzed) {
    throw 'Coverage executed-command count must be between zero and the analyzed count.'
}

$coveragePercent = 100.0 * $CommandsExecuted / $CommandsAnalyzed
$message = 'PowerShell coverage: {0}/{1} commands ({2:N2}%); required >= {3:N2}%.' -f `
    $CommandsExecuted, $CommandsAnalyzed, $coveragePercent, $MinimumPercent
Write-Host $message

if ($coveragePercent -lt $MinimumPercent) {
    throw "Coverage threshold failed. $message"
}

[PSCustomObject]@{
    CommandsAnalyzed = $CommandsAnalyzed
    CommandsExecuted = $CommandsExecuted
    CoveragePercent = $coveragePercent
    MinimumPercent = $MinimumPercent
}
