# 跨平台路径 profile 实施计划

## 1. Resolver 与契约测试

- [x] 新增共享 `tests/fixtures/path-profiles.json`，覆盖 legacy、四平台映射、
  显式缺失/非法映射和未知字段。
- [x] 新增 PowerShell `Paths.ps1` 与 Pester 测试：检测、override、选择优先级、
  WSL fallback、raw/resolved/source/error。
- [x] 新增 shell `Paths.sh` 与 bash/zsh/Bash 3.2 测试，复用相同 fixture。
- [x] 把新领域加入 PowerShell bootstrap、shell build order 和模块化计数测试。

## 2. Read-only 消费者

- [x] picker、list、query path 搜索改用 resolver/所有 profile 字段。
- [x] PowerShell 与 shell switch 使用 resolved path；PowerShell `-WSL` 使用
  `wsl` profile 并检查 native 结果。
- [x] doctor/health 校验 `paths` schema 并用 resolved path 检查当前环境。
- [x] recent 展示尽可能从当前配置解析；持久化 identity 仍为 raw rootPath。

## 3. Status 与 workspace

- [x] normalized status 增加 resolved/profile/source/error 信息；Git/cache/push
  使用 resolved path。
- [x] JSON 增加 `path_profile_invalid` 状态/原因回归，并验证 raw/resolved。
- [x] status fix 跳过显式 profile missing，旧 fallback missing 保持兼容。
- [x] PowerShell WT/launcher 与 shell tmux/workspace 计划统一使用 resolver。

## 4. Mutation 写入与 repair

- [x] Add-Project/cdp-add 新项目写 `rootPath` + `paths.<current>`。
- [x] PowerShell/shell scan 写相同 shape；init 通过 scan 获得一致行为。
- [x] repair 对 legacy missing 保持禁用，对 explicit missing 保留并报告，invalid
  profile 无写入失败。
- [x] 增加无损 round-trip 测试，证明 `paths` 和未知字段在 metadata、repair、
  status fix 中保留。

## 5. 文档、规范和版本元数据

- [x] README.md 先写英文配置示例、优先级、override、迁移/降级和安全 fix 说明。
- [x] README_ZH.md 同步等价结构与信息。
- [x] 更新 backend database/quality specs，固化 path profile 契约。
- [x] 更新 CHANGELOG.md、PROGRESS.md、`cdp.psd1` ReleaseNotes；版本保持
  开发线 `2.2.0`。
- [x] 重新生成 `src/cdp.sh`、Scoop draft 与 hash，并运行 release metadata 检查。

## 6. 验证顺序

定向验证：

```bash
/tmp/powershell-7.5.2/pwsh -NoLogo -NoProfile -Command \
  "Import-Module Pester -MinimumVersion 5.5.0 -Force; Invoke-Pester -Path ./tests/cdp.PathProfiles.Tests.ps1 -CI"
bash tests/cdp.PathProfiles.Tests.sh
zsh tests/cdp.PathProfiles.Tests.sh
bash scripts/Build-ShellScript.sh --check
```

完整门禁：

```bash
/tmp/powershell-7.5.2/pwsh -NoLogo -NoProfile -File scripts/Invoke-PowerShellQualityGate.ps1
bash scripts/Invoke-ShellQualityGate.sh
bash scripts/Build-ShellScript.sh --check
/tmp/powershell-7.5.2/pwsh -NoLogo -NoProfile -File scripts/Test-ReleaseMetadata.ps1
bash scripts/Test-ScoopPackage.sh
git diff --check
python ./.trellis/scripts/task.py validate .trellis/tasks/07-16-v2-2-0-path-profiles
```

Bash 3.2 固定镜像继续使用：

```bash
docker run --rm -v "$PWD:/work" -w /work \
  bash@sha256:3a13e5da38baa575985778cd09ce8ac736d4b4dafc91a430e71271f6e5311b89 \
  bash tests/cdp.PathProfiles.Tests.sh
```

## 7. Review / rollback points

- Resolver pure tests 未通过前不接入 mutation。
- status JSON raw/resolved 或 exit code 回归时先回滚 status 投影，不改变 schema
  version。
- 任一 mutation 无损测试失败时停止，不运行 repair/status fix 写入测试以外的
  配置。
- 完整门禁通过后再提交并归档；不单独 push，等待 v2.2.0 全部子任务统一发布。
