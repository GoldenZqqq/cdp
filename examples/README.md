# 配置文件示例 / Configuration Examples

本目录包含 cdp 自定义配置文件的示例。

## 文件说明

### projects.json

标准的项目配置文件示例，展示了如何配置多个项目。

**字段说明：**

```json
{
  "name": "项目显示名称",        // 必需：在 fzf 菜单中显示的项目名
  "rootPath": "项目路径",        // 必需：项目根目录的绝对路径
  "enabled": true/false          // 必需：是否启用该项目
}
```

## 使用方法

### 方法 1: 直接使用示例文件

```powershell
# 复制示例文件
Copy-Item examples\projects.json C:\my-projects.json

# 编辑配置文件
notepad C:\my-projects.json

# 使用配置文件
Switch-Project -ConfigPath "C:\my-projects.json"
```

### 方法 2: 基于示例创建自己的配置

```powershell
# 读取示例内容
$example = Get-Content examples\projects.json -Raw

# 修改后保存到自定义位置
$example | Out-File "C:\my-projects.json" -Encoding UTF8

# 设置环境变量（推荐）
$env:CDP_CONFIG = "C:\my-projects.json"
```

### 方法 3: 添加到 PowerShell 配置

```powershell
# 编辑 PowerShell 配置文件
notepad $PROFILE

# 添加以下内容：
$env:CDP_CONFIG = "C:\my-projects.json"
```

## 路径格式说明

### Windows 路径

在 JSON 文件中，Windows 路径的反斜杠 `\` 需要转义为 `\\`：

```json
{
  "name": "示例项目",
  "rootPath": "C:\\Projects\\MyProject",  ✅ 正确
  "enabled": true
}
```

**常见错误：**

```json
{
  "name": "示例项目",
  "rootPath": "C:\Projects\MyProject",   ❌ 错误：反斜杠未转义
  "enabled": true
}
```

### 使用正斜杠（推荐）

也可以使用正斜杠 `/`，PowerShell 会自动处理：

```json
{
  "name": "示例项目",
  "rootPath": "C:/Projects/MyProject",   ✅ 推荐：无需转义
  "enabled": true
}
```

## 完整示例

```json
[
  {
    "name": "工作项目",
    "rootPath": "D:/Work/MainProject",
    "enabled": true
  },
  {
    "name": "个人项目",
    "rootPath": "E:/Personal/SideProject",
    "enabled": true
  },
  {
    "name": "已归档项目",
    "rootPath": "F:/Archive/OldProject",
    "enabled": false
  }
]
```

## 提示

1. **使用正斜杠**：避免反斜杠转义的麻烦
2. **启用/禁用**：使用 `enabled: false` 临时禁用项目，而不是删除
3. **路径验证**：确保路径存在，否则切换时会报错
4. **中文支持**：项目名称支持中文和 Unicode 字符
5. **环境变量**：推荐使用 `CDP_CONFIG` 环境变量设置默认配置路径

## 自动生成配置文件

### 从当前目录列表生成

```powershell
# 列出某个目录下的所有子目录作为项目
$baseDir = "E:\Projects"
$projects = Get-ChildItem $baseDir -Directory | ForEach-Object {
    @{
        name = $_.Name
        rootPath = $_.FullName -replace '\\', '\\'
        enabled = $true
    }
}

# 转换为 JSON 并保存
$projects | ConvertTo-Json | Out-File "C:\my-projects.json" -Encoding UTF8
```

### 从 Git 仓库列表生成

```powershell
# 找出所有包含 .git 的目录
$baseDir = "E:\Projects"
$gitProjects = Get-ChildItem $baseDir -Directory -Recurse -Depth 1 |
    Where-Object { Test-Path (Join-Path $_.FullName ".git") } |
    ForEach-Object {
        @{
            name = $_.Name
            rootPath = $_.FullName -replace '\\', '\\'
            enabled = $true
        }
    }

$gitProjects | ConvertTo-Json | Out-File "C:\my-git-projects.json" -Encoding UTF8
```

## 故障排除

### JSON 格式错误

使用在线 JSON 验证器检查格式：
- https://jsonlint.com/
- 或使用 PowerShell 验证：

```powershell
# 验证 JSON 格式
try {
    Get-Content "C:\my-projects.json" -Raw | ConvertFrom-Json
    Write-Host "✅ JSON 格式正确" -ForegroundColor Green
} catch {
    Write-Host "❌ JSON 格式错误" -ForegroundColor Red
    Write-Host $_.Exception.Message
}
```

### 路径不存在

检查路径是否正确：

```powershell
# 检查所有项目路径
$config = Get-Content "C:\my-projects.json" -Raw | ConvertFrom-Json
foreach ($project in $config) {
    if (Test-Path $project.rootPath) {
        Write-Host "✅ $($project.name): $($project.rootPath)" -ForegroundColor Green
    } else {
        Write-Host "❌ $($project.name): 路径不存在" -ForegroundColor Red
    }
}
```
