# 准备并发布 v2.1.0

## Goal

在九个工程子任务全部完成后，生成并验证唯一 v2.1.0 发布候选，通过 main CI 后发布 GitHub tag/Release/资产、PowerShell Gallery 和 Scoop 可用渠道。

## Background

- 九个前置工作提交与任务归档均已完成：atomic config、hook trust、safe mutations、PowerShell modularization、shell modularization、status performance、CI quality、Web/media quality、spec/documentation refresh。
- 本地 `main` 当前比 `origin/main` 超前 25 个提交，工作区 clean，`v2.1.0` 本地/远程 tag 均不存在。
- GitHub CLI 已登录并具有 `repo` / `workflow` 权限；当前环境缺少 `PS_GALLERY_API_KEY`。
- Scoop URL 要求 GitHub Release 上传精确命名的 `cdp-2.1.0.tar.gz`，其 SHA-256 必须与 `scoop/cdp.json` 一致。

## Requirements

- 审计九个子任务的工作提交、完成状态、版本与 ReleaseNotes/CHANGELOG/README/Scoop 同步。
- 重新运行 PowerShell、bash/zsh/Bash 3.2、status benchmark、installer、package、documentation、media、Chromium、YAML/JSON 与 whitespace 全量门禁。
- 生成唯一发布资产和 release notes，记录 SHA-256、大小与内容清单。
- 在获得明确远程授权后，同步远端、push release commit、等待 main CI、创建并验证 annotated tag、GitHub Release 与资产。
- 仅通过 `$env:PS_GALLERY_API_KEY` 发布 Gallery；不读取、打印或提交密钥。
- 验证 GitHub Release 下载资产、Scoop manifest、PowerShell Gallery 精确版本和安装/升级通道。

## Acceptance Criteria

- [x] 九个前置子任务各有工作提交、归档和验收证据。
- [x] 本地 release candidate 的全量门禁、资产内容和 manifest hash 全部通过。
- [ ] 发布 commit SHA、annotated tag、main CI、GitHub Release URL/资产 hash 证据完整。
- [ ] PowerShell Gallery 显示精确 v2.1.0，或明确记录因缺少外部 API key 而无法完成的唯一阻塞。
- [ ] PowerShell 5.1/7、bash/zsh/Bash 3.2、Scoop 与源码安装升级路径不回归。

## Local Preparation Notes

- Release matrix and benchmark results are recorded in `release-evidence.md`.
- Retained asset: `artifacts/release/cdp-2.1.0.tar.gz`, 91,067 bytes,
  SHA-256 `07e2b39dfdc77361b6abd0fe67f1bf2ad923deb7e81ce5a081b62755f71bb74c`.
- Remote main is not divergent and `v2.1.0` does not exist.
- External write authorization and `PS_GALLERY_API_KEY` remain pending.

## External Authorization Boundary

- 未获得用户明确授权前，不执行 `git pull --rebase`、`git push`、tag push、GitHub Release 创建或 Gallery 发布。
- 不要求用户在对话中粘贴 API key；用户应在环境中设置 `PS_GALLERY_API_KEY`。
