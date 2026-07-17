# PowerShell v2 回归测试实施计划

## Order

1. 记录 38-test 与 55.90% coverage 基线。
2. 新建独立 Pester 文件及最小 Git/config helper。
3. 增加 status 结构化过滤、fix/push 目标与失败路径测试。
4. 增加 workspace add/list、空格路径、缺失项目和 mocked launch 测试。
5. 增加 onEnter env、PowerShell hook 与异常隔离测试。
6. 增加 subcommand、project、launcher argument completer 测试。
7. 在 PowerShell 7 定向执行，修复测试隔离或真实缺陷。
8. 在 Windows PowerShell 5.1 执行同一测试集。
9. 运行全量 Pester、PSScriptAnalyzer、coverage、shell 回归、WSL syntax 与 diff check。
10. 更新 task 验证证据与测试 code-spec，提交并归档一次。

## Files

- `tests/cdp.PowerShell.V2.Tests.ps1`
- 必要时最小修改 `src/cdp.psm1`
- `.trellis/spec/backend/quality-guidelines.md`
- 当前 Trellis task artifacts

## Validation

- PowerShell 7 full Pester。
- Windows PowerShell 5.1 full Pester。
- Pester code coverage：最终 percent 必须大于 55.90%。
- PSScriptAnalyzer `Severity Error`。
- 既有 Git Bash CLI/status tests 与 WSL bash/zsh syntax。
- `git diff --check` 与 Trellis task validation。

## Risk Controls

- 不调用真实网络 remote、Windows Terminal 或 AI CLI。
- 不读取或写入真实用户 config/state。
- 测试结束恢复进程环境变量和当前目录。
- 不在本任务内重构生产模块或改变 hook 信任策略。
