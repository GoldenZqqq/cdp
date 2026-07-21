# 准备并发布 v2.2.0

## Goal

在五个自动化功能任务完成后，生成并验证唯一的 v2.2.0 发布候选，通过 `main` CI 后发布 annotated tag、GitHub Release、确定性 Scoop 资产和可用的 PowerShell Gallery 渠道。

## Background

- status JSON、path profiles、workspace lifecycle、multi-repository exec 和 frecency ranking 五个前置任务均已实现、验证并归档。
- `main` 与 `origin/main` 当前同为 `9bc3b11b7747346723e26796a21d1f29a3b698eb`，工作树 clean；CI run `29799179690` 的五个托管作业全部成功。
- `cdp.psd1`、PowerShell/shell 运行时、测试、CHANGELOG 和 Scoop 已指向 `2.2.0`；远端不存在 `v2.2.0` tag 或 GitHub Release。
- 确定性候选资产为 `cdp-2.2.0.tar.gz`，其 SHA-256 必须与 `scoop/cdp.json` 一致。
- 当前环境缺少 `PS_GALLERY_API_KEY`；Gallery 发布只能在凭证存在时执行，缺失时必须如实记录外部阻塞。

## Requirements

- 审计五个前置任务的归档、工作提交、验收证据，以及版本、schema/迁移说明、ReleaseNotes、CHANGELOG、Scoop、官网和双语 README 的同步状态。
- 运行 PowerShell 7 本地质量门禁，以及 bash/zsh/Bash 3.2、contract、安装、性能、安全、文档、Web、确定性 package 和 release metadata 门禁；Windows PowerShell 5.1 由相同脚本的托管 CI 结果兜底。
- 只生成并保留一个确定性发布资产，记录其路径、字节数、SHA-256 和内容清单；上传后必须按公共 URL 重新下载并逐字节核验。
- 在最终 release commit 推送到 `main` 且精确 CI run 成功后，才创建并推送 annotated tag `v2.2.0`，随后创建 non-draft、non-prerelease GitHub Release。
- 仅通过环境变量 `PS_GALLERY_API_KEY` 发布 PowerShell Gallery；不得读取、打印、提交或在对话中索取密钥内容。
- 验证 tag peeled SHA、GitHub Release 元数据、Release/Scoop 下载 hash、PowerShell Gallery 精确版本，以及可执行的源码/包安装升级路径。

## Acceptance Criteria

- [x] 五个前置子任务各有独立工作提交、归档和验收证据。
- [x] 本地 release candidate 的全量门禁、旧配置兼容、升级/降级说明、资产内容和 manifest hash 全部通过。
- [x] 最终 release commit SHA、annotated tag、精确 `main` CI、GitHub Release URL 和公共资产 hash 证据完整。
- [x] PowerShell Gallery 显示精确 v2.2.0，或明确记录缺少外部 API key 的唯一阻塞且不虚报发布成功。
- [x] PowerShell 5.1/7、bash/zsh/Bash 3.2、Scoop 和源码安装路径不存在发布阻断性回归。

## Out of Scope

- 不在本任务中扩展 v2.2.0 功能或修改已经稳定的公开 contract；发现发布阻断性缺陷时回退到修复、复验、重新提交流程。
- 不重写已发布渠道的不可变资产；公开发布后发现内容错误时改发补丁版本。
- 不因缺少 Gallery 凭证而削弱其他发布门禁或伪造渠道验证结果。
