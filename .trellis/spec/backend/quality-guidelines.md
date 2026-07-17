# Backend Quality Guidelines

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
- Config, state, repositories, workspaces, fake executables, and logs live under one validated `mktemp -d` root and are removed by its trap.
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
