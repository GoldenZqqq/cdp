# v2.0.5 实施计划

1. 增加 PowerShell/shell hook policy helpers、单次授权参数和回归测试。
2. 为 status parser/dispatch 增加 `--dry-run`、`--yes`，实现 ShouldProcess/显式确认并补齐测试。
3. 收紧 launcher token，改造 Windows Terminal 与 tmux argv 启动并补齐注入负向测试。
4. 固定 shell installer release ref，增加 cdp.sh SHA-256 校验和安装器测试。
5. 更新 2.0.5 版本、ReleaseNotes、CHANGELOG、PROGRESS、Scoop 与双语 README。
6. 运行定向测试，再运行 PowerShell 5.1/7、PSScriptAnalyzer、bash/zsh、metadata、语法、JSON/YAML 与 whitespace 全量门禁。
7. 生成并上传独立 Scoop package，写入其真实 SHA-256，完成发布前证据记录；远程发布按仓库 release gate 单独执行。

## Risk / Rollback

- hook 默认行为是有意收紧；若兼容反馈严重，只回退授权 UX，不恢复静默执行。
- launcher 回归重点覆盖路径空格、预设命令、无 launcher 和自定义安全命令。
- 安装器先校验临时文件再替换，失败时保留当前已安装版本。

## Validation Commands

```text
powershell -NoLogo -NoProfile -Command "Import-Module Pester -MinimumVersion 5.5.0 -Force; Invoke-Pester -Path ./tests -CI"
pwsh -NoLogo -NoProfile -Command "Import-Module Pester -MinimumVersion 5.5.0 -Force; Invoke-Pester -Path ./tests -CI"
pwsh -NoLogo -NoProfile -Command "Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error"
bash tests/cdp.Cli.Tests.sh
bash tests/cdp.Status.Tests.sh
bash tests/cdp.Shell.V2.Tests.sh
zsh tests/cdp.Shell.V2.Tests.sh
bash -n src/cdp.sh && zsh -n src/cdp.sh && bash -n install-wsl.sh
pwsh -File scripts/Test-ReleaseMetadata.ps1
git diff --check
```
