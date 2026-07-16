# CLI 参数解析实施计划

## Order

1. 为已确认失败场景增加纯解析 Pester 测试，固定兼容调用。
2. 重构 PowerShell invocation parser，使其消费 token 并返回结构化结果。
3. 简化 `Invoke-Cdp` 路由，传递 status/workspace/管理命令的 config 与 options。
4. 为 workspace path 和调用增加可选 config 流，不改变布局实现。
5. 修复 bash/zsh workspace option 消费与 status 冲突校验。
6. 增加 shell 定向解析 smoke，后续 shell regression 任务再扩成完整套件。
7. 同步 PowerShell/Bash 头部开发版本到目标 `2.0.4`，ReleaseNotes 在发布任务最终汇总。
8. 运行定向与全量验证，执行 Trellis check，提交一次。

## Files

- `src/cdp.psm1`
- `src/cdp.sh`
- `tests/cdp.Tests.ps1`
- 必要时新增 `tests/fixtures/cli-invocations.json` 和定向 shell 测试入口
- `cdp.psd1`、`tests/cdp.Tests.ps1` 中版本预期（若模块版本进入 2.0.4 开发态）

## Validation

```powershell
pwsh -NoLogo -NoProfile -Command "Import-Module Pester -MinimumVersion 5.5.0 -Force; Invoke-Pester -Path ./tests -CI"
powershell.exe -NoLogo -NoProfile -Command "Import-Module Pester -MinimumVersion 5.5.0 -Force; Invoke-Pester -Path ./tests -CI"
pwsh -NoLogo -NoProfile -Command '$results = Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error; if ($results) { $results; throw "PSScriptAnalyzer found errors." }'
wsl.exe -d Arch -- bash -lc 'cd /mnt/c/Learn/cdp && bash -n ./src/cdp.sh && zsh -n ./src/cdp.sh'
git diff --check
```

## Risk Controls

- 不写真实用户配置；测试全部使用临时路径。
- 不启动 wt/tmux/AI CLI；使用 pure parser 或 dry-run。
- 不在本任务 push 或发布。
- 如果解析修复要求修改 status 数据模型或 workspace schema，停止并转入对应子任务。
