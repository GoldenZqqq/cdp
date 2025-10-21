#
# Module manifest for module 'cdp'
#
# Generated on: 2025-10-15
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'src\cdp.psm1'

# Version number of this module.
ModuleVersion = '1.2.6'

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
FunctionsToExport = @('Switch-Project', 'Get-ProjectList', 'Add-Project', 'Remove-Project', 'Edit-ProjectConfig', 'Set-ProjectConfig')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @('cdp', 'cdp-add', 'cdp-rm', 'cdp-ls', 'cdp-edit', 'cdp-config')

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
                 'vscode', 'cursor', 'terminal', 'cli', 'windows-terminal')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/GoldenZqqq/cdp/blob/main/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/GoldenZqqq/cdp'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = @'
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
