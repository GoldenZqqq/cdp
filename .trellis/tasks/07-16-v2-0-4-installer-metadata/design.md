# 安装器与发布元数据一致性设计

## Scope

本任务只修复 Windows PowerShell 安装目录、精确安装验证、Scoop 安装入口和仓库内版本镜像校验。`cdp.psd1` 是 canonical version，其他文件是必须由验证器约束的镜像。

## Installation Path Contract

| Scope | PSEdition | Required discoverable root |
| --- | --- | --- |
| CurrentUser | Core | `<Documents>/PowerShell/Modules` |
| CurrentUser | Desktop | `<Documents>/WindowsPowerShell/Modules` |
| AllUsers | Core | `<ProgramFiles>/PowerShell/Modules` |
| AllUsers | Desktop | `<ProgramFiles>/WindowsPowerShell/Modules` |

`Resolve-CdpModuleInstallPath` 构造 edition/scope 对应 root，并要求规范化后的 root 出现在传入的 `PSModulePath` 中。正常安装使用真实环境；测试注入隔离的 Documents、ProgramFiles 和 search path。

## Shared Installation Functions

```powershell
Resolve-CdpModuleInstallPath `
    -Scope <CurrentUser|AllUsers> `
    -Edition <Core|Desktop> `
    -ModuleName cdp `
    -ModuleSearchPath <string> `
    -DocumentsPath <path> `
    -ProgramFilesPath <path>

Select-CdpInstalledModule `
    -AvailableModules <object[]> `
    -ModulePath <path> `
    -ExpectedVersion <version>
```

第二个函数只接受 `ModuleBase` 精确等于本次目标且 version 相等的 candidate。旧路径中的高/低版本均不能证明本次安装成功。

## Installer Flow

1. 校验 AllUsers administrator requirement。
2. dot-source 共用 installation functions，并解析目标路径。
3. 默认保留 overwrite prompt；`-Force` 跳过 prompt。
4. 复制 manifest 与 `src/`。
5. `Test-ModuleManifest` 校验目标 manifest，并从 `Get-Module -ListAvailable -Refresh` 结果中精确选择目标 module。
6. 默认检查/安装 fzf；`-SkipFzf` 跳过该阶段。

Scoop 依赖 `fzf`，installer script 只调用 `& "$dir\Install.ps1" -Scope CurrentUser -Force -SkipFzf`。uninstaller 继续清理两个历史 CurrentUser 目录，兼容旧安装。

## Metadata Validation

`scripts/Test-ReleaseMetadata.ps1` 从 `cdp.psd1` 读取 canonical version，并检查：

- manifest `ReleaseNotes` 首项；
- `src/cdp.psm1` header；
- `src/cdp.sh` header 与 `CDP_VERSION`；
- `tests/cdp.Tests.ps1` manifest/about version expectations；
- Scoop `version`、tag URL、`extract_dir` 与 autoupdate templates；
- `CHANGELOG.md` 首个 release heading；
- `PROGRESS.md` 的 `Current release target`。

验证器汇总所有 mismatch 后抛错，独立进程因此非零退出。它不接受、读取或输出任何 API key。

## Testing and CI

- `tests/cdp.Install.Tests.ps1` 使用 `$TestDrive`/构造 module candidates 覆盖四格 path matrix、search path missing、旧 module 误判与 metadata negative case。
- negative case 在当前 PowerShell executable 的独立进程中运行，断言 exit code 非零。
- Windows PowerShell 5.1 与 PowerShell 7 CI job 在 Pester 后直接运行 metadata validator。
- 既有 PowerShell/Shell 全量门禁保持不变。

## Compatibility and Rollback

- 新脚本只使用 PowerShell 5.1 语法与 API。
- 默认 `Install.ps1` 交互和 fzf 安装行为保持；新增参数仅提供自动化路径。
- 单一工作提交可回退所有安装/metadata 变更；不迁移用户配置，不执行远程发布。
