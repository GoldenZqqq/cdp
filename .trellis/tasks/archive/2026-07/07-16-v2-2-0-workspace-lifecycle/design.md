# Workspace 生命周期技术设计

## 1. 持久化 schema

保持 `workspaces.json` 顶层数组：

```json
{
  "name": "fullstack",
  "open": "codex",
  "layout": { "mode": "split", "direction": "horizontal" },
  "projects": [
    { "name": "api", "rootPath": "C:/Work/api" },
    { "name": "web", "rootPath": "C:/Work/web", "open": "code", "size": 40 }
  ]
}
```

Legacy `projects: ["api", "web"]` remains valid input. New writes use object
references. Existing unknown workspace/reference fields survive edit/migration.

## 2. Reference resolution

Normalized result carries workspace name, reference index/type, configured name,
raw rootPath, current project, resolved path, launcher, size, status and message.

- object reference: exact raw rootPath match; zero/multiple matches are errors.
- legacy string: exact current project name only; never fuzzy match.
- matching rootPath with changed name: `renamed`, safe to launch current project.
- path resolver failure/missing directory: validation error and no launch.

`validate --fix` upgrades resolvable strings and refreshes stale object names while
retaining unresolved entries for manual repair.

## 3. Command parser

Normalized workspace invocation fields add:

```text
WorkspaceAction, WorkspaceName, Projects, WorkspaceLayout,
ClearOpen, Fix, ConfigPath, Open, DryRun, Yes
```

Actions: `usage|list|show|add|edit|remove|validate|open`. Layout CLI values map:

```text
tabs -> {mode:tabs}
split-horizontal -> {mode:split,direction:horizontal}
split-vertical -> {mode:split,direction:vertical}
```

Edit replaces projects only when positionals are supplied; otherwise it updates
only explicitly supplied open/layout fields. `--clear-open` removes workspace
launcher and conflicts with `--open`.

## 4. Launch planning

```text
read workspace -> validate schema -> resolve stable refs -> resolve path profiles
-> derive launcher precedence -> render/approve -> WT or tmux argv execution
```

Tabs create WT tabs or tmux windows. Split creates the first tab/session then
subsequent WT `split-pane` or tmux `split-window`; horizontal/vertical and optional
size map to native argv. No command strings are evaluated.

## 5. Safety and persistence

- Workspaces use existing atomic JSON fingerprint/lock/backup boundary.
- show/list/validate are read-only; validate-fix/add/edit/remove write only after
  full validation and approval.
- launch validates all targets before any process and then continues safe later
  targets after per-target native failure.
- dry-run produces action results and exact plan without writes/processes.

## 6. Compatibility and rollback

- Old arrays and string refs are read without mutation.
- New object refs are ignored only by old cdp workspace implementations, so README
  documents that workspace lifecycle config requires v2.2+ while project config
  remains old-client compatible.
- Rollback does not rewrite data; users can run validate-fix only intentionally.
