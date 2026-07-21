# 技术设计：Gallery 与本地安全语义收口

## 基线与边界

所有实现从当前 `main` 开始。旧提交只通过 `git show archive/...` 读取需求、测试和行为证据；不将旧路径直接恢复到 `src/private` 或 `src/shell`。

## Release boundary

`cdp.psd1` 只保留当前 release notes，`CHANGELOG.md` 保留完整历史。`Publish-ToGallery-Alt.ps1` 在构建 nuspec 前检查 notes 长度，在 native nuget pack/push 后读取 `$LASTEXITCODE`，失败即抛错并清理临时目录。发布验证使用 PowerShellGet exact version、Gallery package metadata 和 GitHub Release JSON。

## Status data flow

```text
local porcelain-v2 scan
  -> immutable status snapshot
  -> explicit bounded fetch phase (optional)
  -> sync-only refresh of HEAD/upstream/remote identity
  -> render / PassThru / frozen push plan
```

PowerShell 复用 `Cdp.Status.ps1` / `Cdp.Status.Fetch.ps1` / `StatusBatch.ps1` 的现有进程边界；shell 复用 `Status.sh` / `StatusBatch.sh` 的数组快照和 cleanup trap。字段至少包含 `Freshness`、`FetchAttempted`、`FetchSucceeded`、`FetchTimedOut`、`FetchMessage`、`HeadOid`、`RemoteName`、`RemoteRef`、`RemoteUrl`。URL 只用于脱敏展示，native stderr 不进入结果。

fetch 调度器限制 jobs 和 timeout，所有退出路径终止 active descendants 并删除私有临时文件。同步刷新后，push plan 固定 `remote + exact remote ref + exact local oid`，审批、执行和结果报告均不重新解析目标。

## Launcher audit

先把旧安全测试迁移为当前 API 的 black-box tests：launcher 名称、项目路径、项目名、特殊 argv、stored workspace、direct switch、dry-run/WhatIf。若远端已有 whitelist/native argv 行为满足测试，只保留测试与文档；若 Windows Terminal 仍将用户数据拼接为 command text，则在当前 `Workspace.ps1` 的 launch-plan 边界加入结构化 argv/payload 隔离，并同步 shell 回归。

## Compatibility and rollback

- PowerShell 5.1 不使用 ThreadJob、`ForEach-Object -Parallel` 或 PS7-only syntax。
- bash/zsh 保持生成 bundle 单文件安装契约；fragment 改动后重建 bundle。
- 每个子变更可单独回滚：release metadata/script、status fetch、launcher audit 分开验证。
- 不改变 v2.2.0 版本号；发布收口修复只影响打包与验证，不改变运行时 public API。
