# P0: macOS 原生支持

## Goal

让 cdp 在 macOS 上开箱即用，扩大用户群覆盖。阮一峰周刊读者中 macOS 用户比例很高，没有 macOS 支持直接砍掉一大半潜在用户。

## Background

现有 `src/cdp.sh` 理论上是 bash/zsh 通用的，但从未在 macOS 上测试过。macOS 有以下差异需要处理：
- 默认 shell 是 zsh（不是 bash）
- 没有 GNU coreutils（`readlink -f` 不可用，需要 `greadlink` 或纯 shell 方案）
- 安装 fzf/jq 走 Homebrew（`brew install fzf jq`）
- `sed` 是 BSD 版本，语法可能有差异
- `date` 命令参数不同

## Requirements

### 兼容性修复

- 审计 `src/cdp.sh` 中所有 GNU-only 用法，替换为 POSIX 或 macOS 兼容写法
- `readlink -f` → 纯 shell 实现或检测 `greadlink`
- BSD `sed` 兼容
- BSD `date` 兼容
- 确保 zsh 下 `source` 正常工作

### 安装脚本

- 更新 `install-wsl.sh`（或创建 `install-macos.sh`）支持 Homebrew 安装 fzf 和 jq
- 提供 Homebrew 一键安装方案：
  ```bash
  brew install fzf jq
  curl -sL https://raw.githubusercontent.com/GoldenZqqq/cdp/main/install-wsl.sh | bash
  ```

### 文档

- README.md 和 README_EN.md 添加 macOS 安装指南
- macOS 截图/GIF（如果有 macOS 环境）

### CI

- GitHub Actions 添加 macOS runner（`runs-on: macos-latest`）
- macOS 上跑 `bash -n src/cdp.sh` + smoke test

## Acceptance Criteria

- [ ] `src/cdp.sh` 在 macOS Ventura/Sonoma 的 zsh 下正常工作
- [ ] `cdp`、`cdp <query>`、`cdp doctor`、`cdp-scan`、`cdp-ls` 全部正常
- [ ] fzf/jq 安装引导使用 Homebrew
- [ ] GitHub Actions CI 包含 macOS 测试
- [ ] 双语 README 包含 macOS 安装说明
- [ ] 无 GNU coreutils 依赖（或自动降级）
