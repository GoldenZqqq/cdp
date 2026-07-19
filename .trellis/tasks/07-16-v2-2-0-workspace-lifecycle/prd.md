# 完善 workspace 生命周期

## Goal

把只能 add/list/launch 的 workspace 扩展为可维护、可验证、可迁移的长期配置，
并确保项目重命名、删除或路径变化时不会启动到错误目录。

## Background

- 当前 `workspaces.json` 是数组，workspace 仅含 `name`、字符串项目名数组和
  可选 `open`；项目名重命名后只能表现为缺失，无法安全确认身份。
- PowerShell 使用 Windows Terminal tabs，shell 使用 tmux windows；当前没有
  show/edit/remove/validate、布局 schema 或 per-project launcher override。
- path profiles 已提供稳定 raw `rootPath` identity 和 resolved local path。

## Requirements

### R1. 命令生命周期

- 支持 `list`、`show <name>`、`add <name> <projects...>`、
  `edit <name> [projects...]`、`remove <name>`、`validate [name] [--fix]` 和
  `open <name>`；保留 `workspace <name>` 启动兼容。
- add/edit/remove/validate-fix/launch 支持 PowerShell `-WhatIf` 与 shell
  `--dry-run`；shell 高影响动作继续要求 `--yes`。
- 补全 workspace action、workspace 名、项目名、launcher 与 layout 值。

### R2. 稳定项目引用与迁移

- 新 workspace 将项目保存为 `{name, rootPath}` 引用；`rootPath` 是稳定 raw
  identity，`name` 是可读 hint。
- 旧字符串项目名数组继续可读和可启动。
- `validate --fix` 将可解析的旧字符串引用迁移为对象，并按 rootPath 刷新已
  重命名项目的 name；无法解析的引用保留并报告，不猜测或绑定同名新项目。
- 对象引用按 raw rootPath 匹配；项目重命名可诊断并安全启动，删除/歧义引用
  必须失败，不得按同名错误项目回退。

### R3. Schema

- workspace 可选 `open` 是默认 launcher。
- project reference 可选 `open` 覆盖 workspace launcher，可选 `size` 为 split
  布局的 10-90 百分比。
- workspace 可选 `layout`：`mode=tabs|split`，split 时
  `direction=horizontal|vertical`；缺失时兼容为 tabs。
- CLI `--open` 最高优先级，其次 project `open`，再次 workspace `open`。
- 未知字段无损保留，非法 launcher/layout/reference 由 validate 报告。

### R4. 启动与诊断

- 启动前完成 workspace schema、引用与路径计划；每个安全目标独立执行，
  失败项不阻止后续安全项，但最终结果必须失败。
- Windows Terminal tabs 与 tmux windows 对应 `tabs`；WT `split-pane` 与 tmux
  `split-window` 对应 `split`，方向与 size 语义保持一致。
- dry-run/show 输出稳定计划：workspace、layout、项目当前名、raw/resolved path、
  launcher、引用状态，不创建进程。

## Out of Scope

- 任意树形 pane DSL、窗口坐标或平台专属布局配置。
- 自动修复已删除项目、模糊匹配或按同名绑定新的 raw identity。
- GUI workspace 编辑器。

## Acceptance Criteria

- [x] 完整 CRUD、验证、补全和 dry-run 在 PowerShell/bash/zsh/Bash 3.2 通过。
- [x] 新引用按 raw rootPath 稳定匹配；重命名可诊断，删除/同名替代不会启动。
- [x] 旧字符串 workspaces.json 可读，validate-fix 可无损迁移可解析引用。
- [x] tabs/split、launcher precedence 与 per-project override 在 WT/tmux fixture
  中行为对等。
- [x] 双语文档、spec、版本元数据、生成 shell 和完整质量门禁通过。
