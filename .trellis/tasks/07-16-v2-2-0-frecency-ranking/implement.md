# Frecency 智能排序实施计划

## 1. Contract and fixtures

- [ ] 新增共享 fixed-now fixture，覆盖 pin、频率、衰减、future、invalid、tie-breaker。
- [ ] PowerShell/shell 固化 exact raw identity、整数 score 与 config-index fallback。

## 2. Ranking integration

- [ ] 新增 PowerShell `Frecency.ps1` 并接入 picker/list/multi-match query。
- [ ] 新增 shell `Frecency.sh` 并接入 sorted names/rows 与 multi-match query。
- [ ] 支持 `CDP_FRECENCY` 关闭，损坏/缺失/大 state 安全退回当前顺序。

## 3. Reset lifecycle

- [ ] 实现 `cdp recent reset`、PowerShell ShouldProcess 与 shell dry-run/yes。
- [ ] 保留未知字段，invalid state 拒绝覆盖，empty reset 不写文件。

## 4. Completion, docs, metadata

- [ ] 更新 PowerShell/bash/zsh completion、README 双语、spec、CHANGELOG、PROGRESS、ReleaseNotes、CI。
- [ ] 重新生成 shell，更新 installer SHA 与 deterministic Scoop hash。

## 5. Validation

```bash
/tmp/powershell-7.5.2/pwsh -NoLogo -NoProfile -File scripts/Invoke-PowerShellQualityGate.ps1
bash tests/cdp.Frecency.Tests.sh
zsh tests/cdp.Frecency.Tests.sh
bash scripts/Build-ShellScript.sh --check
bash scripts/Test-ScoopPackage.sh
node tests/cdp.Documentation.Tests.mjs
git diff --check
```

固定 Bash 3.2 镜像运行 frecency、CLI、shell-v2、persistence 与 safe mutation
矩阵。全量门禁通过后提交并归档；不单独 push，等待 v2.2.0 发布。
