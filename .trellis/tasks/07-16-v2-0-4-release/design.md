# v2.0.4 发布事务设计

## Scope

本任务是 v2.0.4 唯一远程发布事务。release content 以最终 release commit 为边界；随后产生的 Trellis/PROGRESS bookkeeping commit 不改变 tag 内容。

## State Machine

```text
local validated
  -> release commit
  -> main pushed
  -> main CI green
  -> annotated tag pushed and SHA verified
  -> GitHub Release public
  -> PowerShell Gallery 2.0.4 indexed
  -> tag archive + Gallery package verified
  -> evidence/bookkeeping pushed
```

任一阶段失败时停止在当前状态，不越过依赖阶段。只有 release content 在 tag 后需要修复时，才按仓库规则先提交/push fix、重跑 CI、移动 annotated tag，再继续尚未创建的 Release/Gallery；已公开渠道后不静默移动 tag。

## Release Commit Boundary

- `cdp.psd1`、PowerShell/Bash runtime、tests、Scoop、CHANGELOG、PROGRESS target 已由 metadata validator 绑定为 2.0.4。
- release commit 更新 `PROGRESS.md` 为“本地 release candidate 已验证，远程发布 pending”，并包含当前 release task planning/status。
- annotated tag `v2.0.4` 必须 peel 到该 commit SHA。

## Validation Matrix

- Windows PowerShell 5.1 与 PowerShell 7：full Pester `58/58`，metadata validator。
- PSScriptAnalyzer：`Install.ps1`、`scripts/*.ps1`、`src/cdp.psm1` Error severity。
- Git Bash：CLI parser、status、shared shell v2。
- WSL Arch：bash/zsh shared shell v2，bash/zsh syntax。
- Scoop JSON、workflow YAML、`git diff --check`、Trellis task validation。

## Remote Operations

1. `git push origin main`，记录 pushed SHA。
2. `gh run list/watch` 等待该 SHA 对应 main CI 成功。
3. 创建/push annotated `v2.0.4`，核对 HEAD、peeled tag、remote tag。
4. `gh release create --verify-tag --latest`，核对 public/non-draft/non-prerelease。
5. 检查 key 仅输出 PRESENT，再运行 `Publish-ToGallery-Alt.ps1`。
6. 等待 Gallery indexing，核对 `Find-Module -RequiredVersion 2.0.4` 与 package page。

## Artifact Verification

- 下载 tag ZIP 到临时目录，展开后运行 repository metadata validator、manifest 和脚本解析；不执行安装器写入。
- `Save-Module -RequiredVersion 2.0.4` 到临时目录，核对保存的 manifest version 与 module files；不安装到用户模块目录。
- 核对 GitHub Release URL、Gallery URL 和 archive HTTP status。

## Evidence and Rollback

发布证据写入 release task PRD 与 `PROGRESS.md`。临时下载目录可删除；不删除 tag/Release/Gallery。发布前失败可修复并重试，发布后渠道不可逆问题必须显式报告。
