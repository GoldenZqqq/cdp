# status 跨平台正确性实施计划

## Order

1. 增加 PowerShell linked worktree、dirty+untracked、behind-only 和 `--fix` 精确目标失败测试。
2. 增加 shell worktree、组合状态、behind summary、fix 保留 disabled entry 的测试。
3. PowerShell 改用 Git probe 并生成完整 working-tree label。
4. shell status 同时维护 raw/resolved path，改用 Git probe并修复 behind 计数。
5. PowerShell/shell `--fix` 仅删除扫描出的 missing entries。
6. PowerShell push 检查 native exit code；shell 保持逐项返回。
7. shell workspace 在 tmux/列表路径上使用 resolved path。
8. 同步 ReleaseNotes、CHANGELOG 和双语用户说明。
9. 运行定向、全量、跨平台与 whitespace 验证，更新 spec 并提交一次。

## Files

- `src/cdp.psm1`
- `src/cdp.sh`
- `tests/cdp.Tests.ps1`
- `tests/cdp.Status.Tests.sh`
- `.github/workflows/test.yml`
- `cdp.psd1`、`CHANGELOG.md`、`README.md`、`README_ZH.md`
- relevant Trellis task/spec files

## Validation

- PowerShell 7 and Windows PowerShell 5.1 full Pester.
- Git Bash status regression tests with native jq/git.
- WSL bash/zsh syntax.
- PSScriptAnalyzer Severity Error.
- `git diff --check`.

## Risk Controls

- Git fixtures只使用临时目录与本地 bare remote，不访问网络。
- push 测试不连接真实 remote。
- fix 测试只写 TestDrive/mktemp config。
- 不修改用户配置、不 push、不发布。
