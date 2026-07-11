#
# Module manifest for module 'cdp'
#
# Generated on: 2025-10-15
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'src\cdp.psm1'

# Version number of this module.
ModuleVersion = '2.0.3'

# Supported PSEditions
CompatiblePSEditions = @('Desktop', 'Core')

# ID used to uniquely identify this module
GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

# Author of this module
Author = 'GoldenZqqq'

# Company or vendor of this module
CompanyName = 'GoldenZqqq'

# Copyright statement for this module
Copyright = '(c) 2025 GoldenZqqq. All rights reserved.'

# Description of the functionality provided by this module
Description = 'cdp - A fast and intuitive project directory switcher for PowerShell. Fuzzy-find your way to any project instantly.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @('Invoke-Cdp', 'Switch-Project', 'Get-ProjectList', 'Add-Project', 'Set-ProjectPin', 'Clear-ProjectPin', 'Repair-ProjectConfig', 'Initialize-Cdp', 'Add-ProjectAlias', 'Remove-ProjectAlias', 'Add-ProjectTag', 'Remove-ProjectTag', 'Import-GitProjects', 'Remove-Project', 'Edit-ProjectConfig', 'Set-ProjectConfig', 'Test-ProjectHealth', 'Show-CdpAbout', 'Get-CdpRecentProjects', 'Show-CdpProjectStatus', 'Invoke-CdpWorkspace')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @('cdp', 'cdp-add', 'cdp-rm', 'cdp-ls', 'cdp-edit', 'cdp-config', 'cdp-doctor', 'cdp-scan', 'cdp-recent', 'cdp-pin', 'cdp-unpin', 'cdp-clean', 'cdp-init', 'cdp-alias', 'cdp-unalias', 'cdp-tag', 'cdp-untag', 'cdp-status')

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('project-manager', 'fzf', 'fuzzy-search', 'navigation', 'productivity',
                 'vscode', 'cursor', 'terminal', 'cli', 'windows-terminal', 'ai-cli')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/GoldenZqqq/cdp/blob/main/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/GoldenZqqq/cdp'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
ReleaseNotes = @'
v2.0.3 - CJK Column Alignment
- Fixed: Long project names (especially CJK/Chinese) no longer misalign the Branch/Status/Sync/Last Commit columns
- Added: Display-width-aware text limiting and padding (CJK chars = 2 columns)

v2.0.2 - Status Action Mode
- Changed: cdp status --fix now shows only the projects being removed, not the full table
- Changed: cdp status --push now shows only the repos being pushed, not the full table
- Fixed: --fix and --push accept a trailing config path argument

v2.0.1 - Status Dashboard UX
- Added: Progress indicator while scanning projects (Scanning 3/58...)
- Added: cdp status --fix to remove path-missing projects from config
- Added: cdp status --push to push all repos ahead of remote
- Added: Actionable tips after status summary (Tip: cdp status --fix / --push)

v2.0.0 - Project Workbench
- Added: cdp status multi-project Git dashboard with branch, dirty/clean, ahead/behind, and last commit
- Added: cdp status --dirty to filter repos needing attention
- Added: cdp status @tag to filter by project tag
- Added: cdp workspace for multi-project launching (Windows Terminal tabs / tmux)
- Added: cdp workspace --add and cdp workspace --list for workspace management
- Added: onEnter hooks for automatic environment activation on project switch
- Added: Intelligent tab completion for PowerShell, bash, and zsh
- Added: Native macOS support (zsh + bash, Homebrew install, Application Support config discovery)
- Added: macOS CI runner with zsh smoke test
- Fixed: PowerShell 5.1 ConvertFrom-Json array wrapping in Set-ProjectPin, Add-ProjectAlias, Repair-ProjectConfig
- Fixed: bash 3.2 compatibility (lowercase operator, realpath, negative array index)
- Fixed: zsh compatibility (BASH_REMATCH, BASH_SOURCE, read -p, status variable)
- Improved: README repositioned as project workbench with cdp status showcase and updated comparison table

v1.8.0 - AI CLI Workspace Launcher
- Added: PowerShell cdp can start a workspace command after switching, for example cdp api -Open codex
- Added: WSL/Linux cdp supports cdp api --open codex with the same launcher presets
- Added: Launcher presets for code, cursor, codex, claude, and gemini, with custom PATH commands supported
- Added: Pinned projects can be managed with cdp pin / cdp unpin and stay above normal projects
- Added: Safe config repair with cdp clean / cdp-clean / cdp doctor --fix
- Added: First-run setup with cdp init / cdp-init
- Added: Project aliases and tags with cdp alias / cdp tag, including tag queries such as cdp '@work'

v1.7.0 - Recent Projects
- Added: cdp recent / cdp-recent shows recently visited projects ordered by last use
- Added: Successful project switches are tracked in ~/.cdp/state.json without changing projects.json
- Added: CDP_STATE_PATH override for automation and isolated tests

v1.6.3 - PowerShell Preview File Path Hotfix
- Fixed: PowerShell picker preview now passes the preview script path to -File with Windows-safe double quotes

v1.6.2 - PowerShell Preview Hotfix
- Fixed: PowerShell picker preview no longer embeds fzf placeholders inside quoted file paths

v1.6.1 - PowerShell fzf Color Hotfix
- Fixed: PowerShell picker now passes the fzf --color theme as one complete native argument

v1.6.0 - Neon TUI Picker
- Added: The fzf picker now uses ANSI-colored rows, a neon color theme, rounded border, and pointer/marker styling
- Added: The fzf picker shows a right-side project preview with path and Git repository status
- Improved: cdp-ls / Get-ProjectList now displays a compact aligned project table
- Improved: PowerShell and WSL/bash picker styling stay consistent without adding new required dependencies

v1.5.0 - Brand Header and Update Reminder
- Added: cdp about / cdp version shows the cdp logo, current version, config path, project counts, and upgrade command
- Added: cdp doctor displays a compact brand header before diagnostics
- Added: fzf picker header shows cdp version, visible project count, and active config path
- Added: cdp doctor checks PowerShell Gallery for newer cdp releases
- Added: upgrade guidance with Update-Module when a newer version is available
- Improved: update check can be skipped for automation with -SkipUpdateCheck or CDP_SKIP_UPDATE_CHECK

v1.4.1 - PowerShell Startup Performance
- Improved: Cache parsed project configuration within a PowerShell session
- Improved: Cache fzf command resolution and support CDP_FZF_PATH for a fixed fzf executable path
- Improved: Reuse cached config data for cdp and cdp-ls while invalidating after project list writes

v1.4.0 - Fast Query Matching and Git Repository Import
- Added: cdp <query> and Switch-Project -Query for direct project switching when one match is found
- Added: Import-GitProjects / cdp-scan / cdp scan for bulk Git repository discovery and import
- Improved: First-time fzf setup guidance and dependency fallback messages
- Improved: README comparisons with zoxide, autojump, plain fzf cd scripts, and VS Code/Cursor Project Manager
- Improved: Added real-world multi-repo, AI CLI, and Windows + WSL workflow examples

v1.3.0 - Open Source Readiness and Doctor Command
- Added: cdp doctor / cdp-doctor diagnostics for dependencies, config, JSON schema, duplicate names, and missing project paths
- Added: Invoke-Cdp entry point so the short cdp command can support lightweight subcommands while keeping classic switching behavior
- Improved: Synchronized PowerShell and bash/zsh version numbers for the 1.3.0 release
- Improved: Added automated test and CI coverage for the public module surface

v1.2.6 - Critical IME Fix for Candidate Selection
- Fixed: IME candidate selection via number keys now works correctly
- Fixed: IME candidate selection via mouse click now works correctly
- Fixed: Added InputEncoding configuration (previously only OutputEncoding was set)
- Added: no-mouse parameter to prevent IME mouse event conflicts
- Note: This resolves the issue where selecting IME candidates caused fzf to exit

v1.2.5 - Complete IME Fix and UI Improvement
- Fixed: IME candidate selection (number keys or mouse click) no longer triggers false cancellation
- Fixed: Removed exit code check that caused IME input to be treated as cancellation
- Improved: Increased fzf menu height from 40 percent to 60 percent for better visibility
- Improved: Silent cancellation behavior (no more Operation cancelled message when exiting)

v1.2.4 - Critical Bug Fix
- Fixed: Chinese and IME input now works correctly in fzf search
- Fixed: Removed key bindings that conflicted with input method editors

v1.2.2 - Configuration Persistence Feature
- Added: Automatic config choice persistence to ~/.cdp/config
- Added: New Set-ProjectConfig command (alias: cdp-config) to change active config
- Added: Smart config priority: env var > saved choice > interactive selection
- Improved: Only prompt for config selection on first use or when explicitly requested
- Improved: Better UX with current config display in cdp-config command

v1.2.1 - Multi-Config Selection Feature
- Added: Multi-config file selection when multiple configs are detected
- Added: Interactive menu to choose between Cursor, VS Code, and custom configs
- Added: Tip to use $env:CDP_CONFIG to skip selection
- Improved: Better user experience when managing multiple config sources
- Improved: Consistent behavior across PowerShell and WSL/bash versions

v1.2.0 - WSL/Linux Support Release
- Added: Full WSL/Linux support with bash/zsh version
- Added: -WSL parameter to Switch-Project for launching WSL from PowerShell
- Added: Automatic Windows to WSL path conversion (C:\path → /mnt/c/path)
- Added: One-liner install script for WSL/Linux environments
- Added: Shared configuration support between Windows and WSL
- Added: Support for reading Project Manager configs from WSL
- Improved: Documentation with comprehensive WSL usage examples

v1.1.1 - Bug Fix Release
- Fixed: cdp-add command now correctly saves project paths
- Fixed: Resolved issue where Add-Project would save empty rootPath values
- Fixed: Improved path resolution to ensure valid absolute paths are always stored

v1.1.0 - Project Renamed to "cdp"
- BREAKING: Project renamed from ProjSwitch to cdp for simplicity
- Added Add-Project command (alias: cdp-add) to quickly add current directory to project list
- Added Remove-Project command (alias: cdp-rm) to remove projects from configuration
- Added Edit-ProjectConfig command (alias: cdp-edit) to quickly edit config file
- Improved Get-ProjectList (alias: cdp-ls) with better formatting and numbering
- Auto-create default config file at ~/.cdp/projects.json on first use
- Simplified configuration management workflow
- Fixed: Aliases no longer conflict with system commands (ls, rm, add)
'@

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}
