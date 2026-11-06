# OpenCode Offline：Windows ARM64 适配

基于社区分支 [Chetic/opencode-offline](https://github.com/Chetic/opencode-offline) 的源码补丁和构建方法，用于 Windows 11 ARM64 原生终端及本地 Web 界面。固定上游提交：`bcdbd58d57c1c38b13b3f9a3d8b423786f0e1d85`。

本仓库包含 Windows ARM64 构建、离线 fetch 防护、浏览器 CSP 和每次文件操作重新确认的适配。个人模型列表、个人启动配置、聊天、日志、模型权重、SDK 和二进制不在源码包中。

## 已验证范围

实际原生 TTY 渲染和退出、本地后端/config/MCP、打包 Web 界面、已有文件读取，以及经确认的修改和新建均已通过。选择 Always 后按 Once 处理，下一次操作再次询问，拒绝新建不会创建文件。测试期间未观察到外部代理请求。具体条件、测试模型与限制以 [VERIFICATION.md](VERIFICATION.md) 为准；这不保证所有本地模型都可靠使用工具。

运行环境采用 **Bun 1.4.4 ARM64**。旧 Bun 1.3.10 虽能编译，却在原生 TTY 的 FFI/TinyCC 初始化阶段失败，不推荐用于此构建。

## 构建

准备 Windows 11 ARM64、Git、PowerShell 5.1 或更新版本、足够的磁盘空间，以及构建阶段的网络访问。使用原生 ARM64 Git 可避免工具本身依赖模拟。此流程不需要 WSL、Prism 或 NVIDIA 驱动，也不会下载模型。运行所选本地模型所需的后端及驱动由使用者另行准备。

在仓库根目录选择一个**新的或空的本地工作目录**：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-WindowsArm64.ps1 -WorkDirectory (Join-Path $env:TEMP 'opencode-arm64-build') -PlanOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-WindowsArm64.ps1 -WorkDirectory (Join-Path $env:TEMP 'opencode-arm64-build')
```

示例的执行策略只对新启动的 PowerShell 进程生效，不修改系统策略。脚本克隆固定提交、校验并应用补丁、下载并验证官方 Bun 压缩包，然后执行 frozen-lockfile 安装及当前平台 CLI/Web 构建。已有目录不为空时直接停止，不清理或覆盖已有安装；失败后可保留现场，换新目录重试。构建依赖仍需下载，**构建过程不是离线安装器**。

输出：

- `source/packages/opencode/dist/opencode-windows-arm64/bin/opencode.exe`
- `source/packages/app/dist/`
- `build-receipt.json`

只调用上游 CLI 的 `--single --skip-install` 和 Web build，绕过其硬编码 Linux x64 的离线打包脚本。构建使用本地空模型目录，不获取 models.dev；固定版本/渠道并清空发布开关，不自动发布。官方 [Bun 压缩包](https://github.com/oven-sh/bun/releases/download/bun-v1.4.4/bun-windows-aarch64.zip) SHA256：`2d57a0eec0cb44d95c918c3f9734f60455a1306ae5085d76fc68f44e3ee30d09`。

## 本地配置

[配置示例](templates/opencode.example.json) 只有 `local-model` 占位符。将模型名和 API 地址改为自己已安装的本地模型；默认示例端点为 `http://127.0.0.1:11434/v1`，也可通过环境变量指定。它不会安装模型、启动 Ollama 或复用个人配置。

[环境模板](templates/OfflineEnvironment.example.ps1) 展示独立状态目录和离线开关。自行准备所需的本地 MCP、原生 ripgrep，以及本地 Web 资源目录；构建成功与完整运行部署是不同的验收步骤。源码包不附个人 MCP 配置。

离线防护限制 JavaScript fetch 到字面回环 HTTP(S) 地址，并拒绝外部重定向；Web CSP 限制浏览器资源/连接。它**不是操作系统网络沙箱**，不拦截任意原始套接字或用户自行启动的子进程。选定的后端、MCP 和构建依赖仍应可信。

## 来源与许可

保留上游 [MIT LICENSE](LICENSE) 和 `Copyright (c) 2025 opencode`。社区分支来自 Chetic，原项目为 [OpenCode](https://github.com/anomalyco/opencode)。源码中的其他许可证继续适用；根 MIT 不代替第三方依赖或字体的许可。当前仅分享源码适配，不发布二进制 release。
