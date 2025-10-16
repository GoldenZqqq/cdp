# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ProjSwitch is a PowerShell module that provides fast, fuzzy-search-based project directory switching for Windows developers. It's designed for "Vibe Coding" workflows with CLI AI tools (Claude Code, Cursor, etc.) by offering instant project navigation using fzf.

**Key Concept**: The module reads project lists from either VS Code/Cursor Project Manager extension configs or custom JSON files, then provides an interactive fzf menu for instant project switching with automatic terminal tab title updates.

## Development Commands

### Testing Changes Locally

```powershell
# Import module with latest changes (always use -Force to reload)
Import-Module ./ProjSwitch.psd1 -Force

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
Get-Module -ListAvailable ProjSwitch

# Test module exports
Get-Command -Module ProjSwitch

# View module details
Get-Module ProjSwitch | Format-List
```

## Architecture

### Module Structure

- **ProjSwitch.psd1**: Module manifest defining metadata, version, exports (functions: `Switch-Project`, `Get-ProjectList`; alias: `cdp`)
- **src/ProjSwitch.psm1**: Core implementation with all functions
- **Install.ps1**: Installation script that automatically installs fzf (if needed) and copies module to PowerShell modules directory

### Configuration Discovery Logic

The module searches for project configuration in priority order:

1. `-ConfigPath` parameter (explicit override)
2. `$env:PROJSWITCH_CONFIG` environment variable
3. Cursor Project Manager: `$env:APPDATA\Cursor\User\globalStorage\alefragnani.project-manager\projects.json`
4. VS Code Project Manager: `$env:APPDATA\Code\User\globalStorage\alefragnani.project-manager\projects.json`

See src/ProjSwitch.psm1:61-87 for implementation.

### Core Functions

**Switch-Project (alias: cdp)**
- Validates fzf installation (src/ProjSwitch.psm1:49-54)
- Discovers config path using priority logic (src/ProjSwitch.psm1:61-87)
- Parses JSON and filters enabled projects (src/ProjSwitch.psm1:95-108)
- Launches fzf with UTF-8 encoding handling (src/ProjSwitch.psm1:110-125)
- Changes directory and updates terminal tab title using ANSI escape sequences (src/ProjSwitch.psm1:128-143)

**Get-ProjectList**
- Uses same config discovery logic
- Displays formatted list of enabled projects with paths

### JSON Config Format

Projects are defined as JSON objects with three fields:
```json
{
  "name": "Display name in fzf menu",
  "rootPath": "Absolute path (use \\\\ or / for Windows)",
  "enabled": true/false
}
```

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

- `Add:` for new features
- `Fix:` for bug fixes
- `Update:` for updates to existing features
- `Docs:` for documentation changes
- `Refactor:` for code refactoring

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
1. Add path detection in the config discovery logic (src/ProjSwitch.psm1:68-86)
2. Update the error message with the new path (src/ProjSwitch.psm1:77-84)
3. Test with both existing and new config sources

### Adding New Functions

1. Add function to src/ProjSwitch.psm1
2. Include comment-based help with .SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE
3. Export in ProjSwitch.psd1 under `FunctionsToExport`
4. Add alias in `AliasesToExport` if needed
5. Update README.md command list
6. Test import: `Import-Module ./ProjSwitch.psd1 -Force`

### Modifying fzf Options

fzf configuration is in src/ProjSwitch.psm1:116-121. Options:
- `--prompt`: Search prompt text
- `--height`: Menu height (percentage or lines)
- `--layout`: reverse, default
- `--border`: Border style
- `--preview-window`: Preview pane config (currently hidden)

Users can override via `$env:FZF_DEFAULT_OPTS` environment variable.

## Version Management

Update version in ProjSwitch.psd1:13 using semantic versioning (MAJOR.MINOR.PATCH).
