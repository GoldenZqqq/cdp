# PowerShell Modularization Design

## Architecture

`cdp.psd1` keeps `src/cdp.psm1` as `RootModule`. The root module becomes a
bootstrap that initializes module-scoped caches, dot-sources an explicit ordered
list under `src/PowerShell`, registers aliases/completers, and exports the same
public commands.

Domain files do not dot-source one another. Function lookup remains module-scoped,
so cross-domain calls resolve after bootstrap loading without import cycles.

## File Boundaries

```text
Core.ps1             JSON persistence, fingerprints, shared action results
Config.ps1           config discovery/cache, path and fzf resolution
State.ps1            recent-project state persistence
Picker.ps1           picker rendering and display helpers
Hooks.ps1            hook trust, environment, and execution
Parser.ps1           token normalization and invocation model
Projects.ps1         project CRUD, repair, config selection
ProjectMetadata.ps1  pin, alias, and tag mutations
Scan.ps1             initialization and repository import
Status.ps1           Git inspection and batch status actions
Workspace.ps1        launcher and multi-project workspace lifecycle
Health.ps1           doctor/about diagnostics
Commands.ps1         public switching/list entry points and dispatch
Completion.ps1       argument-completer registration only
```

Every file stays at or below 600 physical lines. The bootstrap is the only file
that knows the complete load list.

## Load Order

1. Initialize `$script:CdpProjectConfigCache`, `$script:CdpFzfCommand`, and state
   fingerprints in `cdp.psm1`.
2. Load shared infrastructure and read models: Core, Config, State, Picker.
3. Load behavior domains: Hooks, Parser, ProjectMetadata, Projects, Scan, Status,
   Workspace, Health.
4. Load Commands and Completion.
5. Register aliases and call `Export-ModuleMember` with the unchanged surface.

The order documents dependencies, although PowerShell resolves function calls at
execution time after all files are loaded.

## Compatibility Contract

- `RootModule`, `FunctionsToExport`, and `AliasesToExport` remain unchanged.
- Dot-sourcing uses `$PSScriptRoot` and `Join-Path`; no PowerShell 7-only syntax.
- `$script:` variables stay in the module session state because files are loaded
  from the root module scope.
- Existing comment-based help moves with each function unchanged.
- Install and release tooling continues copying `src` recursively; tests assert
  the modular files are present in generated packages.

## Validation

- Parse every PowerShell source file and reject syntax errors.
- Assert the bootstrap contains no function definitions and every domain file is
  at most 600 lines.
- Assert domain files contain no dot-source statements.
- Compare imported function and alias names with the manifest exports.
- Run the full Pester suite under PowerShell 5.1/7 and PSScriptAnalyzer over the
  entire `src` tree.
- Run an import smoke threshold and generate/inspect the deterministic Scoop
  package.

## Rollback

The refactor is behavior-preserving. Roll back by restoring the previous
monolithic `src/cdp.psm1` and removing `src/PowerShell`; no user data migration or
configuration rollback is required.
