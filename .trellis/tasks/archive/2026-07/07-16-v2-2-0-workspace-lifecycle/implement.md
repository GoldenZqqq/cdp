# Workspace 生命周期实施计划

## 1. Contract and parser

- [x] 新增共享 workspace lifecycle fixture 与 PowerShell/shell schema helpers。
- [x] 扩展纯 parser：show/edit/remove/validate/open、layout、clear-open、fix 与冲突。
- [x] 增加 parser/route 测试，保持 `workspace <name>` 兼容。

## 2. Stable references and CRUD

- [x] 新 add 写 `{name,rootPath}`；实现 object/legacy reference resolver。
- [x] 实现 show、edit、remove、validate 与 validate-fix 原子写入。
- [x] 覆盖 rename/delete/name-reuse/ambiguous/missing-path/unknown-field round trip。

## 3. Launch and layout

- [x] 建立统一 launch plan 与 launcher precedence。
- [x] PowerShell WT tabs/split 与 shell tmux windows/split 使用等价 argv。
- [x] per-project open/size、partial failure、dry-run 和 no-process fixture 通过。

## 4. Completion and docs

- [x] PowerShell/bash/zsh 补全 action、workspace、project、launcher、layout。
- [x] README.md/README_ZH.md 同步 CRUD、schema、迁移与示例。
- [x] 更新 persistence/quality specs、CHANGELOG、PROGRESS、ReleaseNotes。
- [x] 重新生成 shell、installer hash、Scoop draft/hash。

## 5. Validation

```bash
/tmp/powershell-7.5.2/pwsh -NoLogo -NoProfile -File scripts/Invoke-PowerShellQualityGate.ps1
bash tests/cdp.Workspace.Lifecycle.Tests.sh
zsh tests/cdp.Workspace.Lifecycle.Tests.sh
bash scripts/Build-ShellScript.sh --check
bash scripts/Test-ScoopPackage.sh
node tests/cdp.Documentation.Tests.mjs
git diff --check
```

固定 Bash 3.2 镜像运行 lifecycle、CLI、safe mutation、shell v2 和 persistence
矩阵。完整门禁通过后提交、归档；仍不单独 push，等待 v2.2.0 统一发布。
