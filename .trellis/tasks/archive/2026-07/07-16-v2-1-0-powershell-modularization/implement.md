# PowerShell Modularization Implementation

1. Add structural Pester coverage for bootstrap-only loading, file-size limits,
   no cross-file dot-sourcing, public exports, and import performance.
2. Mechanically extract every top-level function from `src/cdp.psm1` into the
   documented domain file without changing function bodies.
3. Replace `src/cdp.psm1` with the deterministic loader, unchanged aliases,
   completer registration, and export list.
4. Update CI to analyze all PowerShell files and extend installer/package tests to
   prove the new domain files are shipped.
5. Run parser checks and Pester first; compare command/alias inventories and fix
   only extraction defects.
6. Synchronize release notes, progress, changelog, spec, and deterministic Scoop
   hash; run all project quality gates.

## Validation Commands

```powershell
Import-Module ./cdp.psd1 -Force
Invoke-Pester -Path ./tests -CI
Invoke-ScriptAnalyzer -Path ./src -Recurse -Severity Error
Get-Command -Module cdp
```

```bash
bash ./scripts/New-ScoopPackage.sh 2.1.0 /tmp/cdp-2.1.0.tar.gz
tar -tzf /tmp/cdp-2.1.0.tar.gz
git diff --check
```

## Rollback Points

- After extraction but before docs/metadata: restore the monolithic module if any
  public inventory or regression differs.
- Do not combine internal algorithm cleanup with extraction; defer it to the
  owning follow-up task.

## Completion Evidence

- [x] `src/cdp.psm1` is a 71-line deterministic bootstrap and contains no
  function definitions.
- [x] Fourteen PowerShell domain/completion files are explicitly loaded; the
  largest file is 557 lines and no domain file dot-sources a peer.
- [x] AST comparison reports all `119/119` extracted function bodies identical
  to `HEAD` before the split.
- [x] PowerShell 7.5.2 arm64 Pester passed `88/88`; PSScriptAnalyzer reported no
  Error-severity findings across `src`.
- [x] Manifest command/alias inventory, import performance, package recursion,
  release metadata, shell regressions, YAML/JSON, Trellis validation, and
  `git diff --check` passed locally.
- [x] Deterministic Scoop archive contains all 14 PowerShell files and has
  SHA-256 `83a89dd5f4a79d1f476b33e018c3118cd5352f4379f317a4481b4e75643ceee8`.

PowerShell 5.1 is not installed in the local Linux environment. The identical
Pester suite and recursive ScriptAnalyzer gate are configured in Windows CI and
will be verified by the v2.1.0 release task.
