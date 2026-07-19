# Safe Mutation Design

## Risk Classes

Every mutation has a preview boundary. Risk determines whether execution also
requires explicit approval by default.

- Low: add one project, pin/unpin, alias/tag, workspace definition, hook trust
  metadata. PowerShell uses `ShouldProcess` with Medium impact; shell accepts
  `--dry-run` and `--yes`, while preserving default execution compatibility.
- High: config repair, project removal, repository scan/import, status fix,
  status push, active-config selection, and launching external multi-project
  workspaces. PowerShell uses High-impact `ShouldProcess`; shell requires
  `--yes` unless `--dry-run` is selected.

Read-only `status`, list, doctor, hook list, and picker behavior remain free of
confirmation.

## Action Results

PowerShell mutation functions emit action result objects only through
`-PassThru`:

```text
Action, Target, Status, Changed, Error
```

Batch functions additionally keep their existing aggregate fields. Status
fix/push returns one result per target under `-PassThru`; a failed push is
`Status=failed` and does not stop later repositories.

Shell prints one redacted result line per target and returns nonzero when any
item fails. It never reports `done` before checking the native exit status.

## CLI Contract

```text
PowerShell: -WhatIf, -Confirm, -PassThru
shell:      --dry-run, --yes
```

Common parser rules reject `--dry-run --yes`, missing action values, and safety
flags on read-only commands. Dry-run validates and renders targets but performs
no JSON write, push, launcher process, config-choice write, or hook-trust write.

## Workspace Launch

Workspace definition creation is a low-risk JSON mutation. Workspace opening
is an external side effect: PowerShell uses `ShouldProcess`; shell requires
`--yes` or supports `--dry-run`. The existing `CDP_OPEN_DRY_RUN` test boundary
remains valid for launcher argv assertions but does not replace user-facing
approval.

## Non-Interactive Safety

High-impact shell actions never infer approval from TTY presence. Without
`--yes`, they return nonzero after showing the plan. PowerShell uses native
`ShouldProcess`; automation supplies `-Confirm:$false`, and preview supplies
`-WhatIf`.

## Compatibility

- Existing read-only and low-risk command syntax remains valid.
- Existing status safety flags remain unchanged.
- PowerShell 5.1, Bash 3.2, and zsh remain supported.
- No confirmation prompt is read from stdin, preventing test/iterator stream
  consumption and ensuring deterministic non-interactive behavior.

## Failure Semantics

Dry-run is success when validation succeeds. Missing explicit approval for a
high-impact shell action is a nonzero refusal. Batch operations continue after
per-item failures, render every result, and finish nonzero / return failed
objects. JSON writes retain atomic fingerprint conflict behavior.
