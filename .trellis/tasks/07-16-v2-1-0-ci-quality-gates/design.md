# CI Quality Gate Design

## Repository-Owned Gates

CI workflows select the platform and install pinned tools. Product assertions
live in repository scripts:

- `scripts/Invoke-PowerShellQualityGate.ps1` runs the full Pester suite once,
  produces NUnit and JaCoCo reports, enforces coverage, runs PSScriptAnalyzer,
  and validates release metadata.
- `scripts/Test-CoverageThreshold.ps1` owns the auditable coverage calculation
  and failure message so the threshold can be tested without recursively
  launching Pester.
- `scripts/Test-ScoopPackage.sh` builds the deterministic release archive,
  checks required and forbidden entries, and compares its SHA-256 to the Scoop
  manifest.

Existing shell test entry points remain canonical. The workflow invokes them by
layer so failures identify syntax, generated artifact, lint, behavior,
installer, or package integrity independently.

## Version and Coverage Policy

- Pester is pinned to `5.7.1` for Windows PowerShell 5.1 and PowerShell 7.
- PSScriptAnalyzer is pinned to `1.24.0`.
- PowerShell command coverage includes `src/cdp.psm1` and every
  `src/PowerShell/*.ps1` domain file.
- The initial required threshold is 60%. The measured baseline is 67.54%
  (`2097/3105`) under PowerShell 7.5.2 and Pester 5.7.1.
- The quality script reports analyzed/executed command counts and percentage.

## Workflow Boundaries

- Each job has an explicit timeout.
- PowerShell 5.1 and 7 run the same repository-owned quality script.
- PowerShell 7 uploads coverage and test-result artifacts even when a gate
  fails.
- Ubuntu owns Bash, Bash 3.2, package, and deterministic hash verification.
- macOS owns zsh plus macOS dependency and installer compatibility.

## Negative Validation

- Coverage threshold helper is tested with passing and deliberately failing
  percentages.
- Package verification is run once with the manifest hash and once with a
  deliberately incorrect expected hash.
- Existing metadata and shell-installer tests retain their deliberate drift
  fixtures.

## Rollback

The workflow can temporarily call the previous individual commands while the
repository scripts remain available locally. Coverage threshold changes require
an updated measured baseline and must never be silently disabled.
