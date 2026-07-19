# Status JSON Implementation

1. Add parser fields and validation for PowerShell `-Json` / `-NoColor` and
   shell `--json` / `--no-color`, including read-only conflict rules.
2. Add runtime-neutral status-code, attention-reason, redacted error, summary,
   and exit-code projections without changing the existing collector contract.
3. Serialize schema version 1 in PowerShell with `ConvertTo-Json` and in shell
   with `jq -n`; suppress progress and route fatal diagnostics to stderr.
4. Add plain no-color table rendering while preserving the current styled table
   as the default.
5. Add PowerShell, bash, zsh, and Bash 3.2 contract/parser/output/exit tests.
6. Regenerate `src/cdp.sh`, synchronize English and Chinese documentation, move
   development metadata to v2.2.0, and run the full task quality matrix.

## Validation Commands

```text
pwsh -File scripts/Invoke-PowerShellQualityGate.ps1
bash scripts/Build-ShellScript.sh --check
bash tests/cdp.Status.Json.Tests.sh
zsh tests/cdp.Status.Json.Tests.sh
bash tests/cdp.Status.Tests.sh
bash tests/cdp.Status.Performance.Tests.sh
shellcheck --severity=error --exclude=SC2296 src/cdp.sh src/Shell/*.sh
node scripts/Test-Documentation.mjs
python .trellis/scripts/task.py validate <task>
git diff --check
```

The fixed Bash 3.2 container runs the new JSON fixture before completion.

## Completion Record

- [x] Added parser/dispatch support for JSON and no-color read-only modes.
- [x] Added schema version 1 projections with stable status/reason/error fields,
  raw/resolved paths, scan timing, summary counts, and exit codes 0-3.
- [x] Added one shared contract fixture consumed by PowerShell, bash, and zsh.
- [x] Preserved classic table, PowerShell PassThru, status fix/push, cache,
  timeout, concurrency, and safe-mutation behavior.
- [x] Synchronized v2.2.0 manifest/runtime/installer/Scoop/changelog/progress and
  English/Chinese documentation.
- [x] PowerShell 7.5.2 quality gate passed Pester `104/104`, coverage
  `2311/3344` (`69.11%`), PSScriptAnalyzer, and release metadata.
- [x] bash/zsh/Bash 3.2 status JSON and complete shell regression matrices passed.
- [x] Deterministic Scoop package SHA-256 is
  `d29537ccb61d7e6937dbeb63503674e5d35aec48f94466ed15290e70c853d839`;
  generated shell SHA-256 is
  `36220aaf421571fb17fb208901237e1ae532584ea50c3c83a6fa5dfe97da4935`.
- [x] Documentation/asset fixtures `11/11`, YAML/JSON, Trellis validation, and
  `git diff --check` passed.

## Rollback Points

- Parser/projection changes can be reverted before documentation because the
  default table remains untouched.
- If cross-runtime schema equivalence cannot be maintained, do not publish a
  runtime-specific JSON shape; return to the design and reduce schema scope.
- Any regression in fix/push or `-PassThru` blocks completion.
