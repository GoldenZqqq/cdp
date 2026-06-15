# Progress

## Goal

Prepare `cdp` for a stronger Ruan Yifeng Weekly submission by improving first-run clarity, terminal AI workflow fit, and visible product completeness.

## Submission Readiness Checklist

- [x] Create a public progress tracker for the submission polish work.
- [x] Add `cdp <query>` fast matching.
  - Directly switch when a query has exactly one match.
  - Fall back to `fzf` when a query has multiple matches.
  - Keep positional custom config path compatibility for `.json` and path-like arguments.
- [x] Add batch Git repository scanning to generate/import project config.
- [ ] Strengthen README comparison against `zoxide`, `autojump`, and plain `fzf cd` scripts.
- [ ] Add a concise Chinese submission pitch for the weekly.
- [ ] Smooth the install path, especially first-time `fzf` setup.
- [ ] Add real-world usage scenarios for multi-repo, AI CLI, and Windows + WSL workflows.

## Current Focus

Next up: strengthen the README comparison against `zoxide`, `autojump`, and plain `fzf cd` scripts.

## Verification Log

- PowerShell 7 Pester: `Invoke-Pester -Path ./tests -CI` passed 7 tests.
- PSScriptAnalyzer: `Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error` reported no errors.
- Windows PowerShell 5.1: `Test-ModuleManifest -Path ./cdp.psd1` loaded version 1.3.0.
- Windows PowerShell 5.1: `Invoke-Cdp` exposes the new `Query` parameter.
- WSL Arch: `bash -n ./src/cdp.sh` passed.
- Local WSL query smoke was not run end-to-end because this Arch distro does not have `jq`; the CI workflow installs `jq` and now includes the query smoke.
- Windows `jq`: the exact-match and contains-match filters used by bash query mode returned the expected enabled project.
- PowerShell 7 Pester after Git scan import: `Invoke-Pester -Path ./tests -CI` passed 9 tests.
- PSScriptAnalyzer after Git scan import: `Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error` reported no errors.
- CI bash smoke now creates two fake Git repositories and checks `cdp-scan` writes both to JSON.
