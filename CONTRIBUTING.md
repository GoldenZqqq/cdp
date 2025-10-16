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
* Update the README.md with details of changes if applicable
* Test your changes with both PowerShell 5.1 and PowerShell 7+
* Ensure your code works on Windows (primary platform)

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

The main module code is in `cdp/src/cdp.psm1`.

4. **Test your changes**

```powershell
# Import the module locally
Import-Module ./cdp/cdp.psd1 -Force

# Test the functions
Switch-Project
Get-ProjectList
```

5. **Commit your changes**

```powershell
git add .
git commit -m "Add: Your descriptive commit message"
```

Use conventional commit messages:
- `Add:` for new features
- `Fix:` for bug fixes
- `Update:` for updates to existing features
- `Docs:` for documentation changes
- `Refactor:` for code refactoring

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
├── src/
│   └── cdp.psm1      # Main module file
├── tests/                    # Unit tests (future)
├── docs/                     # Additional documentation
├── cdp.psd1          # Module manifest
└── Install.ps1              # Installation script
```

## Testing

Currently, testing is manual. Future contributions for automated testing (Pester tests) are welcome!

Manual testing checklist:
- [ ] Test with PowerShell 5.1
- [ ] Test with PowerShell 7+
- [ ] Test with VS Code configuration
- [ ] Test with Cursor configuration
- [ ] Test with empty configuration
- [ ] Test with no fzf installed
- [ ] Test tab title update in Windows Terminal
- [ ] Test with custom config path

## Documentation

* Update README.md if you change functionality
* Update function comment-based help
* Add examples for new features
* Update version numbers in cdp.psd1

## Questions?

Feel free to open an issue with your question or reach out to the maintainers.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
