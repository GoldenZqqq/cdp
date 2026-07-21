# 收口 v2.2.0 Gallery 与本地安全语义

## Goal

以最新 `main` 为唯一产品基线，完成 v2.2.0 PowerShell Gallery 发布证据收口，并把旧本地分支中尚未被远端吸收的 status remote semantics 与 launcher safety 需求转换为当前模块架构下可验证、可维护的实现。

## Background

- `main` 已快进到远端最新提交，v2.2.0 GitHub Release 和 PowerShell Gallery 包均应可验证。
- 旧本地 `48d5dfd` 基于已废弃的 `src/private` / `src/shell` 结构，不能整体 cherry-pick。
- 远端已有 status-performance、hook trust、workspace launcher 白名单和跨平台测试；本任务只补未吸收的行为。
- 发布过程中发现 `Publish-ToGallery-Alt.ps1` 未检查 native `nuget push` 退出码，且过长 ReleaseNotes 会被 Gallery 拒绝；两项发布收口修复属于本任务范围。

## Requirements

### R1. Release evidence

- `cdp.psd1` 的 v2.2.0 ReleaseNotes 符合 Gallery 10,600 字符限制，历史版本说明继续由 `CHANGELOG.md` 维护。
- 发布脚本在 pack/push 失败时返回非零并输出明确错误，禁止假成功。
- 记录并验证 `Find-Module -RequiredVersion 2.2.0`、Gallery 页面和 GitHub Release 状态。

### R2. Status remote semantics

- 在当前 `src/PowerShell/Status*.ps1` 与 `src/Shell/Status*.sh` 架构中移植旧设计的 freshness、fetch audit 和 frozen push snapshot 契约。
- 默认 status 仍不联网；fetch 是显式阶段，使用 bounded jobs/timeout、进程清理和脱敏错误。
- fetch 后重新读取 upstream/HEAD/ref identity；push 只能使用审批前冻结的 exact remote/ref/oid，不能因状态变化扩大目标。
- PowerShell、bash/zsh、structured result、table 和 tests 共用同一字段语义；不恢复旧文件路径或旧版本号。

### R3. Launcher safety audit

- 将旧 `dbedad5` 的恶意 launcher、动态命令文本、特殊路径/项目名和副作用前置拒绝测试适配到当前 workspace lifecycle。
- 评估远端现有 launcher whitelist、native argv 和 Windows Terminal/tmux 计划是否足够；只有失败的回归才增加实现。
- 不允许把 workspace/project 名称或路径拼接成 PowerShell command text；dry-run/WhatIf 不得启动子进程。

### R4. Reconciliation cleanup

- 旧 status-performance WIP、hook trust 旧实现和旧本地主干只作为审计来源，不进入新主干。
- 全部回归通过且候选需求已吸收后，删除旧备份分支、归档候选分支、stash 和 bundle；删除前输出精确对象并确认工作区干净。

## Acceptance Criteria

- [x] Gallery v2.2.0 可通过 PowerShellGet exact lookup 验证，GitHub Release/tag 状态保持正确。
- [x] 发布脚本有 ReleaseNotes 长度门禁和 native pack/push exit-code 门禁，并有对应回归断言。
- [ ] status remote semantics 在 PowerShell 7、Windows PowerShell 5.1、Git Bash/WSL bash/zsh 的 focused tests 通过；默认无网络路径与原有 JSON/status schema 不回归。
- [x] frozen push、fetch timeout/cancel、脱敏错误、远端 identity 和 freshness 状态均有可重复测试。
- [x] launcher safety focused tests 覆盖 direct/stored/workspace、特殊 argv、dry-run/WhatIf 和副作用前置拒绝；现有 PowerShell/shell V2 矩阵保持通过。
- [x] Pester、PSScriptAnalyzer、shell bundle/syntax、Trellis validation、`git diff --check` 全部通过。
- [ ] 清理后只保留 canonical `main`（以及用户明确保留的远端跟踪引用），无旧 stash/bundle/归档分支。

## Out of Scope

- 不整体合并 `backup/local-main-20260721` 或旧三条候选提交。
- 不发布下一版本，不新增依赖，不改变 config/schema，不引入后台 daemon 或跨命令持久化 cache。模块变更按仓库 release gate 准备为 v2.3.0，但不得创建 tag、Release、Gallery 包或远端 push。
- 不自动 push 新代码；代码提交和远端同步另行确认。
