# bash/zsh v2 回归测试实施计划

## Order

- [x] 新建共享 shell test entry 与 assertion/helper 边界。
- [x] 迁移 Ubuntu/macOS 内联 core lifecycle smoke。
- [x] 增加 jq/git/fzf 缺失与 missing/invalid config 断言。
- [x] 增加受控 onEnter 成功与失败隔离断言。
- [x] 增加 fake tmux workspace add/list/launch 与空格路径断言。
- [x] 增加 bash/zsh completion adapter 断言。
- [x] 增加 Windows path 与 launcher 参数组合断言。
- [x] 在 Git Bash 运行 bash 模式，在 WSL Arch 运行 zsh 模式。
- [x] 将 CI 内联 smoke 替换为共享入口调用。
- [x] 运行 PowerShell、shell、syntax、whitespace 与 Trellis 全量门禁。
- [ ] 更新 task 证据与 shell testing code-spec，提交并归档一次。

## Files

- `tests/cdp.Shell.V2.Tests.sh`
- `.github/workflows/test.yml`
- 必要时最小修改 `src/cdp.sh`
- `.trellis/spec/backend/quality-guidelines.md`
- 当前 Trellis task artifacts

## Validation

- Git Bash：CLI/status 既有脚本与共享 bash entry。
- WSL Arch：共享 zsh entry、bash/zsh syntax。
- PowerShell 5.1/7 full Pester 与 PSScriptAnalyzer。
- `git diff --check` 与 Trellis task validation。

## Risk Controls

- 不卸载依赖、不改系统 PATH；negative tests 只影响子 shell。
- 不运行真实 tmux、GUI、AI CLI 或网络 push。
- 不读取或写入真实用户 config/state。
- 生产修复仅限新增回归证明的当前 v2 缺陷。
