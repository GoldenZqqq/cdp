# status 跨平台正确性设计

## Scope

修复状态计算、跨平台路径解析、Git 仓库识别、汇总与 `--fix/--push` 目标选择。并发、缓存和 Git 进程合并留给 v2.1.0 性能任务。

## Data Flow

```text
projects.json rootPath
  -> platform path resolver
  -> Git repository probe
  -> branch/worktree/upstream facts
  -> normalized status object/arrays
  -> filter or action target selection
  -> terminal rendering
```

原始配置路径用于 JSON 身份匹配；解析后的本地路径用于文件系统与 Git 命令。两者不能混用。

## Contracts

### Repository detection

- 路径存在后调用 `git -C <path> rev-parse --is-inside-work-tree`。
- `true` 视为工作树，包括 `.git` 目录和 `.git` 文件形式的 linked worktree。
- 命令失败或非 true 视为 non-git，不继续执行 status/rev-list/log。

### Working tree label

- clean：`clean`
- only tracked changes：`N dirty`
- only untracked：`N untracked`
- both：标签必须同时包含 dirty 与 untracked 数量。
- 任一 tracked/untracked 或 behind 大于 0 时 `NeedsAttention = true`。

### Path resolution

- PowerShell 使用原始 Windows 路径。
- bash/zsh 对每个 project/workspace rootPath 调用现有 `convert_windows_to_wsl`，再检查目录和执行 Git/tmux。
- 配置修复仍按原始 rootPath 精确识别 JSON entry。

### Action targets

- `--fix` 只删除本次扫描中展示为 `path missing` 的 enabled entry；不得顺便删除 disabled missing entry。
- `--push` 只选择 `IsGitRepo && AheadCount > 0`；ahead 只能来自成功的 upstream 查询。
- PowerShell 必须根据 Git native exit code 判断 push 成败，不能把非零退出打印为 done。

## Compatibility

- 不改变 `Show-CdpProjectStatus` 公共参数。
- 不新增网络 fetch；ahead/behind 仍基于本地 remote-tracking refs。
- 终端表格保持原列，仅允许扩大 Status 列以容纳组合状态。

## Rollback

改动集中在 status 数据采集、shell workspace path resolution、动作选择和测试；不迁移配置。整体回退任务提交即可恢复 v2.0.4 parser 基线。
