# P2: 项目环境自动激活 (onEnter hook)

## Goal

当用户通过 cdp 切换到某个项目时，自动执行预设的命令——激活虚拟环境、切换 Node 版本、设置环境变量等。类似 direnv 的功能，但与 cdp 的项目配置集成。

## User Stories

1. Python 开发者希望 `cdp ml-project` 后自动 `source .venv/bin/activate`
2. Node 开发者希望切换项目后自动 `nvm use`
3. 团队希望进入项目后自动设置 `DATABASE_URL` 等环境变量

## Requirements

### 配置方式

在 projects.json 的项目条目中添加 `onEnter` 字段：

```json
{
  "name": "ml-pipeline",
  "rootPath": "E:/Projects/ml",
  "enabled": true,
  "onEnter": ".venv/Scripts/Activate.ps1"
}
```

或更复杂的形式：

```json
{
  "name": "web-app",
  "rootPath": "E:/Projects/web",
  "enabled": true,
  "onEnter": {
    "powershell": ".venv/Scripts/Activate.ps1",
    "bash": "source .venv/bin/activate",
    "env": {
      "NODE_ENV": "development"
    }
  }
}
```

### 行为

- cdp 切换到项目目录后，检查 `onEnter` 字段
- 字符串形式：直接在当前 shell 中执行（相对路径基于 rootPath）
- 对象形式：根据当前 shell 选择 `powershell` 或 `bash` 脚本，并设置 `env` 中的环境变量
- 执行失败时显示警告但不阻塞切换
- `cdp doctor` 检查 onEnter 脚本是否存在

### 安全

- 只执行用户在自己配置文件中定义的命令
- 不自动执行项目目录中的任意文件（区别于 direnv 的 .envrc）
- 首次遇到 onEnter 时显示即将执行的命令并请求确认（可选）

## Acceptance Criteria

- [ ] 字符串形式 `onEnter` 在 PowerShell 中正常执行
- [ ] 字符串形式 `onEnter` 在 bash/zsh 中正常执行
- [ ] 对象形式按 shell 类型选择正确脚本
- [ ] `env` 中的环境变量被正确设置
- [ ] 脚本不存在时显示警告不崩溃
- [ ] `cdp doctor` 检查 onEnter 脚本存在性
- [ ] 添加测试覆盖
