# 修复安装器与发布元数据一致性

## Goal

保证 PowerShell 5.1/7 都能从脚本安装后发现模块，并让发布元数据漂移在 CI 中立即失败。

## Requirements

- CurrentUser/AllUsers 安装目录基于实际模块搜索路径与 PSEdition 选择。
- 安装验证必须核对本次目标路径，而不是任意同名旧模块。
- Scoop 不得继续固定在 1.8.0，正式发布记录不得使用不可验证的占位状态。
- 建立脚本核对 manifest、PowerShell/Bash 运行时、测试预期、Scoop、CHANGELOG 和 PROGRESS。
- 更新安装相关双语文档。

## Acceptance Criteria

- [ ] 隔离环境下 PowerShell 5.1 与 7 安装路径选择测试通过。
- [ ] 版本或元数据不一致会使验证命令非零退出。
- [ ] 当前已确认的 1.8.0/2.0.3 漂移被消除。
- [ ] 不打印或写入任何 Gallery API key。
