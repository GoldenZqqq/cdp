# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

cdp is a PowerShell module that provides fast, fuzzy-search-based project directory switching for Windows developers. It's designed for "Vibe Coding" workflows with CLI AI tools (Codex, Cursor, etc.) by offering instant project navigation using fzf.

**Key Concept**: The module reads project lists from either VS Code/Cursor Project Manager extension configs or custom JSON files, then provides an interactive fzf menu for instant project switching with automatic terminal tab title updates.

## Development Commands

### Testing Changes Locally

```powershell
# Import module with latest changes (always use -Force to reload)
Import-Module ./cdp.psd1 -Force

# Test main functionality
cdp
Switch-Project
Get-ProjectList

# Test with custom config
Switch-Project -ConfigPath "examples/projects.json"
```

### Installation Testing

```powershell
# Test the install script
.\Install.ps1

# Test with profile integration
.\Install.ps1 -AddToProfile

# Test AllUsers scope (requires admin)
.\Install.ps1 -Scope AllUsers
```

### Module Verification

```powershell
# Check if module is recognized
Get-Module -ListAvailable cdp

# Test module exports
Get-Command -Module cdp

# View module details
Get-Module cdp | Format-List
```

## Architecture

### Module Structure

- **cdp.psd1**: Canonical PowerShell version, metadata, functions, and aliases.
- **src/cdp.psm1**: Stable bootstrap that initializes module state, loads ordered `src/PowerShell/*.ps1` domains, and exports the public surface.
- **src/PowerShell/*.ps1**: Config, state, parser, projects, status, workspace, hooks, completion, health, and other bounded PowerShell domains.
- **src/Shell/*.sh**: Canonical bash/zsh domain sources. Edit these instead of the generated distribution.
- **src/cdp.sh**: Deterministically generated single-file shell artifact used by source/offline installs.
- **scripts/**: Repository-owned build, quality, benchmark, package, documentation, and release validation.
- **tests/**: Pester, bash/zsh/Bash 3.2, Node, and Playwright regression suites.
- **Install.ps1 / install-wsl.sh**: PowerShell and verified shell installer entries.

### Configuration Discovery Logic

An explicit `-ConfigPath` / positional config always wins. Otherwise discovery
uses this priority without persisting a choice:

1. `$env:CDP_CONFIG`
2. Saved explicit selection from `~/.cdp/config`
3. Cursor Project Manager
4. VS Code Project Manager
5. Custom `~/.cdp/projects.json`

PowerShell ownership: `src/PowerShell/Config.ps1`. Shell ownership:
`src/Shell/Config.sh`. Only `Set-ProjectConfig` / `cdp-config` writes the saved
selection.

### Core Execution Flows

- `Invoke-Cdp` / `cdp`: parse once in `Parser.ps1` / `Commands.sh`, then dispatch to switch, status, workspace, health, metadata, scan, config, or hook management.
- `Switch-Project`: resolve config, normalize project matches, use fzf only when needed, switch directory, record recent state, apply authorized onEnter behavior, and optionally launch a tool.
- `Show-CdpProjectStatus` / `cdp-status`: collect porcelain-v2 Git state with bounded workers, timeouts, optional TTL cache, and safe fix/push actions.
- `Invoke-CdpWorkspace` / `cdp-workspace`: persist named project groups beside the active config and launch through argv-safe platform adapters.
- JSON writes: use the shared atomic persistence boundary with fingerprints, locks, sibling temporary files, and bounded backups.

PowerShell and shell features must remain behaviorally aligned, but each runtime
keeps native implementation patterns and its own regression entry.

### JSON Config Format

Projects are defined as JSON objects with required identity fields and optional
cdp metadata:
```json
{
  "name": "api",
  "rootPath": "E:/Projects/api",
  "paths": {
    "windows": "E:/Projects/api",
    "wsl": "/home/me/api",
    "linux": "/srv/api",
    "macos": "/Users/me/api"
  },
  "enabled": true,
  "pinned": false,
  "aliases": ["backend"],
  "tags": ["work"],
  "onEnter": {
    "env": { "NODE_ENV": "development" },
    "powershell": "$env:API_PROFILE = 'local'",
    "bash": "export API_PROFILE=local"
  }
}
```

Recent state, workspace definitions, active selection, and hook trust remain in
separate files; see README state/persistence tables and backend Trellis specs.
`rootPath` is always the raw compatibility identity. Project filesystem, Git,
picker, workspace, and future exec behavior must call `Resolve-CdpProjectPath`
or `cdp_resolve_project_json` instead of adding local conversion branches.

## PowerShell Compatibility

- Supports PowerShell 5.1 (Desktop edition) and 7+ (Core edition)
- Uses `CompatiblePSEditions = @('Desktop', 'Core')` in manifest
- Uses UTF-8 encoding with `[Console]::OutputEncoding` to handle international characters in fzf

## Dependencies

- **fzf**: Required external dependency for fuzzy search UI
- Check: `Get-Command fzf -ErrorAction SilentlyContinue`
- **Auto-installation**: Install.ps1 automatically detects and installs fzf using winget/scoop/chocolatey if not found
- Manual installation methods: `winget install fzf`, `choco install fzf`, `scoop install fzf`

## Coding Conventions (from CONTRIBUTING.md)

- Use PowerShell approved verbs (Get-, Set-, Switch-, etc.)
- 4 spaces for indentation
- Comment-based help for all functions
- Color coding for messages: Red (errors), Yellow (warnings), Green (success), Cyan (headers), Gray (secondary info)
- Error handling with try-catch blocks
- Test manually on both PowerShell 5.1 and 7+

## Commit Message Format

Use Conventional Commits: `<type>(scope): <summary>`.

- Scope is optional.
- Summary is concise Chinese, starts with a verb, is at most 50 characters, and has no trailing period.
- Common types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`.

Examples: `feat: 增加项目能力`, `fix(status): 修复仓库判断`,
`test(web): 增加官网回归`.

## CRITICAL Development Guidelines

⚠️ **IMPORTANT**: These synchronization rules are mandatory and must be followed for EVERY change.

### 1. Documentation Synchronization

**RULE**: English is the canonical and default public language for this project. Any change that affects user-facing functionality MUST be documented in BOTH maintained language versions:
- `README.md` (English canonical version and GitHub default)
- `README_ZH.md` (Simplified Chinese mirror)

`README_EN.md` is a legacy compatibility redirect only. Do not add or maintain product documentation there.

The official website, SEO metadata, code examples, release notes, and newly added public documentation default to English. Chinese content is available through an explicit language switch or `_ZH` companion file.

**When to update**:
- Adding new features
- Modifying existing functionality
- Changing command usage or parameters
- Adding/removing dependencies
- Updating installation methods

**How to synchronize**:
1. Make changes to code first
2. Update README.md with the English description first
3. Update README_ZH.md with the equivalent Simplified Chinese description
4. Ensure both READMEs have identical structure and information
5. Review both files before committing

### 2. PowerShell Module Version Management

**RULE**: Any change to PowerShell module files requires version update and Gallery re-publishing:

**Files that trigger version updates**:
- `src/cdp.psm1` (PowerShell module implementation)
- `cdp.psd1` (Module manifest)
- Any exported function changes

**Version update procedure**:
1. Modify the PowerShell code in `src/cdp.psm1` or related files
2. Update version number in `cdp.psd1`:
   - **PATCH** (x.x.X): Bug fixes, minor improvements
   - **MINOR** (x.X.0): New features, backward-compatible changes
   - **MAJOR** (X.0.0): Breaking changes
3. Update `ReleaseNotes` in `cdp.psd1` with change description
4. Test locally: `Import-Module ./cdp.psd1 -Force`
5. Publish to PowerShell Gallery:
   ```powershell
   # Use alternative publishing script (avoids .NET SDK issues)
   .\Publish-ToGallery-Alt.ps1 -ApiKey "your-api-key"
   ```
6. Verify publication at: https://www.powershellgallery.com/packages/cdp

**Note**: WSL/bash changes (`src/cdp.sh`) do NOT require PowerShell Gallery updates, but still need version updates in the bash script header.

### 3. Cross-Platform Consistency

**RULE**: Features must work identically across both PowerShell and WSL/bash versions.

**When implementing new features**:
1. Implement in PowerShell version (`src/cdp.psm1`)
2. Implement equivalent functionality in bash version (`src/cdp.sh`)
3. Ensure both versions:
   - Accept same parameters
   - Produce similar output format
   - Handle errors consistently
   - Share configuration files

### 4. Pre-Commit Checklist

Before committing ANY change, verify:

- [ ] PowerShell changes tested locally
- [ ] Bash/WSL changes tested in WSL environment
- [ ] README.md updated in English (if user-facing change)
- [ ] README_ZH.md updated in Simplified Chinese (if user-facing change)
- [ ] Version number incremented (if PowerShell module changed)
- [ ] ReleaseNotes updated in cdp.psd1 (if version changed)
- [ ] Commit message follows format (Add/Fix/Update/Docs/Refactor)

### 5. Release Publishing Workflow

**RULE**: A public version release is not complete until the git commit, git tag, GitHub Release, PowerShell Gallery package, CI, and post-release verification all succeed.

**Release preparation checklist**:

1. Decide the semantic version bump.
   - **PATCH** (x.x.X): Bug fixes, minor improvements
   - **MINOR** (x.X.0): New features, backward-compatible changes
   - **MAJOR** (X.0.0): Breaking changes
2. Update all versioned release files:
   - `cdp.psd1` `ModuleVersion`
   - `cdp.psd1` `ReleaseNotes`
   - `src/cdp.psm1` header version
   - `src/cdp.sh` header version
   - `tests/cdp.Tests.ps1` expected manifest version
   - `scoop/cdp.json` `version`, tag URL, and `extract_dir`
   - `CHANGELOG.md` release section
3. Update `README.md` and `README_ZH.md` when the release changes user-facing behavior.
4. Keep private submission pitches or one-off promotion copy out of repository Markdown unless explicitly requested.

**Required local validation before the release commit**:

```powershell
powershell -NoLogo -NoProfile -File .\scripts\Invoke-PowerShellQualityGate.ps1 -ReportDirectory .\artifacts\powershell-51
pwsh -NoLogo -NoProfile -File .\scripts\Invoke-PowerShellQualityGate.ps1 -ReportDirectory .\artifacts\powershell-7
```

```bash
bash ./scripts/Build-ShellScript.sh --check
shellcheck --severity=error --exclude=SC2296 ./src/cdp.sh ./src/Shell/*.sh ./install-wsl.sh ./scripts/*.sh ./tests/*.Tests.sh
bash ./tests/cdp.Shell.Modularization.Tests.sh
bash ./tests/cdp.Cli.Tests.sh
bash ./tests/cdp.Status.Tests.sh
bash ./tests/cdp.Status.Performance.Tests.sh
bash ./tests/cdp.SafeMutations.Tests.sh
bash ./tests/cdp.Shell.V2.Tests.sh
bash ./tests/cdp.Persistence.Tests.sh
zsh ./tests/cdp.Shell.V2.Tests.sh
zsh ./tests/cdp.Persistence.Tests.sh
bash ./tests/cdp.Installer.Tests.sh
bash ./scripts/Test-ScoopPackage.sh
node ./scripts/Test-Documentation.mjs
pnpm --dir tests/web install --frozen-lockfile
pnpm --dir tests/web test
git diff --check
```

**Git release steps**:

1. Confirm the worktree is clean except for the intended release changes:
   ```powershell
   git status --short
   ```
2. Rebase on the remote branch before committing:
   ```powershell
   git pull --rebase --autostash
   ```
3. Commit the release preparation:
   ```powershell
   git add CHANGELOG.md PROGRESS.md cdp.psd1 scoop/cdp.json src/cdp.psm1 src/cdp.sh tests/cdp.Tests.ps1 README.md README_ZH.md
   git commit -m "chore: 准备 x.y.z 发布"
   ```
4. Push the release commit:
   ```powershell
   git push origin main
   ```
5. Wait for GitHub Actions CI on `main` to finish successfully:
   ```powershell
   gh run list --branch main --limit 5
   gh run watch <run-id> --exit-status
   ```
6. Create and push an annotated release tag only after the final release commit is on `main`:
   ```powershell
   git tag -a vx.y.z -m "Release vx.y.z: Brief description"
   git push origin vx.y.z
   ```
7. Verify the tag points to the final commit:
   ```powershell
   git rev-parse HEAD
   git rev-parse "vx.y.z^{}"
   git ls-remote --tags origin vx.y.z
   ```

**If any release-blocking fix is needed after tagging**:

1. Commit and push the fix first.
2. Move the local annotated tag to the new final commit.
3. Force-update the remote tag before publishing GitHub Release or Gallery package:
   ```powershell
   git tag -f -a vx.y.z -m "Release vx.y.z: Brief description"
   git push --force origin vx.y.z
   ```

**GitHub Release steps**:

1. Create the GitHub Release from the existing verified tag:
   ```powershell
   gh release create vx.y.z --verify-tag --latest --title "vx.y.z" --notes-file -
   ```
2. Verify it is public, non-draft, and non-prerelease:
   ```powershell
   gh release view vx.y.z --json tagName,name,url,isDraft,isPrerelease,publishedAt,targetCommitish
   ```

**PowerShell Gallery steps**:

1. Confirm `$env:PS_GALLERY_API_KEY` exists without printing the key:
   ```powershell
   if ([string]::IsNullOrWhiteSpace($env:PS_GALLERY_API_KEY)) { "PS_GALLERY_API_KEY_MISSING" } else { "PS_GALLERY_API_KEY_PRESENT" }
   ```
2. Publish with the alternative script:
   ```powershell
   .\Publish-ToGallery-Alt.ps1 -ApiKey $env:PS_GALLERY_API_KEY
   ```
3. Wait for Gallery indexing if needed.
4. Verify the exact version through both PowerShellGet and the package page:
   ```powershell
   pwsh -NoLogo -NoProfile -Command '$m = Find-Module -Name cdp -Repository PSGallery -ErrorAction Stop; $m | Select-Object Name,Version,Repository,ProjectUri | Format-List'
   pwsh -NoLogo -NoProfile -Command 'Invoke-WebRequest -Uri "https://www.powershellgallery.com/packages/cdp/x.y.z" -UseBasicParsing -MaximumRedirection 5 -ErrorAction Stop | Select-Object StatusCode'
   ```

**Release completion report must include**:

- Release commit SHA and tag name
- GitHub Release URL
- PowerShell Gallery URL and verified version
- CI result
- Any warnings that do not block the release, such as GitHub Actions runtime deprecation warnings

**API Key Management**:
- Store API key in environment variable: `$env:PS_GALLERY_API_KEY`
- Get API key from: https://www.powershellgallery.com/account/apikeys
- Never commit API keys to repository


## Testing Checklist

When making changes, manually test:
- PowerShell 5.1 and PowerShell 7+ compatibility
- VS Code Project Manager config detection
- Cursor Project Manager config detection
- Custom config path via parameter
- Custom config path via environment variable
- Auto-installation of fzf via Install.ps1
- Error handling when fzf not installed and auto-install fails
- Error handling when config not found
- Terminal tab title update in Windows Terminal
- UTF-8 encoding with international characters

## Common Development Patterns

### Adding New Configuration Sources

When adding support for new project management tools:
1. Update both `src/PowerShell/Config.ps1` and `src/Shell/Config.sh`.
2. Keep automatic discovery read-only; persistence belongs to explicit config selection.
3. Update diagnostics and both README files.
4. Test existing and new sources in PowerShell and shell regressions.

### Adding New Functions

1. Add the function to the narrowest `src/PowerShell/*.ps1` domain.
2. Include comment-based help with .SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE
3. Export in cdp.psd1 under `FunctionsToExport`
4. Add alias in `AliasesToExport` if needed
5. Add the equivalent shell route/domain behavior when user-facing.
6. Update command lists in both README files; the documentation gate checks manifest coverage.
7. Run the PowerShell, shell, documentation, package, and release-metadata gates.

### Modifying fzf Options

fzf configuration lives in `src/PowerShell/Picker.ps1` and
`src/Shell/Picker.sh`. Options include:
- `--prompt`: Search prompt text
- `--height`: Menu height (percentage or lines)
- `--layout`: reverse, default
- `--border`: Border style
- `--preview-window`: Preview pane config (currently hidden)

Users can override via `$env:FZF_DEFAULT_OPTS` environment variable.

## Version Management

Update the `ModuleVersion` field in `cdp.psd1` using semantic versioning
(MAJOR.MINOR.PATCH), then synchronize every release mirror through the release
metadata workflow.
