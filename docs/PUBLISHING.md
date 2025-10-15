# Publishing Guide

This guide explains how to publish ProjSwitch to various distribution platforms.

## Table of Contents

- [PowerShell Gallery (Recommended)](#powershell-gallery-recommended)
- [GitHub Releases](#github-releases)
- [Chocolatey](#chocolatey-optional)
- [Winget](#winget-optional)
- [Scoop](#scoop-optional)

---

## PowerShell Gallery (Recommended)

PowerShell Gallery is the **primary and recommended** distribution method for PowerShell modules.

### Prerequisites

1. **PowerShellGet module** (pre-installed on PowerShell 5.1+)
2. **NuGet API Key** from [PowerShell Gallery](https://www.powershellgallery.com/)
   - Create account at https://www.powershellgallery.com/
   - Go to Account → API Keys → Create
   - Copy your API key

### Steps to Publish

1. **Validate the module**

```powershell
# Test the module manifest
Test-ModuleManifest -Path .\ProjSwitch.psd1

# Import and test locally
Import-Module .\ProjSwitch.psd1 -Force
Get-Command -Module ProjSwitch
```

2. **Set your API key** (one-time setup)

```powershell
# Store your API key securely
$apiKey = Read-Host -Prompt "Enter your PowerShell Gallery API key" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey)
$key = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Or simply (less secure):
$key = "your-api-key-here"
```

3. **Publish to PowerShell Gallery**

```powershell
# First time publishing
Publish-Module -Path . -NuGetApiKey $key -Verbose

# Subsequent updates (increment version in .psd1 first!)
Publish-Module -Path . -NuGetApiKey $key -Verbose
```

4. **Verify publication**

Visit: https://www.powershellgallery.com/packages/ProjSwitch

Users can now install with:
```powershell
Install-Module -Name ProjSwitch -Scope CurrentUser
```

### Version Updates

Before publishing updates:

1. Update version in `ProjSwitch.psd1`:
   ```powershell
   ModuleVersion = '1.1.0'  # Increment version
   ```

2. Update `CHANGELOG.md` with changes

3. Test thoroughly

4. Publish with same command:
   ```powershell
   Publish-Module -Path . -NuGetApiKey $key -Verbose
   ```

---

## GitHub Releases

GitHub Releases provide version tracking and distribution via GitHub.

### Steps

1. **Create a Git tag**

```powershell
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

2. **Create release on GitHub**

- Go to your repository on GitHub
- Click "Releases" → "Create a new release"
- Select the tag you just created
- Title: `v1.0.0 - Initial Release`
- Description: Copy from CHANGELOG.md
- Attach files (optional): Create a zip of the module

3. **Users can install via**

```powershell
# Download and install manually
Invoke-WebRequest -Uri "https://github.com/yourusername/ProjSwitch/archive/refs/tags/v1.0.0.zip" -OutFile "ProjSwitch.zip"
Expand-Archive ProjSwitch.zip -DestinationPath "$env:USERPROFILE\Documents\PowerShell\Modules\"
```

---

## Chocolatey (Optional)

Chocolatey is a Windows package manager. Less common for PowerShell modules, but useful for broader distribution.

### Prerequisites

1. Create account at https://community.chocolatey.org/
2. Get API key from your account settings
3. Install Chocolatey packaging tools

### Steps

1. **Create nuspec file**

Create `projswitch.nuspec`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd">
  <metadata>
    <id>projswitch</id>
    <version>1.0.0</version>
    <title>ProjSwitch</title>
    <authors>Your Name</authors>
    <owners>Your Name</owners>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <licenseUrl>https://github.com/yourusername/ProjSwitch/blob/main/LICENSE</licenseUrl>
    <projectUrl>https://github.com/yourusername/ProjSwitch</projectUrl>
    <description>Fast project directory switcher for PowerShell</description>
    <tags>powershell project-manager fzf navigation productivity</tags>
    <dependencies>
      <dependency id="fzf" version="0.30.0" />
    </dependencies>
  </metadata>
  <files>
    <file src="tools\**" target="tools" />
  </files>
</package>
```

2. **Create installation script**

Create `tools/chocolateyinstall.ps1`:

```powershell
$ErrorActionPreference = 'Stop'

$moduleName = 'ProjSwitch'
$moduleVersion = '1.0.0'

# Download and install module
$packageArgs = @{
  packageName   = $moduleName
  url           = "https://github.com/yourusername/ProjSwitch/archive/refs/tags/v$moduleVersion.zip"
  unzipLocation = "$env:ProgramFiles\PowerShell\Modules\$moduleName"
  checksum      = 'YOUR_CHECKSUM_HERE'
  checksumType  = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
```

3. **Pack and push**

```powershell
choco pack
choco push projswitch.1.0.0.nupkg --source https://push.chocolatey.org/ --api-key YOUR_API_KEY
```

Users install with:
```powershell
choco install projswitch
```

---

## Winget (Optional)

Windows Package Manager (winget) - requires submission to microsoft/winget-pkgs repository.

### Steps

1. **Fork winget-pkgs repository**

https://github.com/microsoft/winget-pkgs

2. **Create manifest files**

In `manifests/p/YourName/ProjSwitch/1.0.0/`:

- `YourName.ProjSwitch.yaml` (main manifest)
- `YourName.ProjSwitch.installer.yaml` (installer details)
- `YourName.ProjSwitch.locale.en-US.yaml` (localization)

3. **Submit PR to winget-pkgs**

Follow their contribution guidelines

Users install with:
```powershell
winget install ProjSwitch
```

**Note**: This process has a longer approval time and is more complex.

---

## Scoop (Optional)

Scoop is a lightweight package manager for Windows.

### Steps

1. **Fork a Scoop bucket** (e.g., extras bucket)

https://github.com/ScoopInstaller/Extras

2. **Create manifest file**

`bucket/projswitch.json`:

```json
{
    "version": "1.0.0",
    "description": "Fast project directory switcher for PowerShell",
    "homepage": "https://github.com/yourusername/ProjSwitch",
    "license": "MIT",
    "url": "https://github.com/yourusername/ProjSwitch/archive/refs/tags/v1.0.0.zip",
    "hash": "SHA256_HASH_HERE",
    "extract_dir": "ProjSwitch-1.0.0",
    "psmodule": {
        "name": "ProjSwitch"
    },
    "depends": "fzf"
}
```

3. **Submit PR**

Users install with:
```powershell
scoop install projswitch
```

---

## Recommendations

**For ProjSwitch, I recommend:**

1. **Primary**: **PowerShell Gallery** - Native, easy, instant
2. **Secondary**: **GitHub Releases** - Version tracking, backup distribution
3. **Optional**: Chocolatey, Winget, Scoop - Only if demand grows

### Quick Start: PowerShell Gallery Only

```powershell
# 1. Test
Test-ModuleManifest .\ProjSwitch.psd1

# 2. Get API key from PowerShellGallery.com

# 3. Publish
Publish-Module -Path . -NuGetApiKey "YOUR_KEY" -Verbose

# Done! Users can now:
Install-Module ProjSwitch
```

This gives you the widest reach with minimal effort.
