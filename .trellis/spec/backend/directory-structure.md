# Backend Directory Structure

## Runtime Ownership

```text
cdp.psd1                         PowerShell public manifest and version source
src/cdp.psm1                     stable PowerShell bootstrap/export surface
src/PowerShell/*.ps1             bounded PowerShell domains
src/Shell/*.sh                   canonical bash/zsh domains
src/cdp.sh                       generated single-file shell distribution
Install.ps1                      PowerShell source installer entry
install-wsl.sh                   verified shell installer entry
scripts/                         build, quality, benchmark, package, release tools
tests/                           Pester and shell regression suites
scoop/cdp.json                   Scoop release metadata
```

## PowerShell Domains

`src/cdp.psm1` initializes module-scoped cache state, dot-sources an explicit
ordered domain list, defines aliases, and exports public functions. It must not
regain business function bodies.

Use the existing concern boundaries:

- `Core.ps1`: shared formatting, paths, action results, and JSON primitives.
- `Paths.ps1`: runtime profile detection, raw/resolved project path selection,
  and backward-compatible new-entry path maps.
- `Config.ps1` / `State.ps1`: config discovery/cache and recent state.
- `Parser.ps1` / `Commands.ps1`: raw CLI normalization then dispatch.
- `Projects.ps1` / `ProjectMetadata.ps1` / `Scan.ps1`: project mutations.
- `Status.ps1` / `StatusOutput.ps1` / `StatusBatch.ps1`: Git collection,
  schema/table projection, cache, workers, and actions.
- `WorkspaceLifecycle.ps1` / `Workspace.ps1`: stable workspace schema, CRUD,
  validation/migration, launch planning, and WT execution; `Hooks.ps1` owns trusted onEnter.
- `ExecSelection.ps1` / `Exec.ps1` / `ExecOutput.ps1`: multi-repository
  selection/path planning, bounded native argv workers, and ordered human/JSON output.
- `Picker.ps1` / `Completion.ps1` / `Health.ps1`: interaction and diagnostics.

New functions belong in the narrowest existing domain. Add a new domain only
when no current concern owns it, keep the file under 600 lines, add it to the
bootstrap order, installer/package coverage, and modularization tests.

## Shell Domains and Generated Artifact

Edit `src/Shell/*.sh`, never hand-edit `src/cdp.sh`. The build script concatenates
fragments in a fixed order and validates the generated file:

```bash
bash scripts/Build-ShellScript.sh
bash scripts/Build-ShellScript.sh --check
```

Fragments use bash/zsh-compatible functions and must retain Bash 3.2 support.
Do not let a domain source peer fragments; the generated runtime provides the
shared scope.

Keep `Paths.sh` as the single project-path resolver, `WorkspaceLifecycle.sh` as
the workspace schema/CRUD/plan owner, and `StatusBatch.sh` as the status
cache/settings owner. Callers must not reintroduce local Windows-to-WSL
conversion branches or duplicate stable-reference resolution in `Workspace.sh`.
`ExecSelection.sh`, `Exec.sh`, and `ExecOutput.sh` own the equivalent shell
selection, batch/watchdog execution, and rendering contract.

## Test and Tool Placement

- PowerShell suites: `tests/*.Tests.ps1`, one focused behavior family per file.
- Shell suites: `tests/*.Tests.sh`, shared bash/zsh entry where parity matters.
- Website Node/Playwright: `tests/web` and focused `tests/*.mjs` fixtures.
- Reusable validation belongs in `scripts/`; workflow YAML only orchestrates.

## Naming and Anti-Patterns

- PowerShell public functions use approved verbs; internal helpers use `*-Cdp*`.
- Shell public compatibility commands retain `cdp-*`; helpers use `cdp_*`.
- Avoid generic `Utils` files, peer dot-sourcing, duplicated workflow assertions,
  or direct edits to generated/release artifacts.

Reference tests: `tests/cdp.Modularization.Tests.ps1` and
`tests/cdp.Shell.Modularization.Tests.sh`.
