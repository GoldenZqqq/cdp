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
- `Json`, `NoColor`: mutually exclusive read-only output modes.
- `TagFilter`: zero or one `@tag` value.
- `Refresh`: bypasses the optional status cache.
- `ThrottleLimit`: bounded worker count from 1 through 16; zero means the configured default.

Workspace fields:

- `WorkspaceAction`: `usage`, `list`, `show`, `add`, `edit`, `remove`,
  `validate`, or `open`.
- `WorkspaceName`: required for show/add/edit/remove/open and optional for validate.
- `Projects`: add/edit project names only; option names and values are forbidden.
- `WorkspaceLayout`: `tabs`, `split-horizontal`, or `split-vertical`.
- `ClearOpen` and `Fix`: explicit edit/migration controls.

Management fields:

- `Name`, `Value`, `RootPath`, `MaxDepth`, and `Count` are normalized before dispatch.
- A trailing or explicit `--config` value must reach the called public function.

### 4. Validation & Error Matrix

- Missing value after `--open` or `--config` -> parser error; no action.
- Duplicate `--open`, config path, or tag -> parser error; no action.
- Unknown `-`-prefixed option -> parser error; no action.
- `status --fix --push` -> mutually exclusive action error.
- `status --dirty` with `--fix` or `--push` -> filter/action conflict error.
- `status --jobs` without a value or outside 1-16 -> parser error; no scan.
- `status --refresh` is valid with read-only status and with actions; `--fix` and `--push` always refresh.
- `status --json --no-color`, or either output mode with `--fix` / `--push` -> parser error; no scan or mutation.
- `workspace --list --open ...` -> invalid combination error.
- `workspace --add` without a name and at least one project -> required argument error.
- `workspace edit` without projects/open/layout change -> required update error.
- `workspace --open` plus `--clear-open` -> conflict before config access.
- workspace safety options on read-only list/show/validate -> parser error.

### 5. Good / Base / Bad Cases

Good:

```text
cdp status --dirty --jobs 8 --refresh @work C:\configs\projects.json
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

## Scenario: Resolve Cross-Platform Project Path Profiles

### 1. Scope / Trigger

Apply whenever project config schema, switching, picker/list output, status,
workspace, doctor/repair, add/scan/init, recent paths, or future multi-repository
execution changes. It prevents raw Project Manager identity from being confused
with the local filesystem path and prevents a missing explicit mapping from
falling through to the wrong checkout.

### 2. Signatures

Project config:

```json
{"rootPath":"C:/Work/api","paths":{"windows":"C:/Work/api","wsl":"/home/me/api","linux":"/srv/api","macos":"/Users/me/api"}}
```

PowerShell:

```powershell
Get-CdpCurrentPathProfile [-Profile <windows|wsl|linux|macos>]
Resolve-CdpProjectPath -Project <object> [-Profile <profile>]
# RawPath, ResolvedPath, Profile, Source, IsExplicit, ErrorCode, ErrorMessage
```

Shell:

```text
cdp_current_path_profile [profile]
cdp_resolve_project_json <compact-project-json> [profile]
CDP_PATH_PROFILE=windows|wsl|linux|macos
```

### 3. Contracts

- `rootPath` is required raw identity and remains readable by Project Manager
  and older cdp versions.
- Known `paths` values are optional non-empty strings; unknown fields and future
  profile keys survive all writes.
- Selection order is explicit current mapping, WSL conversion of an unprofiled
  Windows `rootPath`, then unchanged `rootPath` fallback.
- An explicit current mapping is authoritative even when its directory is
  missing; do not use another profile or `rootPath`.
- `CDP_PATH_PROFILE` is case-insensitive and overrides detection. PowerShell
  `-WSL` requests `wsl` explicitly.
- Filesystem, Git, launcher, WT, and tmux use resolved paths. Recent identity,
  hook fingerprints, duplicate identity, and mutation matching use raw paths.
- New add/scan/init entries write both `rootPath` and `paths.<current>`.
- Repair/status fix preserve unavailable explicit mappings; legacy fallback
  missing paths retain the existing disable/remove behavior.

### 4. Validation & Error Matrix

- Invalid override -> command failure; JSON status stderr only, exit 3.
- `paths` is not an object -> `path_profile_invalid`; no filesystem probe.
- Any known profile value is non-string/empty -> `path_profile_invalid`; repair
  refuses to write.
- Explicit selected path missing -> `path_missing`, correct resolved path shown,
  no fallback and no destructive fix.
- Missing current key -> compatible `rootPath` fallback; WSL converts a Windows
  drive path.
- Missing legacy fallback path -> existing repair/status-fix behavior applies.

### 5. Good / Base / Bad Cases

Good:

```text
rootPath=C:/Work/api, paths.linux=/srv/api, profile=linux
raw identity C:/Work/api -> filesystem/Git /srv/api
```

Base compatibility:

```text
rootPath=D:/Code/api, no paths, profile=wsl -> /mnt/d/Code/api
rootPath=/home/me/api, no paths, profile=linux -> /home/me/api
```

Bad:

```text
paths.linux=/missing -> silently enter existing rootPath C:/Work/api
status --fix on Linux -> delete a project whose explicit Windows path is valid
```

### 6. Tests Required

- One shared fixture asserts all four profile results in PowerShell and shell.
- PowerShell 5.1/7 and bash/zsh/Bash 3.2 assert override casing, invalid values,
  WSL fallback, invalid mappings, and unknown-field preservation.
- Status JSON asserts raw/resolved separation, `path_profile_invalid`, exit 1,
  and invalid override fatal exit 3.
- Add/scan/init assert `rootPath` plus current `paths` mapping.
- Repair/status fix assert explicit missing entries remain enabled/present and
  legacy missing behavior stays compatible.
- Workspace/switch/status tests prove the resolved path reaches Set-Location,
  Git, WT/tmux, and launcher boundaries.

### 7. Wrong vs Correct

Wrong:

```text
consumer reads project.rootPath -> local convert_windows_to_wsl -> filesystem
```

Correct:

```text
project object -> shared resolver -> {raw,resolved,profile,source}
raw -> identity/mutation; resolved -> filesystem/Git/launcher
```

## Scenario: Rank Projects with Deterministic Frecency

### 1. Scope / Trigger

Apply whenever picker, project-list, multi-match query, recent-state recording,
or recent-history lifecycle changes. Status, exec, and workspace selection keep
their own explicit ordering contracts and must not consume this display rank.

### 2. Signatures

```text
score = floor(clamp(visitCount, 1, 1000) * 1000000 / (ageDays + 1))
ageDays = floor(max(0, nowEpoch - lastVisitedEpoch) / 86400)
CDP_FRECENCY=0|false|off|no
cdp recent reset [--dry-run|--yes]
Reset-CdpRecentProjects [-WhatIf] [-Confirm]
```

Internal fixed-time entry points are `Sort-CdpProjectsForDisplay -NowEpoch` and
`cdp_frecency_ranked_project_json <config> [now-epoch]`.

### 3. Contracts

- Match history by exact configured raw `rootPath`; never by name, resolved
  path, or case-insensitive comparison.
- Sort by pin rank ascending, score descending, last epoch descending, clamped
  visits descending, then original config index ascending.
- Parse the UTC `YYYY-MM-DDTHH:MM:SS` prefix. PowerShell 7 may deserialize ISO
  JSON values as `DateTime`, so normalization accepts string, `DateTime`, and
  `DateTimeOffset`; PowerShell 5.1 string behavior remains equivalent.
- Invalid/unmatched history gets zero metrics. Future time clamps to age zero.
  At most 10,000 recent entries are normalized; duplicate identities keep the
  newest valid timestamp, then greater visits.
- Missing `date` command in a minimal shell environment falls back to pin + config
  order instead of adding a new hard dependency.
- Reset preserves unknown state fields and uses the shared atomic writer.

### 4. Validation & Error Matrix

- Missing/invalid state or non-array recent history -> rank by pin + config.
- Invalid time, nonnumeric/fractional/negative visits -> zero metrics.
- `CDP_FRECENCY` disabled -> pin + config without changing match sets.
- Reset missing/empty state -> `skipped`, no write or backup.
- Reset invalid active state -> `failed` / nonzero, original bytes unchanged.
- Shell reset without `--yes` -> canceled; `--dry-run` -> preview only.

### 5. Good / Base / Bad Cases

- Good: a frequently used project rises within its pin group on every runtime.
- Base: no history retains the exact configured order inside each pin group.
- Bad: use floating-point decay, local timezone parsing, case-folded paths, or
  route status/exec/workspace through the display sorter.

### 6. Tests Required

- Run one shared fixed-now fixture in PowerShell, bash, zsh, and Bash 3.2.
- Assert pins, frequency, decay, future/invalid time, zero/negative visits,
  duplicate state, case mismatch, opt-out, and original-index fallback.
- Assert fuzzy, exact-alias, and tag query sets remain unchanged and ranked.
- Assert reset preview/approval, unknown fields, invalid bytes, and empty no-op.

### 7. Wrong vs Correct

Wrong:

```text
sort by project name or Date.now()-based floating score in each caller
```

Correct:

```text
exact raw rootPath -> one normalized integer metric -> shared display sorter
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
- Collect repository state with `git -C <resolved-path> status --porcelain=v2 --branch --untracked-files=all`; do not reintroduce separate `rev-parse`, `rev-list`, or branch probes.
- Use at most one status probe plus one `log -1 --format=%cr` probe per committed repository. Skip the log probe for an unborn or non-Git repository.
- Report tracked and untracked changes independently. If both exist, the label contains both counts.
- `NeedsAttention` is true for tracked changes, untracked files, or a positive behind count. A dirty-only header reports the number actually rendered.
- Derive ahead/behind only from a successful upstream query. Detached and no-upstream repositories remain at zero.
- `--fix` removes only enabled, non-explicit fallback missing entries selected by
  the current scan. Disabled entries and unavailable explicit profile mappings
  remain even when they share the same raw path. Mutation identity is project
  name plus raw `rootPath`, not raw path alone.
- `--push` targets only scanned Git repositories with a positive upstream-derived ahead count and reports the native push exit code accurately.
- Preserve input order while using bounded workers. `CDP_STATUS_CONCURRENCY` and `--jobs`/`-ThrottleLimit` are clamped to 1-16; the default is at most four workers.
- Keep status caching disabled unless `CDP_STATUS_CACHE_TTL` is a positive value from 1-60 seconds. PowerShell keys include normalized path plus project identity; shell records contain only Git-derived fields and key by normalized path. `--refresh` bypasses the entry.
- Enforce `CDP_STATUS_TIMEOUT_SECONDS` from 1-60 per repository. A timeout is visible as `status timed out`, needs attention, and must not prevent other repositories from completing.

### 4. Validation & Error Matrix

- Missing resolved directory -> `PathExists=false`, `StatusLabel="path missing"`; never run Git.
- Existing non-worktree directory -> `IsGitRepo=false`, `StatusLabel="not a git repo"`; never run later Git probes.
- `.git` file linked worktree -> valid Git repository.
- Upstream query failure -> ahead and behind stay zero; never become a push target.
- Behind-only repository -> needs attention and cannot produce an all-clean summary.
- `--fix` with no previewed missing entries -> no config write.
- Native `git push` nonzero exit -> render failure, never `done`.
- Porcelain/status process failure -> `status failed` or `not a git repo` according to the collector boundary; never hang the full scan.
- Expired cache entries are replaced in place; sparse array indexing must not drop later cache entries under Bash 3.2 or zsh.

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
- PowerShell and shell: an unavailable explicit current profile is reported with
  its resolved path and remains present after repair/status fix.
- PowerShell and shell: two enabled entries sharing raw `rootPath` prove status
  fix removes only the scanned name+raw identity.
- Shell: a stubbed Windows path proves status and workspace consume the resolved path.
- Shell: dirty-only output asserts the rendered project count, not the scanned total.
- PowerShell and shell: process-count tests assert no legacy Git probes; batch tests assert order, bounded overlap, timeout visibility, cache TTL, and refresh bypass.
- Bash, zsh, and Bash 3.2: default status execution must complete for non-Git paths; zsh must not use Bash-only indirect parameter expansion.
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

## Scenario: Emit Machine-Readable Status Schema Version 1

### 1. Scope / Trigger

Apply whenever status JSON fields, no-color output, attention/error codes, scan
summaries, or automation exit codes change.

### 2. Signatures

```text
cdp status [--dirty] [@tag] [--json|--no-color]
Show-CdpProjectStatus [-DirtyOnly] [-TagFilter <tag>] [-Json|-NoColor]
```

### 3. Contracts

- JSON stdout is exactly one document with `schemaVersion: 1`, `generatedAt`,
  `durationMs`, `filters`, `summary`, and an always-array `projects` field.
- Projects expose name, raw configured path, resolved local path, path existence,
  stable status, attention reasons, redacted error, and nested typed Git fields.
- Stable status values are `clean`, `changed`, `path_missing`, `not_git`,
  `scan_timeout`, and `scan_failed`.
- Stable reasons use deterministic order: `path_missing`, `scan_timeout`,
  `scan_failed`, `dirty`, `untracked`, then `behind` when applicable.
- JSON exit codes are 0 clean, 1 attention, 2 partial scan failure, and 3 fatal.
  Partial failure takes precedence; filtered-out projects do not affect the code.
- Fatal diagnostics use stderr and never leave partial JSON on stdout. JSON
  suppresses progress; no-color produces a human table with no ANSI escapes.
- JSON/no-color are read-only and cannot mix with fix/push. `-PassThru` remains
  the backward-compatible PowerShell object contract.

### 4. Validation & Error Matrix

- Empty project set -> valid document with zero counts and `projects: []`.
- Missing path -> attention reason `path_missing`, no scan error, exit 1.
- Timeout/collector failure -> redacted error object and exit 2.
- Invalid option, missing dependency/config, or serialization failure -> stderr,
  empty stdout, exit 3 in JSON mode.
- Dirty filtering -> `summary.total` remains scanned count; `shown`, projects,
  attention, failures, and exit code describe only rendered items.

### 5. Tests Required

- PowerShell 5.1/7 and bash/zsh/Bash 3.2 parse JSON and compare normalized
  schema/type/reason/error semantics for the same fixture.
- Assert stdout/stderr separation, exit codes 0-3, parser conflicts, empty arrays,
  and no ESC byte under no-color.
- Run existing table, PassThru, fix/push, cache, timeout, and performance suites.

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

## Scenario: Maintain Stable Multi-Project Workspaces

### 1. Scope / Trigger

Apply whenever workspace parsing, `workspaces.json`, path identity, launcher
selection, WT/tmux layout argv, completion, or workspace safety behavior changes.

### 2. Signatures

```text
cdp workspace list
cdp workspace show <name>
cdp workspace add <name> <projects...> [--open <launcher>] [--layout <layout>]
cdp workspace edit <name> [projects...] [--open <launcher>|--clear-open] [--layout <layout>]
cdp workspace remove <name>
cdp workspace validate [name] [--fix]
cdp workspace open <name> [--open <launcher>]
cdp workspace <name>                 # compatibility launch
```

PowerShell uses native `-WhatIf`, `-Confirm`, and `-PassThru`; shell mutations
use `--dry-run`, and external launch requires `--yes`.

### 3. Contracts

- New references persist `{name,rootPath}`; `rootPath` is exact raw identity and
  `name` is a hint. Object references never fall back to a same-name project.
- Legacy strings resolve by one exact current name and remain readable.
- `validate --fix` upgrades resolvable strings, refreshes renamed hints, preserves
  unresolved references and every unknown field, and skips byte writes if unchanged.
- Effective launcher precedence is CLI, reference `open`, workspace `open`.
- Layouts are tabs, horizontal split, or vertical split. Reference `size` is an
  integer 10-90 and applies only when creating a later split pane.
- `show` and preview expose name, status, raw/resolved path, launcher, and layout.
- Complete all schema/path/argv planning before process creation; later safe
  targets continue after one native failure, while the aggregate result fails.

### 4. Validation & Error Matrix

- Missing/non-string object `name` or `rootPath` -> `invalid-reference`.
- Non-integer/out-of-range `size` -> `invalid-size`.
- Unsafe launcher token -> `invalid-launcher`; no process.
- Zero raw-path matches -> `missing-project`; multiple -> `ambiguous-project`.
- Unique raw identity with stale hint -> `renamed`, launch current project safely.
- Deleted identity plus reused name -> `missing-project`, never name fallback.
- Invalid explicit path profile -> `invalid-path-profile`; absent directory -> `missing-path`.
- Invalid layout -> no WT/tmux process. WhatIf/dry-run -> no write or process.

### 5. Good / Base / Bad Cases

- Good: renamed `api-v2` keeps `C:/Work/api`; validation says `renamed`, fix
  updates only the hint, and launch uses the current resolved path.
- Base: `projects:["api"]` launches and migrates intentionally with `--fix`.
- Bad: bind `{name:"api",rootPath:"C:/Deleted/api"}` to a new same-name checkout.

### 6. Tests Required

- PowerShell 5.1/7 and bash/zsh/Bash 3.2 cover parser conflicts, CRUD, unknown
  fields, legacy migration, rename/delete/name-reuse/ambiguity, and no-op fix bytes.
- Assert PowerShell WT and shell tmux exact argv for tabs, both split directions,
  size, per-project launcher, CLI override, paths with spaces, and no command eval.
- Put an unsafe item before a safe item; assert aggregate failure and later native call.
- Completion asserts actions, workspace names, add/edit projects, launchers, layouts.
- Run existing persistence, safe-mutation, path-profile, CLI, and shell-v2 suites.

### 7. Wrong vs Correct

Wrong:

```json
{"name":"team","projects":["api"]}
```

as a new write, followed by runtime name fallback after project replacement.

Correct:

```json
{"name":"team","projects":[{"name":"api","rootPath":"C:/Work/api"}]}
```

Resolve only the exact raw identity; keep the string form as read compatibility.

## Scenario: Build Cross-Version PowerShell Regression Fixtures

### 1. Scope / Trigger

Apply this contract when adding Pester coverage for status actions, workspace launch, onEnter hooks, argument completers, or any behavior with process, environment, filesystem, Git, or user-config side effects. It keeps the PowerShell 5.1 and 7 suites identical and prevents regression tests from mutating the developer machine.

### 2. Signatures

The project test boundary is:

```powershell
Invoke-Pester -Path .\tests -PassThru

scripts/Invoke-PowerShellQualityGate.ps1 [-CoverageThreshold 60] [-ReportDirectory <path>]

$config = New-PesterConfiguration
$config.Run.Path = '.\tests'
$config.Run.PassThru = $true
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @('.\src\cdp.psm1', '.\src\PowerShell\*.ps1')
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
- CI pins Pester `5.7.1` and PSScriptAnalyzer `1.24.0`; the repository quality
  script owns invocation order and failure messages.
- Coverage includes the bootstrap and every PowerShell domain file, reports
  analyzed/executed command counts, and fails below the recorded 60% threshold.
- New suites remain below 600 lines; add a focused file instead of extending an oversized legacy test file.
- Configs, state files, repositories, remotes, and missing paths live under `$TestDrive`.
- Git synchronization tests use local bare remotes only. They prove success through refs and prove failure through an unavailable local path.
- Windows Terminal, editors, and AI CLIs are mocked or use an explicit production dry-run mode.
- onEnter tests execute controlled environment assignments or expected throws only; they do not start external commands.
- Environment variables, location, and module config cache are restored after each scenario that changes them.
- Argument completer tests use `TabExpansion2` so the registered command boundary, not a copied scriptblock, is exercised.
- Capture `Write-Host` output with information-stream redirection (`6>&1`) when success/failure text is part of the contract.
- Parse JSON fixtures with `ConvertFrom-Json -InputObject` and the production
  array normalizer; do not rely on pipeline enumeration inside `@(...)` under
  Windows PowerShell 5.1.
- Use framework type names such as `[System.Int16]`, not edition-dependent
  aliases such as `[short]`, in shared PowerShell 5.1/7 code.
- Test object presence with `$null -ne $value`; Windows PowerShell 5.1 can treat
  deserialized `PSCustomObject` values differently in direct boolean conditions.
- Put `@(...)` around the complete `if`/`switch` expression when its result must
  remain an array. Arrays created inside a branch are emitted again by the
  control-flow pipeline, and a single item has no reliable `.Count` in 5.1.
- Native exec probes use temporary `-File` scripts when the test targets argv,
  cwd, stderr, or exit codes; nested `powershell -Command` parsing is a separate
  host behavior and must not obscure the cdp boundary.

### 4. Validation & Error Matrix

- Real user config/state path accessed -> invalid test; redirect to `$TestDrive`.
- Network remote, `wt.exe`, or AI CLI started -> invalid test; replace with local fixture, mock, or dry run.
- PS7-only syntax or runtime feature -> compatibility failure; rewrite for Windows PowerShell 5.1.
- Environment or current location not restored -> isolation failure, even if assertions pass.
- Push ref changes but output says failure -> product regression; assert both the ref and success text.
- Hook throws -> caller must not throw; warning output is asserted.
- Coverage percent below the quality threshold -> acceptance failure; the pure
  threshold helper also has a deliberate failing regression test.
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
- Run `scripts/Invoke-PowerShellQualityGate.ps1` on PS5.1 and PS7, then shell
  gates, syntax, package integrity, and `git diff --check`.
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
- Normalize both the temporary base and the created root with a physical `pwd` around `mktemp -d`; runner-provided `TMPDIR` may end in `/`, and macOS may expose `/var` logically while `pwd -P` resolves `/private/var`.
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

The repository release and quality checks are:

```text
pwsh -File scripts/Test-ReleaseMetadata.ps1 [-RepositoryRoot <path>]
powershell.exe -File scripts/Test-ReleaseMetadata.ps1 [-RepositoryRoot <path>]
pwsh -File scripts/Invoke-PowerShellQualityGate.ps1 [-CoverageThreshold 60]
bash scripts/Test-ScoopPackage.sh [<output.tar.gz>]
node scripts/Test-WebAssets.mjs
node scripts/Test-Documentation.mjs
pnpm --dir tests/web test
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
- `scripts/Test-ScoopPackage.sh` checks every tracked `src/PowerShell` and
  `src/Shell` source file is packaged, rejects repository-only entries, and
  compares the archive digest with `scoop/cdp.json`.
- Shell release tooling normalizes a trailing carriage return before parsing
  `ModuleVersion`; a fresh checkout follows `.gitattributes` and may materialize
  `cdp.psd1` with CRLF even when a developer's existing worktree is LF or mixed.
  The staged package explicitly normalizes directories to `0700` and files to
  `0600` so archive metadata does not depend on checkout modes or caller umask.
- Browser tooling stays isolated under `tests/web`; the dedicated CI job calls
  repository-owned asset and Playwright entries and uploads its report.
- Installer/metadata validators do not accept, read, print, or persist Gallery API keys.
- Gallery publication verification enumerates the official feed or requests an
  exact version through PowerShellGet. A versioned package page or download HTTP
  200 is not sufficient: the Gallery may redirect a missing version to the
  latest existing `.nupkg`, so verify the resolved package identity and version.
- In Windows PowerShell 5.1 negative process tests, native stderr redirected with `2>&1` becomes an ErrorRecord. Temporarily use `ErrorActionPreference=Continue` only around the expected failing child and restore it in `finally` before asserting exit code/output.

### 4. Validation & Error Matrix

- Edition/scope root absent from `PSModulePath` -> resolver throws; copy does not start.
- AllUsers without administrator privileges -> installer exits nonzero before mutation.
- Existing module without `-Force` and user declines -> clean cancellation; no overwrite.
- Only an old module at another `ModuleBase` -> exact verification fails.
- Target module version differs from copied manifest -> exact verification fails with found/expected versions.
- Any checked metadata version, Scoop URL, extract directory, dependency, or installer command drifts -> validator lists the mismatched key and exits nonzero.
- Current repository is consistent -> validator reports the canonical version and exits zero under PowerShell 5.1 and 7.
- Quality gate tool missing or wrong pinned version -> quality job fails before tests.
- Package content or digest drift -> package gate lists the missing/forbidden
  entry or expected/actual digest and exits nonzero.
- CRLF manifest checkout or a caller `umask` such as `0002` -> version parsing
  still returns the canonical version and produces the same package digest and
  normalized `0700`/`0600` modes as the release asset.
- Missing metadata file or invalid manifest/JSON -> validator exits nonzero before release work.
- Missing exact Gallery version -> the feed remains on an older version; a
  versioned package request may redirect to that older package and still end in
  HTTP 200. Record the credential/channel blocker instead of reporting success.

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
accept HTTP 200 from a Gallery version URL without checking the resolved nupkg version
```

### 6. Tests Required

- Path matrix: CurrentUser/AllUsers crossed with Core/Desktop, using isolated Documents, ProgramFiles, and `PSModulePath` values.
- Resolver error: required edition root missing from injected `PSModulePath`.
- Exact selection: target path/version succeeds; same version elsewhere fails; wrong version at target fails.
- Metadata positive: current repository passes in PowerShell 5.1 and 7.
- Metadata negative: copy required files to `$TestDrive`, mutate Scoop version, run the validator in a separate same-edition process, assert nonzero and `scoop.version` output.
- Package regression: run the deterministic content/hash gate under multiple
  umasks and with an isolated CRLF-manifest checkout.
- CI runs the repository-owned PowerShell quality gate in both Windows jobs and
  uploads the NUnit/JaCoCo reports from PowerShell 7.
- CI runs the static/media gate before provisioning Chromium, then executes the
  pinned Playwright smoke and uploads its HTML report even on failure.
- Final gate also includes PSScriptAnalyzer on installer/scripts/module, Scoop JSON and workflow YAML parsing, shell regressions/syntax, secret-reference search, Trellis validation, and `git diff --check`.
- Post-release verification checks the exact Gallery version in the feed or
  through `Find-Module`; when following a package redirect, assert the resolved
  `.nupkg` version instead of only its final HTTP status.

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
