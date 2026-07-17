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
