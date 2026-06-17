# Progress

## Goal

Prepare `cdp` for a stronger public release by improving first-run clarity, terminal AI workflow fit, and visible product completeness.

## Release Polish Checklist

- [x] Create a public progress tracker for the release polish work.
- [x] Add `cdp <query>` fast matching.
  - Directly switch when a query has exactly one match.
  - Fall back to `fzf` when a query has multiple matches.
  - Keep positional custom config path compatibility for `.json` and path-like arguments.
- [x] Add batch Git repository scanning to generate/import project config.
- [x] Strengthen README comparison against `zoxide`, `autojump`, and plain `fzf cd` scripts.
- [x] Smooth the install path, especially first-time `fzf` setup.
- [x] Add real-world usage scenarios for multi-repo, AI CLI, and Windows + WSL workflows.

## Current Focus

Release polish checklist is complete. Current release step: publish version 1.4.1.

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
- Install path polish: `Install.ps1` parsed successfully on Windows PowerShell 5.1.
- Install path polish: `Invoke-Pester -Path ./tests -CI` passed 9 tests.
- Install path polish: `bash -n ./install-wsl.sh` and `bash -n ./src/cdp.sh` passed in WSL.
- Release 1.4.0: Windows PowerShell 5.1 `Invoke-Pester -Path ./tests -CI` passed 9 tests.
- Release 1.4.0: PowerShell 7 `Invoke-Pester -Path ./tests -CI` passed 9 tests.
- Release 1.4.0: `Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error` reported no errors.
- Release 1.4.0: WSL Arch `bash -n ./src/cdp.sh` and `bash -n ./install-wsl.sh` passed.
- Release 1.4.0: `git diff --check` reported no whitespace errors.
- Release 1.4.1: Added PowerShell session caches for project config parsing and `fzf` command resolution.
- Release 1.4.1: PowerShell 7 direct switch timing improved from about 154.6 ms to 16.6 ms on the second same-session call.
- Release 1.4.1: PowerShell 7 `Invoke-Pester -Path ./tests -CI` passed 10 tests.
- Release 1.4.1: Windows PowerShell 5.1 `Invoke-Pester -Path ./tests -CI` passed 10 tests.
- Release 1.4.1: `Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error` reported no errors.
- Release 1.4.1: WSL Arch `bash -n ./src/cdp.sh` and `bash -n ./install-wsl.sh` passed.
- Release 1.4.1: `git diff --check` reported no whitespace errors.
