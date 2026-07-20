# 多仓库 exec 实施计划

## 1. Contract and parser

- [x] 扩展 normalized invocation 与纯 parser，强制 `--` 边界并隔离 command argv。
- [x] 实现互斥 selector、jobs/timeout/fail policy/JSON/safety 校验和 route 测试。
- [x] 固化 JSON schema、status 与退出码 fixture。

## 2. Selection and plan

- [x] PowerShell/shell 实现 explicit/tag/workspace/all 选择与 deterministic de-dup。
- [x] 复用 workspace stable refs 与 path profile resolver，覆盖 renamed/deleted/invalid path。
- [x] 完整 plan 在确认/执行前生成；empty/unknown selector fatal，无进程。

## 3. Execution and output

- [x] PowerShell bounded runspace worker 使用 executable + argv、独立 cwd/stdout/stderr/timeout。
- [x] shell Bash 3.2-compatible batch worker 与 portable watchdog，无 eval/拼接。
- [x] continue/fail-fast、partial failure、timeout/canceled 和 deterministic human/JSON 汇总通过。

## 4. Completion, docs, metadata

- [x] PowerShell/bash/zsh 补全 exec selectors/options/project/workspace/tag。
- [x] README.md/README_ZH.md、spec、CHANGELOG、PROGRESS、ReleaseNotes 和 CI 同步。
- [x] 重新生成 shell，更新 installer SHA 与 deterministic Scoop hash。

## 5. Validation

```bash
/tmp/powershell-7.5.2/pwsh -NoLogo -NoProfile -File scripts/Invoke-PowerShellQualityGate.ps1
bash tests/cdp.Exec.Tests.sh
zsh tests/cdp.Exec.Tests.sh
bash scripts/Build-ShellScript.sh --check
bash scripts/Test-ScoopPackage.sh
node tests/cdp.Documentation.Tests.mjs
git diff --check
```

固定 Bash 3.2 image 运行 exec、CLI、path、workspace、safe mutation、shell-v2 与
persistence 矩阵。完整门禁通过后提交并归档；不单独 push，等待 v2.2.0 发布。
