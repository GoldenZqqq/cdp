# Backend Quality Guidelines

## Scenario: Trust Project Command Hooks Without Storing Commands

### 1. Scope / Trigger

Apply whenever `onEnter`, switch options, hook management, or hook trust
storage changes. Structured `env` data is not command trust; command execution
always requires one-switch authorization or a current persistent fingerprint.

### 2. Signatures

```text
cdp <project> [--allow-hook|--no-hook]
cdp hook list [--config <projects.json>]
cdp hook trust <project> [--config <projects.json>]
cdp hook revoke <project|--all> [--config <projects.json>]
CDP_HOOK_TRUST_PATH=<test/automation override>
```

### 3. Contracts

- `--no-hook` wins over environment and command behavior.
- `--allow-hook` authorizes one switch and is never persisted.
- Persistent entries contain config, project, and command SHA-256 values plus
  `trustedAt`; command text and environment values are forbidden.
- Config path, any config content, project name/root path, or command changes invalidate trust.
- The trust file uses atomic JSON persistence and mode `0600` / current-user ACL.
- List, warnings, and failures identify projects or states but never commands.

### 4. Validation & Error Matrix

- `--allow-hook` plus `--no-hook` -> parser error; no switch.
- Untrusted/stale command -> skip and show redacted trust/one-switch hint.
- Invalid env key -> skip key without rendering key or value.
- Invalid trust JSON or permission hardening failure -> no command execution.
- Ambiguous/missing project or missing platform command -> mutation fails.
- Hook runtime error -> redacted warning; successful directory switch remains.

### 5. Good / Base / Bad Cases

- Good: inspect config, `hook trust api`, command runs until its fingerprint changes.
- Base: structured env applies, command remains skipped by default.
- Bad: store command text, log it on failure, or trust only by project name.

### 6. Tests Required

- PowerShell 5.1/7 and bash/zsh cover default deny, one-switch allow, persistent
  trust, stale command, revoke, list redaction, and no-hook.
- Assert invalid env names and hook failures never reveal names/commands.
- Assert trust JSON contains only fingerprints/timestamp and file mode is `0600`
  on Unix; redirect storage with `CDP_HOOK_TRUST_PATH` in tests.
- Preserve project/alias named `hook` unless the next token is a management action.

### 7. Wrong vs Correct

Wrong:

```text
{ "project": "api", "command": "export TOKEN=..." }
```

Correct:

```text
{ "configFingerprint": "...", "projectFingerprint": "...", "hookFingerprint": "...", "trustedAt": "..." }
```

## Scenario: Persist cdp JSON Atomically

### 1. Scope / Trigger

Apply whenever code creates or mutates `projects.json`, `state.json`,
`workspaces.json`, or future cdp-owned JSON state. Direct `Out-File`, shell
redirection to the live target, or a temp file outside the target directory is
forbidden.

### 2. Signatures

PowerShell:

```powershell
Read-CdpJsonDocument -LiteralPath <path>
Write-CdpJsonFile -LiteralPath <path> -Value <object> `
    -ExpectedFingerprint <sha256|missing> [-BackupCount 3]
Get-CdpValidJsonBackups -LiteralPath <path>
Restore-CdpJsonBackup -LiteralPath <path> -BackupPath <path>
```

Shell:

```text
cdp_json_fingerprint <path>
cdp_commit_json_file <target> <candidate> <sha256|missing>
cdp_write_json_text <target> <json> <sha256|missing>
cdp_valid_json_backups <path>
cdp_restore_json_backup <target> <backup>
```

### 3. Contracts

- Read and parse before mutation; retain the SHA-256 fingerprint.
- Lock with a sibling `<file>.cdp.lock` and never wait silently.
- Recheck the fingerprint while holding the lock.
- Validate JSON, flush a sibling temporary file, then replace by same-directory
  rename/replace.
- Preserve the previous document as `<file>.cdp-backup.*` and retain the three
  newest backups.
- PowerShell writes invalidate the project config cache.
- Invalid active state is read-only until explicitly restored; never reset it
  silently to an empty document.

### 4. Validation & Error Matrix

- Existing foreign lock -> fail; do not delete the foreign lock.
- Fingerprint mismatch -> concurrency error; original remains unchanged.
- Invalid candidate JSON -> fail before replacement.
- Invalid active state -> report valid backup count; do not overwrite.
- Permission, flush, backup, or replace error -> nonzero/exception; remove only
  owned temporary and lock artifacts.
- Missing target plus expected `missing` -> initialize atomically.

### 5. Good / Base / Bad Cases

- Good: read fingerprint, transform object, persist with that fingerprint.
- Base: initialize a missing cdp-owned JSON file with expected `missing`.
- Bad: `ConvertTo-Json ... | Out-File projects.json` or `jq ... > projects.json`.

### 6. Tests Required

- PowerShell 5.1/7 and bash/zsh/Bash 3.2 cover successful replacement.
- Assert stale fingerprints, invalid JSON, and locks preserve exact original
  bytes.
- Assert only three backups remain and an explicit valid backup restores.
- Assert project cache reads the replacement immediately.
- Run existing add, metadata, repair, status-fix, workspace, state, and scan
  regressions because every mutation route shares this boundary.

### 7. Wrong vs Correct

Wrong:

```text
jq '<transform>' projects.json > projects.json
```

Correct:

```text
fingerprint -> sibling candidate -> cdp_commit_json_file target candidate fingerprint
```

## Scenario: Parse CLI Tokens Once Before Dispatch

### 1. Scope / Trigger

Apply this contract whenever `Invoke-Cdp`, `cdp()`, a subcommand, option, positional argument, or custom config path is added or changed. It prevents argument order from changing behavior and prevents option tokens from leaking into project names or paths.

### 2. Signatures

PowerShell owns a pure parser boundary:

```powershell
ConvertFrom-CdpInvokeArguments `
    -Command <string> `
    -ConfigPath <string> `
    -Query <string> `
    -Open <string> `
    -RemainingArgs <string[]>
```

The parser returns one invocation object. `Invoke-Cdp` dispatches by `Kind` and must not reinterpret raw tokens. Bash/zsh subcommands must consume all options before performing dependency checks or actions.

### 3. Contracts

Common invocation fields:

- `Kind`: canonical command name or `switch`.
- `ConfigPath`: zero or one resolved config path.
- `Query`: project query for `switch` only.
- `Open`: launcher value after `--open`, `-open`, or `-o` is consumed.

Status fields:

- `DirtyOnly`, `Fix`, `Push`: booleans.
- `TagFilter`: zero or one `@tag` value.

Workspace fields:

- `WorkspaceAction`: `usage`, `list`, `add`, or `open`.
- `WorkspaceName`: required for `add` and `open`.
- `Projects`: project names only; option names and option values are forbidden.

Management fields:

- `Name`, `Value`, `RootPath`, `MaxDepth`, and `Count` are normalized before dispatch.
- A trailing or explicit `--config` value must reach the called public function.

### 4. Validation & Error Matrix

- Missing value after `--open` or `--config` -> parser error; no action.
- Duplicate `--open`, config path, or tag -> parser error; no action.
- Unknown `-`-prefixed option -> parser error; no action.
- `status --fix --push` -> mutually exclusive action error.
- `status --dirty` with `--fix` or `--push` -> filter/action conflict error.
- `workspace --list --open ...` -> invalid combination error.
- `workspace --add` without a name and at least one project -> required argument error.

### 5. Good / Base / Bad Cases

Good:

```text
cdp status --dirty @work C:\configs\projects.json
cdp workspace --add fullstack api web --open codex --config C:\configs\projects.json
```

Base compatibility:

```text
cdp
cdp api
cdp api C:\configs\projects.json --open codex
```

Bad:

```text
cdp status --fix --push
cdp workspace --add fullstack api --open
```

### 6. Tests Required

- Pure parser tests assert every returned field and argument-order independence.
- Route tests mock the target command and assert the exact named parameters.
- PowerShell 5.1 and 7 run the same Pester scenarios.
- Bash tests assert conflict errors and inspect persisted workspace JSON to prove option tokens were consumed.
- Existing classic switch/query/open tests remain green.

### 7. Wrong vs Correct

Wrong: dispatch code reinterprets positional variables after parsing.

```powershell
if ($Command -eq 'status') {
    $dirty = $ConfigPath -eq '--dirty'
    $config = $RemainingArgs[0]
}
```

Correct: parsing owns token meaning; dispatch only forwards the normalized contract.

```powershell
$invocation = ConvertFrom-CdpInvokeArguments @parseParameters
if ($invocation.Kind -eq 'status') {
    Invoke-CdpStatusInvocation -Invocation $invocation
}
```

## Scenario: Inspect and Mutate Project Status with Stable Path Identity

### 1. Scope / Trigger

Apply this contract whenever status collection, workspace launch, WSL path conversion, Git synchronization, or `status --fix/--push` behavior changes. It prevents a converted filesystem path from being written back as configuration identity and prevents an action from touching projects outside its scan preview.

### 2. Signatures

PowerShell status collection returns a normalized object:

```powershell
Get-CdpGitProjectInfo -Project <project>
# Name, RootPath, PathExists, IsGitRepo, Branch,
# DirtyCount, UntrackedCount, AheadCount, BehindCount,
# LastCommitRelative, StatusLabel, NeedsAttention
```

The shell boundary is:

```text
cdp-status [--dirty] [@tag] [--fix|--push] [--config <projects.json>]
convert_windows_to_wsl <raw-rootPath> -> <resolved-local-path>
```

### 3. Contracts

- Preserve each JSON `rootPath` as the raw configuration identity.
- Resolve raw Windows paths before filesystem, Git, tmux, or workspace access in bash/zsh.
- Detect repositories with `git -C <resolved-path> rev-parse --is-inside-work-tree`; a successful literal `true` includes normal repositories and linked worktrees.
- Report tracked and untracked changes independently. If both exist, the label contains both counts.
- `NeedsAttention` is true for tracked changes, untracked files, or a positive behind count. A dirty-only header reports the number actually rendered.
- Derive ahead/behind only from a successful upstream query. Detached and no-upstream repositories remain at zero.
- `--fix` removes only enabled missing entries selected by the current scan. Disabled entries remain even when they share the same raw path.
- `--push` targets only scanned Git repositories with a positive upstream-derived ahead count and reports the native push exit code accurately.

### 4. Validation & Error Matrix

- Missing resolved directory -> `PathExists=false`, `StatusLabel="path missing"`; never run Git.
- Existing non-worktree directory -> `IsGitRepo=false`, `StatusLabel="not a git repo"`; never run later Git probes.
- `.git` file linked worktree -> valid Git repository.
- Upstream query failure -> ahead and behind stay zero; never become a push target.
- Behind-only repository -> needs attention and cannot produce an all-clean summary.
- `--fix` with no previewed missing entries -> no config write.
- Native `git push` nonzero exit -> render failure, never `done`.

### 5. Good / Base / Bad Cases

Good:

```text
raw rootPath: C:\Work\api
resolved WSL path: /mnt/c/Work/api
Git/status/tmux use: /mnt/c/Work/api
fix identity uses: C:\Work\api
```

Base compatibility:

```text
/home/me/api remains /home/me/api
clean repository with no upstream reports clean and 0/0 sync
```

Bad:

```text
Test-Path <root>/.git
remove every config entry whose resolved path is missing
print "done" without checking git push exit status
```

### 6. Tests Required

- PowerShell 5.1 and 7: normal repo, linked worktree, dirty plus untracked, behind-only, diverged, detached/no-upstream, missing, and non-Git fixtures.
- PowerShell and shell: `--fix` preserves a disabled entry that shares the missing enabled entry's raw path.
- Shell: a stubbed Windows path proves status and workspace consume the resolved path.
- Shell: dirty-only output asserts the rendered project count, not the scanned total.
- Git fixtures use local temporary repositories and bare remotes only; tests must not fetch or push over the network.
- CI runs shell status tests on both Ubuntu and macOS, plus bash/zsh syntax validation.

### 7. Wrong vs Correct

Wrong: infer repository type from a directory layout and let the action rescan all config entries.

```text
if <path>/.git is a directory, treat as Git
status --fix = delete every currently missing path
```

Correct: ask Git, keep raw and resolved paths separate, and mutate only the scan result.

```text
raw rootPath -> resolve for filesystem/Git -> normalized status
normalized missing enabled set -> remove matching enabled config entries only
```

## Scenario: Preview and Approve Mutating Commands

### 1. Scope / Trigger

Apply whenever a command writes cdp state, changes the active config, pushes
Git, or starts a multi-project workspace process. Preview must be decided
before the first persistent or external side effect.

### 2. Signatures

```text
PowerShell: <mutation> [-WhatIf] [-Confirm] [-PassThru]
shell:      <mutation> [--dry-run|--yes]

PowerShell action result:
Action, Target, Status, Changed, Error

shell action result:
action=<name> target=<target> status=<state> changed=<true|false> [error=<reason>]
```

### 3. Contracts

- Low-risk add, pin/unpin, alias/tag, workspace-definition, and hook-trust
  changes preview but execute by default.
- High-risk repair, remove, scan/import, init, status fix/push, active-config
  selection, and workspace launch require native High-impact confirmation in
  PowerShell or `--yes` in shell.
- PowerShell returns action results only with `-PassThru`; existing domain and
  aggregate fields may be carried as additional properties for compatibility.
- Shell never reads confirmation from stdin. `cdp-config` consumes an explicit
  numeric selection; automatic config discovery is read-only and deterministic.
- Dry-run validates targets and plans actions but never writes JSON/config
  choice, pushes Git, creates tmux/terminal processes, or persists hook trust.
- Batch actions continue after item failure and retain a failed result/nonzero
  final status after processing later targets.

### 4. Validation & Error Matrix

- `--dry-run --yes` -> parser error; no side effect.
- Safety option on read-only list/status/doctor/switch -> parser error.
- High-risk shell action without `--yes` -> show plan, return nonzero.
- `-WhatIf` / `--dry-run` with valid targets -> preview result, success, bytes unchanged.
- Per-target native failure -> failed result; continue remaining targets.
- Config fingerprint race -> failed result under `-PassThru`, otherwise exception;
  active bytes remain the concurrent writer's version.

### 5. Good / Base / Bad Cases

- Good: `cdp status --push --dry-run`, inspect remote/upstream, then rerun with `--yes`.
- Base: `cdp pin api` keeps compatibility; `cdp pin api --dry-run` previews.
- Bad: prompt with `read`, `Read-Host`, or `ShouldContinue` after a batch stream
  starts; write config before checking approval; stop after the first failed push.

### 6. Tests Required

- PowerShell 5.1/7: every mutation exposes native common parameters and WhatIf
  preserves exact bytes; workspace WhatIf calls no process API.
- bash/zsh/Bash 3.2: low-risk dry-run, high-risk refusal/dry-run/yes, config
  selection without stdin confirmation, and no-write assertions.
- Status/workspace batch fixtures put a failure before a success and assert both
  results plus the successful later native side effect.
- CI runs `cdp.SafeMutations.Tests.ps1` and `cdp.SafeMutations.Tests.sh`.

### 7. Wrong vs Correct

Wrong:

```text
initialize/write -> prompt -> stop on first failure
```

Correct:

```text
parse -> validate -> plan -> approve/preview -> execute each -> aggregate status
```

## Scenario: Build Cross-Version PowerShell Regression Fixtures

### 1. Scope / Trigger

Apply this contract when adding Pester coverage for status actions, workspace launch, onEnter hooks, argument completers, or any behavior with process, environment, filesystem, Git, or user-config side effects. It keeps the PowerShell 5.1 and 7 suites identical and prevents regression tests from mutating the developer machine.

### 2. Signatures

The project test boundary is:

```powershell
Invoke-Pester -Path .\tests -PassThru

$config = New-PesterConfiguration
$config.Run.Path = '.\tests'
$config.Run.PassThru = $true
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = '.\src\cdp.psm1'
Invoke-Pester -Configuration $config
```

Behavior fixtures call public functions directly or use the module boundary:

```powershell
InModuleScope cdp -Parameters @{ Value = $value } {
    # Call one internal boundary and assert observable results.
}
```

### 3. Contracts

- PowerShell 5.1 and 7 execute the same `*.Tests.ps1` files and assertions.
- New suites remain below 600 lines; add a focused file instead of extending an oversized legacy test file.
- Configs, state files, repositories, remotes, and missing paths live under `$TestDrive`.
- Git synchronization tests use local bare remotes only. They prove success through refs and prove failure through an unavailable local path.
- Windows Terminal, editors, and AI CLIs are mocked or use an explicit production dry-run mode.
- onEnter tests execute controlled environment assignments or expected throws only; they do not start external commands.
- Environment variables, location, and module config cache are restored after each scenario that changes them.
- Argument completer tests use `TabExpansion2` so the registered command boundary, not a copied scriptblock, is exercised.
- Capture `Write-Host` output with information-stream redirection (`6>&1`) when success/failure text is part of the contract.

### 4. Validation & Error Matrix

- Real user config/state path accessed -> invalid test; redirect to `$TestDrive`.
- Network remote, `wt.exe`, or AI CLI started -> invalid test; replace with local fixture, mock, or dry run.
- PS7-only syntax or runtime feature -> compatibility failure; rewrite for Windows PowerShell 5.1.
- Environment or current location not restored -> isolation failure, even if assertions pass.
- Push ref changes but output says failure -> product regression; assert both the ref and success text.
- Hook throws -> caller must not throw; warning output is asserted.
- Coverage percent does not exceed the recorded task baseline -> acceptance failure.
- Parallel default `Invoke-Pester -CI` runs in one checkout -> report collision risk at `testResults.xml`; run sequentially or configure unique result paths.

### 5. Good / Base / Bad Cases

Good:

```text
$TestDrive repo -> local bare remote -> status --push
mocked Start-Process -> exact wt.exe ArgumentList assertions
temporary CDP_CONFIG -> TabExpansion2 -> enabled project completion
```

Base compatibility:

```text
the same test file passes under powershell.exe 5.1 and pwsh 7
full suite runs without requiring Windows Terminal or an installed launcher
```

Bad:

```text
push to a GitHub test branch
read the developer's Project Manager JSON
call wt.exe and assert only that no exception occurred
copy the completer scriptblock into the test
```

### 6. Tests Required

- Status: structured filters plus local push success and failure, asserting both state and rendered outcome.
- Workspace: persisted add/list JSON, paths containing spaces, missing config entries, and exact mocked launch arguments.
- onEnter: env values, controlled PowerShell/string hooks, and exception isolation.
- Completion: subcommand, enabled project, disabled-project exclusion, and launcher prefixes through `TabExpansion2`.
- Run targeted scenarios first, then full Pester on PS5.1 and PS7, PSScriptAnalyzer, code coverage, shell regressions, syntax, and `git diff --check`.
- Report executed/analyzed command counts with the percentage so coverage change is auditable.

### 7. Wrong vs Correct

Wrong: a smoke test reports success because an external program happened to be installed.

```powershell
{ Invoke-CdpWorkspace -Name team } | Should -Not -Throw
```

Correct: isolate the side effect and assert the exact contract.

```powershell
Mock Start-Process {}
Invoke-CdpWorkspace -Name team -ConfigPath $testConfig
Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
    $FilePath -eq 'wt.exe' -and $ArgumentList -contains $expectedProjectPath
}
```

## Scenario: Run One Cross-Shell V2 Regression Contract

### 1. Scope / Trigger

Apply this contract whenever `src/cdp.sh`, shell dependency handling, switching, hooks, launchers, workspace/scan iteration, Windows path conversion, bash/zsh completion, or the Ubuntu/macOS CI jobs change. It prevents bash-only success from hiding zsh regressions and prevents CI-only inline fixtures from drifting away from local tests.

### 2. Signatures

The repository-owned test entry is invoked directly by both supported shells:

```text
bash tests/cdp.Shell.V2.Tests.sh
zsh tests/cdp.Shell.V2.Tests.sh
```

The zsh completion boundary separates the real compsys wrapper from its deterministic helper:

```text
_cdp_zsh_completions
  -> _cdp_zsh_complete_words <CURRENT> <words...>
```

Controlled test environment keys are:

```text
CDP_TEST_REPO_ROOT   optional repository root override
CDP_TEST_JQ_EXE      optional jq executable bridge for a WSL host tool
CDP_TEST_FAKE_FZF    optional in-process fzf stub
CDP_STATE_PATH       temporary recent-project state
CDP_OPEN_DRY_RUN     disables GUI/AI launcher execution
CDP_TEST_TMUX_LOG    records fake tmux arguments
```

### 3. Contracts

- The same test file must run under bash and zsh without a caller pre-sourcing helpers.
- Normalize the temporary base with a physical `pwd` before `mktemp -d`; runner-provided `TMPDIR` may end in `/`, and logical double-slash paths must not become expected filesystem identities.
- Config, state, repositories, workspaces, fake executables, and logs live under one validated `mktemp -d` root and are removed by its trap.
- Every test that reaches workspace launch shadows `tmux` with a fixture executable, even when workspace behavior is not the test's primary subject. Runner images may preinstall real `tmux`, which must never create or attach a session during tests.
- Dependency-negative checks override `PATH` only in child scopes and explicitly remove test functions; later tests retain the original executable search path.
- Never bind the exact shell variable name `path` in zsh-compatible code. In zsh it is a special array tied to `PATH`; use `input_path`, `project_path`, `raw_project_path`, or `config_entry_path`.
- Loops whose bodies start `jq`, `tmux`, Windows executable bridges, or other child processes read their item stream from a dedicated fd such as fd 3. Child stdin must not be the iterator stream.
- Launcher metadata with optional empty fields uses a non-whitespace delimiter such as ASCII file separator (`\034`); tab is forbidden because shell `read` collapses adjacent IFS whitespace.
- NUL-delimited directory iteration uses `read -d $'\0'` so bash and zsh share the same parser.
- `_cdp_zsh_completions` reads real `words`/`CURRENT`; `_cdp_zsh_complete_words` owns the testable behavior. Both use local `noksharrays` semantics because compsys positions are 1-based even though the rest of the shared script enables `KSH_ARRAYS`.
- Ubuntu and macOS CI install dependencies and call the repository entry. They do not copy lifecycle fixtures into workflow YAML.

### 4. Validation & Error Matrix

- Missing `jq`, `git`, or `fzf` -> deterministic nonzero result containing the named dependency; no system uninstall or global `PATH` mutation.
- Missing config -> `Configuration file not found`; invalid top-level JSON -> schema/array error.
- `onEnter` environment/bash hook -> controlled environment values are visible after switching; failing legacy hook -> warning and successful caller isolation.
- Empty launcher argument -> dry-run output reports the intended label and never passes that label as the command argument.
- Workspace or scan with two items plus child commands -> both items are observed; one item proves stdin leakage.
- Trailing-slash `TMPDIR` -> generated project paths and physical `$PWD` use the same normalized root.
- Preinstalled runner `tmux` -> the test still calls only the fixture executable and leaves no server/session behind.
- zsh path operation -> `command -v basename` and other executable lookup still work afterward.
- Completion -> subcommand, enabled project, disabled exclusion, `workspace`, and launcher candidates are asserted in both adapters.
- Windows path input -> deterministic `/mnt/<drive>/...` output without requiring a real mounted Windows drive in CI.

### 5. Good / Base / Bad Cases

Good:

```text
Git Bash bash entry + WSL zsh entry -> identical scenario groups pass
workspace/scan loop <&3 -> jq/tmux cannot consume the next project
zsh helper with local noksharrays -> CURRENT=2 resolves the second word
```

Base compatibility:

```text
native Ubuntu jq/fzf/git and native macOS zsh run with no test bridge variables
paths containing spaces remain one config value and one tmux argument
```

Bad:

```text
local path="$1"
while read item; do jq ...; done <<< "$items"
printf "codex\t\tCodex\n" | read command argument label
copy a 50-line smoke fixture into each CI job
```

### 6. Tests Required

- Dependency/config: missing `jq`, `git`, `fzf`, missing config, and invalid JSON.
- Lifecycle: direct switch, recent, pin/unpin, clean, alias/tag, launcher dry run, and status smoke.
- Hooks: object `env` plus bash hook success and legacy failure isolation.
- Workspace: add/list, path with spaces, fake tmux launch, missing-project skip, and every-project iteration.
- Isolation: run with a trailing-slash `TMPDIR` and with a real `tmux` earlier on the host PATH; assertions still use the normalized root and fixture tmux.
- Scan: shallow init plus nested multi-repository scan, asserting the persisted JSON length.
- Completion: bash adapter and zsh helper assert subcommand, `workspace`, enabled project, disabled exclusion, and launcher candidates.
- Path: Windows conversion and a post-operation executable lookup assertion under zsh.
- Final gate: both PowerShell versions, PSScriptAnalyzer, CLI/status shell suites, bash/zsh shared entry, bash/zsh syntax, and `git diff --check`.

### 7. Wrong vs Correct

Wrong: share the loop's stdin with arbitrary child processes and shadow zsh's executable path array.

```bash
local path="$1"
while IFS= read -r project; do
    jq -r ... "$config"
done <<< "$projects"
```

Correct: use semantic path names and a dedicated iterator descriptor.

```bash
local project_path="$1"
while IFS= read -r project <&3; do
    jq -r ... "$config"
done 3<<< "$projects"
```

## Scenario: Install and Validate One Canonical Release Version

### 1. Scope / Trigger

Apply this contract whenever `Install.ps1`, PowerShell module search paths, `cdp.psd1` version/release notes, runtime version headers, tests, Scoop, changelog, progress, or Windows CI release checks change. It prevents an installer from writing to a directory the active edition cannot discover and prevents a release from publishing mutually inconsistent version metadata.

### 2. Signatures

The shared installation boundaries are:

```powershell
Resolve-CdpModuleInstallPath -Scope <CurrentUser|AllUsers> -Edition <Core|Desktop> `
    -ModuleSearchPath <PSModulePath> -DocumentsPath <path> -ProgramFilesPath <path>

Select-CdpInstalledModule -AvailableModules <object[]> `
    -ModulePath <exact-target> -ExpectedVersion <version>
```

The source installer automation boundary is:

```text
Install.ps1 [-Scope CurrentUser|AllUsers] [-Force] [-SkipFzf]
```

The repository release check is:

```text
pwsh -File scripts/Test-ReleaseMetadata.ps1 [-RepositoryRoot <path>]
powershell.exe -File scripts/Test-ReleaseMetadata.ps1 [-RepositoryRoot <path>]
```

### 3. Contracts

- `cdp.psd1` `ModuleVersion` is the only canonical version. Every other version string is a checked mirror.
- Required discoverable roots are: Core CurrentUser `<Documents>/PowerShell/Modules`, Desktop CurrentUser `<Documents>/WindowsPowerShell/Modules`, Core AllUsers `<ProgramFiles>/PowerShell/Modules`, and Desktop AllUsers `<ProgramFiles>/WindowsPowerShell/Modules`.
- The normalized required root must be present in the current/injected `PSModulePath`; do not guess from directory existence or silently install to an undiscoverable path.
- Installation success requires an available module whose normalized `ModuleBase` equals the exact target and whose version equals the copied manifest. A same-name module elsewhere is irrelevant.
- `-Force` only skips overwrite confirmation. `-SkipFzf` only skips dependency setup when the caller already declares `fzf`; default interactive behavior remains.
- Scoop owns the `fzf` dependency and calls the root installer. It must not copy module-path selection logic.
- The metadata validator checks release-notes first version, PowerShell/Bash headers, Bash runtime version, two Pester expectations, Scoop current/template metadata, changelog first heading, and progress release target.
- `PROGRESS.md` distinguishes latest externally verified public release from the current local target. It never claims publication before channel verification.
- Installer/metadata validators do not accept, read, print, or persist Gallery API keys.
- In Windows PowerShell 5.1 negative process tests, native stderr redirected with `2>&1` becomes an ErrorRecord. Temporarily use `ErrorActionPreference=Continue` only around the expected failing child and restore it in `finally` before asserting exit code/output.

### 4. Validation & Error Matrix

- Edition/scope root absent from `PSModulePath` -> resolver throws; copy does not start.
- AllUsers without administrator privileges -> installer exits nonzero before mutation.
- Existing module without `-Force` and user declines -> clean cancellation; no overwrite.
- Only an old module at another `ModuleBase` -> exact verification fails.
- Target module version differs from copied manifest -> exact verification fails with found/expected versions.
- Any checked metadata version, Scoop URL, extract directory, dependency, or installer command drifts -> validator lists the mismatched key and exits nonzero.
- Current repository is consistent -> validator reports the canonical version and exits zero under PowerShell 5.1 and 7.
- Missing metadata file or invalid manifest/JSON -> validator exits nonzero before release work.

### 5. Good / Base / Bad Cases

Good:

```text
PS7 CurrentUser -> Documents/PowerShell/Modules/cdp present in PSModulePath
PS5 AllUsers -> ProgramFiles/WindowsPowerShell/Modules/cdp present in PSModulePath
Scoop -> Install.ps1 -Scope CurrentUser -Force -SkipFzf
manifest 2.0.4 -> every checked mirror 2.0.4
```

Base compatibility:

```text
interactive Install.ps1 still prompts before overwrite and manages fzf by default
PowerShell 5.1 and 7 run the same Pester file and metadata validator
```

Bad:

```text
if Documents/PowerShell exists, install there regardless of PSEdition
Get-Module -ListAvailable cdp returns anything -> claim installation success
Scoop maintains its own copied module-path algorithm
update manifest version but forget Scoop/CHANGELOG/tests/PROGRESS
```

### 6. Tests Required

- Path matrix: CurrentUser/AllUsers crossed with Core/Desktop, using isolated Documents, ProgramFiles, and `PSModulePath` values.
- Resolver error: required edition root missing from injected `PSModulePath`.
- Exact selection: target path/version succeeds; same version elsewhere fails; wrong version at target fails.
- Metadata positive: current repository passes in PowerShell 5.1 and 7.
- Metadata negative: copy required files to `$TestDrive`, mutate Scoop version, run the validator in a separate same-edition process, assert nonzero and `scoop.version` output.
- CI runs full Pester and the validator explicitly in both Windows jobs.
- Final gate also includes PSScriptAnalyzer on installer/scripts/module, Scoop JSON and workflow YAML parsing, shell regressions/syntax, secret-reference search, Trellis validation, and `git diff --check`.

### 7. Wrong vs Correct

Wrong: infer the destination from an unrelated directory and accept an arbitrary old module.

```powershell
$modulePath = "$HOME/Documents/PowerShell/Modules/cdp"
if (Get-Module -ListAvailable cdp) { 'installed' }
```

Correct: resolve one discoverable edition root and verify only the target identity.

```powershell
$modulePath = Resolve-CdpModuleInstallPath -Scope CurrentUser -ModuleName cdp
$manifest = Test-ModuleManifest (Join-Path $modulePath 'cdp.psd1')
$candidates = @(Get-Module -ListAvailable -Name cdp -Refresh)
Select-CdpInstalledModule -AvailableModules $candidates `
    -ModulePath $modulePath -ExpectedVersion $manifest.Version
```

## Scenario: Load PowerShell Domains Through a Stable Bootstrap

### 1. Scope / Trigger

Apply whenever `src/cdp.psm1` or a PowerShell domain file is added, moved, or
split. The module manifest and public command surface must remain stable while
internal files stay independently reviewable.

### 2. Signatures

```text
cdp.psd1 RootModule = src/cdp.psm1
src/cdp.psm1 -> ordered dot-source of src/PowerShell/*.ps1
src/PowerShell/Completion.ps1 -> Register-ArgumentCompleter only
```

### 3. Contracts

- `src/cdp.psm1` owns module-scoped cache initialization, the explicit load list,
  aliases, and `Export-ModuleMember`; it defines no functions.
- Domain files contain function bodies only for one bounded concern and do not
  dot-source peer files. Shared `$script:` state remains in the module scope.
- Every domain file is at most 600 physical lines and is copied by installer,
  Gallery, and Scoop recursive `src` packaging paths.
- `FunctionsToExport` and `AliasesToExport` in the manifest are unchanged by an
  internal split.

### 4. Validation & Error Matrix

- Missing listed domain file -> module import fails with the exact path.
- Bootstrap function definition or unlisted domain file -> structural test fails.
- Domain dot-source or file over 600 lines -> structural test fails.
- Any source parse error -> structural test and CI fail before behavior tests.
- Export inventory drift -> Pester fails with actual and expected command names.
- Package path omits a domain file -> installer/package structural test fails.

### 5. Good / Base / Bad Cases

- Good: add a function to one domain file and keep the bootstrap list/export
  unchanged unless the public surface changes.
- Base: add a new domain file, list it once in bootstrap order, and add a focused
  regression test.
- Bad: reintroduce helper functions into the bootstrap or have domains dot-source
  one another to force load order.

### 6. Tests Required

- Parse bootstrap and every `src` PowerShell file with the AST parser.
- Assert bootstrap has zero function definitions, all domain files are listed,
  all domain files are <=600 lines, and no domain dot-sources peers.
- Import the manifest and compare exported functions/aliases with its declared
  inventory; measure an import smoke threshold.
- Run the same full Pester suite under PowerShell 5.1 and 7, plus
  `Invoke-ScriptAnalyzer -Path ./src -Recurse -Severity Error`.
- Inspect recursive source-copy behavior in `Install.ps1`, both Gallery scripts,
  and `scripts/New-ScoopPackage.sh`.

### 7. Wrong vs Correct

Wrong:

```powershell
# cdp.psm1 grows another domain function and silently imports one peer.
function Get-CdpStatusHelper { ... }
. "$PSScriptRoot/Status.ps1"
```

Correct:

```powershell
$domainFiles = @('Core.ps1', 'Config.ps1', 'Status.ps1', 'Commands.ps1')
foreach ($domainFile in $domainFiles) {
    . (Join-Path $domainRoot $domainFile)
}
```

## Scenario: Generate the Single-File Shell Distribution from Domains

### 1. Scope / Trigger

Apply whenever bash/zsh behavior, a file under `src/Shell`, `src/cdp.sh`, or the
shell installer digest changes. Developers edit domain fragments; users continue
to receive one verified sourceable file.

### 2. Signatures

```text
scripts/Build-ShellScript.sh          # regenerate src/cdp.sh
scripts/Build-ShellScript.sh --check  # exact-byte drift check
src/Shell/*.sh -> src/cdp.sh
```

### 3. Contracts

- `src/Shell/*.sh` is canonical source; `src/cdp.sh` is a committed generated
  distribution artifact and must not be edited independently.
- The build script owns one explicit ordered fragment list and is compatible with
  Bash 3.2. Runtime is first; Completion is last.
- Each fragment is at most 600 physical lines, declares its ShellCheck dialect,
  and never sources a peer fragment.
- Generated output starts with `#!/usr/bin/env bash`, retains version markers,
  and contains the same function inventory as all fragments combined.
- `install-wsl.sh` downloads or copies only generated `src/cdp.sh` and verifies
  its exact SHA-256 for remote installs.

### 4. Validation & Error Matrix

- Missing fragment -> build exits nonzero with the exact path.
- Fragment/artifact byte drift -> `--check` exits nonzero and requests rebuild.
- Oversized fragment, peer source, syntax error, or function inventory drift ->
  modularization test fails.
- Generated file lacks first-line shebang -> modularization test fails.
- Installer hash differs from generated bytes -> installer metadata test fails.
- Mixed bash/zsh ShellCheck reports known zsh expansions as `SC2296`; exclude only
  that rule while retaining Error-severity checks for every other rule.

### 5. Good / Base / Bad Cases

- Good: edit one domain, regenerate, run cross-shell tests, then update hashes.
- Base: reorder fragments only when top-level initialization/export order remains
  valid and the complete regression matrix passes.
- Bad: make `src/cdp.sh` a runtime multi-file loader or download fragments during
  installation, which breaks offline and single-file use.

### 6. Tests Required

- Build `--check`, fragment count/size, no peer source, first-line shebang, and
  exact function inventory assertions.
- bash and zsh syntax for fragments/artifact plus ShellCheck Error severity with
  only `SC2296` excluded.
- Existing CLI, status, safe-mutation, persistence, installer, completion, and
  v2 regression suites under bash/zsh; run the applicable matrix under Bash 3.2.
- Isolated offline installer copies exact bytes and the installed file can be
  sourced with public functions available.
- Recompute and verify shell installer and deterministic Scoop package hashes.

### 7. Wrong vs Correct

Wrong:

```text
edit src/cdp.sh directly -> fragments silently stale
source src/Shell/Status.sh from installed cdp.sh -> remote install breaks
```

Correct:

```bash
edit src/Shell/Status.sh
bash scripts/Build-ShellScript.sh
bash scripts/Build-ShellScript.sh --check
```
