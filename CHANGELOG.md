# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Publish to PowerShell Gallery
- Support for additional project management tools
- Recent projects quick access
- Project tags and filtering
- Customizable project actions
- Cross-platform terminal title support

## [1.0.0] - 2025-10-15

### Added
- Initial release of ProjSwitch
- Core `Switch-Project` function with fzf integration
- `Get-ProjectList` function to view all projects
- Automatic detection of VS Code and Cursor Project Manager configurations
- Windows Terminal tab title synchronization
- PowerShell 5.1+ and PowerShell 7+ support
- Comprehensive installation script with profile integration
- `cdp` alias for quick access
- Interactive fzf menu with enhanced options
- Detailed error handling and user feedback
- Full documentation (README, CONTRIBUTING, LICENSE)

### Features
- Fuzzy search powered by fzf
- Smart config path detection (Cursor → VS Code fallback)
- UTF-8 encoding support for international project names
- Enabled projects filtering
- Color-coded console output
- Custom config path support via parameter

[Unreleased]: https://github.com/yourusername/ProjSwitch/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/ProjSwitch/releases/tag/v1.0.0
