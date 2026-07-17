# PowerShell v2 回归测试设计

## Scope

本任务只建立 PowerShell v2 行为回归网。生产模块仅在新增测试证明真实缺陷时做最小修复；模块拆分、hook 信任模型与 shell 测试保持在后续任务。

## Test Boundary

新增 `tests/cdp.PowerShell.V2.Tests.ps1`，按四个行为域组织：

1. status filter/action：结构化状态、tag/dirty 过滤、fix/push 目标与失败输出。
2. workspace：add/list 持久化、路径空格、缺失项目、启动参数。
3. onEnter：env、PowerShell hook、异常隔离。
4. argument completer：子命令、临时配置项目、launcher。

测试通过模块公共入口或 `InModuleScope cdp` 调用内部边界；不复制生产逻辑来构造预期值。

## Isolation Contracts

- 每个配置、仓库、workspace 文件都位于 `$TestDrive`。
- 修改的环境变量在 `finally` 或 `AfterEach` 中恢复。
- 修改当前目录的测试使用 `Push-Location/Pop-Location`。
- Git fixture 只连接本地 bare remote。
- `Start-Process`、`Get-Command wt.exe` 与 launcher 通过 Pester mock，不启动真实进程。
- completion 通过 `$env:CDP_CONFIG` 指向临时 JSON，并显式清模块 config cache。

## Status Data Flow

```text
$TestDrive projects.json + local Git fixtures
  -> Show-CdpProjectStatus / Get-CdpGitProjectInfo
  -> normalized status or action selection
  -> assertions on fields, config mutation, local remote ref, and failure text
```

`--push` 成功场景通过本地 remote ref 是否前移证明目标被执行；无 upstream 仓库不得成为目标。失败场景使用失效的本地 remote URL，禁止网络访问。

## Workspace Data Flow

```text
projects.json + sibling workspaces.json
  -> Invoke-CdpWorkspace add/list/open
  -> persisted JSON or mocked Start-Process
  -> exact workspace/project/launcher/path assertions
```

包含空格的项目路径必须作为单个启动参数传递；缺失项目或路径只输出 warning，不调用启动器。

## Compatibility

- 同一测试集在 Windows PowerShell 5.1 与 PowerShell 7 执行。
- 不依赖 PS7 专属语法或 `$PSNativeCommandUseErrorActionPreference`。
- 不要求本机安装 Windows Terminal 或 AI CLI。

## Rollback

测试以新增文件为主。若生产缺陷修复超出本任务边界，回滚该修复并将发现记录到对应后续任务；测试提交可整体回退而不迁移用户数据。
