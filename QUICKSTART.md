# Quick Start Guide

Get ProjSwitch up and running in 5 minutes!

## Prerequisites Check

```powershell
# Check PowerShell version (need 5.1+)
$PSVersionTable.PSVersion

# Check if fzf is installed
fzf --version

# If fzf is not installed:
winget install fzf
# Then restart your terminal
```

## Installation

### Option 1: Quick Install (Recommended)

```powershell
# Clone the repository
git clone https://github.com/yourusername/ProjSwitch.git
cd ProjSwitch

# Run the installer with automatic profile setup
.\Install.ps1 -AddToProfile

# Restart PowerShell or reload profile
. $PROFILE
```

### Option 2: Manual Install

```powershell
# Clone the repository
git clone https://github.com/yourusername/ProjSwitch.git
cd ProjSwitch

# Run the installer
.\Install.ps1

# Manually add to your PowerShell profile
notepad $PROFILE

# Add these lines:
Import-Module ProjSwitch
Set-Alias -Name cdp -Value Switch-Project

# Save and reload
. $PROFILE
```

### Option 3: PowerShell Gallery (When Published)

```powershell
# Install from PowerShell Gallery
Install-Module -Name ProjSwitch -Scope CurrentUser

# Add to profile
Import-Module ProjSwitch
Set-Alias -Name cdp -Value Switch-Project
```

## First Use

1. **Make sure you have Project Manager set up**
   - Install [Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager) in VS Code or Cursor
   - Save a few projects using the extension

2. **Try switching projects**

```powershell
# Use the alias (quickest)
cdp

# Or use the full command
Switch-Project
```

3. **Navigate with fzf**
   - Type to filter projects by name (fuzzy matching)
   - Use arrow keys ↑↓ to navigate
   - Press Enter to select
   - Press Esc to cancel

4. **List all projects**

```powershell
Get-ProjectList
```

## Usage Examples

### Basic Usage

```powershell
# Quick switch
PS C:\> cdp
# Opens fuzzy finder with all projects
# Select project → Switches directory
# Terminal tab title updates automatically
```

### With Custom Config

```powershell
# Use a custom projects.json location
Switch-Project -ConfigPath "C:\my-custom-projects.json"
```

### Integration Examples

```powershell
# Add to your profile for custom workflows

# Switch and open in VS Code
function cdpv { cdp; code . }

# Switch and show git status
function cdpg { cdp; git status }

# Switch and list files
function cdpl { cdp; ls }

# Switch and open in explorer
function cdpe { cdp; explorer . }
```

## Verification

Test that everything is working:

```powershell
# 1. Check module is loaded
Get-Module ProjSwitch

# 2. Check commands are available
Get-Command Switch-Project
Get-Command Get-ProjectList

# 3. Check alias exists
Get-Alias cdp

# 4. Try it out!
cdp
```

## Troubleshooting

### "fzf: command not found"

```powershell
# Install fzf
winget install fzf

# Restart your terminal
exit
# Open new terminal and try again
```

### "Module not found"

```powershell
# Check if module is in the right location
Get-Module -ListAvailable ProjSwitch

# If not found, reinstall
cd path\to\ProjSwitch
.\Install.ps1 -AddToProfile
```

### "No projects found"

Make sure you have:
1. Project Manager installed in VS Code or Cursor
2. At least one project saved
3. Projects are enabled (check projects.json)

### "Command not recognized after installation"

```powershell
# Reload your profile
. $PROFILE

# Or restart PowerShell
exit
# Open new terminal
```

## Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Check out [CONTRIBUTING.md](CONTRIBUTING.md) if you want to contribute
- See [docs/PUBLISHING.md](docs/PUBLISHING.md) to learn about distribution options
- Report issues on [GitHub](https://github.com/yourusername/ProjSwitch/issues)

## Common Workflows

### Daily Development

```powershell
# Morning: Jump to current project
cdp  # Select your work project

# Later: Switch to another project
cdp  # Select different project

# Quick check what projects you have
Get-ProjectList
```

### Team Setup

```powershell
# Share your installation script with team
# Everyone runs:
git clone https://github.com/yourusername/ProjSwitch.git
cd ProjSwitch
.\Install.ps1 -AddToProfile

# Now everyone can use:
cdp
```

## Tips

- Type just a few letters to filter - fzf's fuzzy matching is smart!
- Projects are sorted by when they were added to Project Manager
- The terminal tab title updates automatically to show current project
- Use `Get-ProjectList` to see all available projects before switching
- You can customize fzf options via `$env:FZF_DEFAULT_OPTS`

---

**That's it! You're ready to start using ProjSwitch. Happy coding! 🚀**
