# Contributing to cdp

First off, thank you for considering contributing to cdp! It's people like you that make cdp such a great tool.

## Code of Conduct

This project and everyone participating in it is governed by our commitment to providing a welcoming and inspiring community for all. Please be respectful and constructive in your interactions.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you are creating a bug report, please include as many details as possible:

* Use a clear and descriptive title
* Describe the exact steps which reproduce the problem
* Provide specific examples to demonstrate the steps
* Describe the behavior you observed and what behavior you expected
* Include screenshots if relevant
* Include your environment details (OS, PowerShell version, fzf version)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* Use a clear and descriptive title
* Provide a detailed description of the suggested enhancement
* Provide specific examples to demonstrate the enhancement
* Explain why this enhancement would be useful

### Pull Requests

* Fill in the pull request template
* Follow the PowerShell coding style
* Include comments in your code where necessary
* Update the canonical English `README.md` and the Simplified Chinese `README_ZH.md` when applicable
* Run the repository-owned quality gate for every affected runtime/layer
* Preserve PowerShell 5.1/7, bash/zsh, and Bash 3.2 compatibility where applicable

## Development Setup

1. **Fork and clone the repository**

```powershell
git clone https://github.com/GoldenZqqq/cdp.git
cd cdp
```

2. **Create a branch**

```powershell
git checkout -b feature/your-feature-name
```

3. **Make your changes**

PowerShell behavior lives in `src/PowerShell/*.ps1` and is loaded by the stable
`src/cdp.psm1` bootstrap. Shell behavior lives in canonical `src/Shell/*.sh`
fragments; regenerate `src/cdp.sh` with `scripts/Build-ShellScript.sh`.

4. **Test your changes**

```powershell
# Import the module locally
Import-Module ./cdp.psd1 -Force

# Test the functions
cdp doctor .\examples\projects.json
Get-ProjectList

# Run pinned Pester, coverage, PSScriptAnalyzer, and release metadata
.\scripts\Invoke-PowerShellQualityGate.ps1
```

```bash
# Shell source/generated artifact and cross-shell behavior
bash ./scripts/Build-ShellScript.sh --check
bash ./tests/cdp.Shell.Modularization.Tests.sh
bash ./tests/cdp.Shell.V2.Tests.sh

# Package, documentation, media, and browser quality
bash ./scripts/Test-ScoopPackage.sh
node ./scripts/Test-Documentation.mjs
pnpm --dir tests/web install --frozen-lockfile
pnpm --dir tests/web test
```

5. **Commit your changes**

```powershell
git add <changed-files>
git commit -m "feat: 增加简短功能说明"
```

Use Conventional Commits with an optional scope and a concise Chinese summary
(50 characters or fewer, no trailing period):

- `feat: 增加项目能力`
- `fix(status): 修复仓库状态判断`
- `test(web): 增加官网回归`
- `docs: 同步双语文档`
- `refactor: 拆分内部模块`
- `chore: 更新工程配置`

6. **Push to your fork**

```powershell
git push origin feature/your-feature-name
```

7. **Create a Pull Request**

Go to the original repository and create a pull request from your fork.

## Coding Conventions

* Use clear, descriptive variable names
* Follow PowerShell approved verb naming conventions for functions
* Add comment-based help to all functions
* Use 4 spaces for indentation
* Keep functions focused and single-purpose
* Add error handling with try-catch blocks where appropriate
* Use `-ForegroundColor` for user-facing messages appropriately:
  * Red: Errors
  * Yellow: Warnings
  * Green: Success messages
  * Cyan: Informational headers
  * Gray: Secondary information

## Module Structure

```
cdp/
├── cdp.psd1                  # PowerShell manifest and canonical version
├── src/
│   ├── cdp.psm1              # Stable PowerShell bootstrap/export surface
│   ├── PowerShell/*.ps1      # Bounded PowerShell domains
│   ├── Shell/*.sh            # Canonical bash/zsh domains
│   └── cdp.sh                # Generated single-file shell distribution
├── scripts/                  # Build, quality, package, and release gates
├── tests/                    # Pester, shell, Node, and Playwright tests
├── docs/                     # Static website and governed media
├── scoop/cdp.json            # Scoop release metadata
├── Install.ps1               # PowerShell installer
└── install-wsl.sh            # Verified shell installer
```

## Testing

CI pins Pester `5.7.1`, PSScriptAnalyzer `1.24.0`, pnpm `11.9.0`, and
Playwright `1.61.1`. Use repository scripts instead of copying CI assertions.

```powershell
.\scripts\Invoke-PowerShellQualityGate.ps1
```

```bash
bash ./scripts/Build-ShellScript.sh --check
bash ./scripts/Test-ScoopPackage.sh
pnpm --dir tests/web test
```

Manual testing checklist:
- [ ] Test with PowerShell 5.1
- [ ] Test with PowerShell 7+
- [ ] Test with VS Code configuration
- [ ] Test with Cursor configuration
- [ ] Test with empty configuration
- [ ] Test with no fzf installed
- [ ] Test tab title update in Windows Terminal
- [ ] Test with custom config path
- [ ] Test `cdp doctor`
- [ ] Test bash and zsh behavior if shell scripts changed
- [ ] Test Bash 3.2 compatibility for shared shell changes
- [ ] Run documentation/media/browser gates for website or docs changes
- [ ] Verify deterministic package hash if `cdp.psd1` or packaged files changed

## Documentation

* Update both `README.md` and `README_ZH.md` if you change functionality
* Update function comment-based help
* Add examples for new features
* Update `cdp.psd1` version and ReleaseNotes for module release changes
* Keep `README_EN.md` as a redirect only

## Questions?

Feel free to open an issue with your question or reach out to the maintainers.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
