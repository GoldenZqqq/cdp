# v2.0.4 稳定性修复与发布

## Goal

修复 v2.0.3 已确认的安装、命令解释、状态面板和测试缺口，在不扩大产品范围的前提下发布可信的补丁版本。

## Requirements

- 先修复行为，再补覆盖，再完成安装/元数据与发布收口。
- 叶子任务顺序：CLI parser、status correctness、PowerShell tests、shell tests、installer metadata、release。
- 该版本不进行大规模模块拆分、hook 信任模型或新产品功能开发。

## Acceptance Criteria

- [x] 所有 6 个子任务完成并各自拥有独立 work/archive 提交。
- [x] 组合参数、跨平台 status 和安装路径问题均有自动化回归测试。
- [x] PowerShell 5.1/7 Pester、PSScriptAnalyzer Error、bash/zsh syntax、shell regression、`git diff --check` 全部通过。
- [x] 统一 push 后 CI 成功，v2.0.4 tag、GitHub Release、PowerShell Gallery 和 Scoop 均核验成功。
