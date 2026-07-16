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
