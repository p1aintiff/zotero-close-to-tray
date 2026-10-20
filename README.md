# Zotero Close to Tray

适用于 **Windows / Zotero 10.0.x** 的系统托盘插件。点击主窗口右上角 **×** 后，Zotero 隐藏到右下角通知区域，继续在后台运行；点击托盘图标恢复窗口。

## 在线下载安装

**[下载最新版](https://github.com/p1aintiff/zotero-exit/releases/latest)** · **[直接下载 1.0.2 XPI](https://github.com/p1aintiff/zotero-exit/releases/download/v1.0.2/zotero-close-to-tray-1.0.2.xpi)**

1. 从上面的 GitHub Releases 下载 `.xpi` 安装包，无需下载源码或自行构建。
2. 在 Zotero 打开「工具 → 插件」（Tools → Plugins）。
3. 点击齿轮菜单，选择「从文件安装插件」，选择下载的 XPI。
4. 安装后无需重启。通知区域会出现 Zotero 图标；Windows 可能将它放进「显示隐藏的图标」区域。

**从本地版 1.0.1 升级的用户，请先手动安装一次 1.0.2。** 1.0.1 使用占位更新地址，无法自动发现本仓库的新版本。1.0.2 起使用本仓库的在线更新清单，之后可以通过 Zotero 插件管理器检查更新。

## 使用

- 点击主窗口 **×**：隐藏主窗口及其任务栏按钮，后台继续运行。
- 点击托盘图标，或右键选择「显示 Zotero」：恢复主窗口，保留原有最大化状态。
- 托盘右键「退出 Zotero」，或 Zotero「文件 → 退出」：正常退出程序。
- Alt+F4，以及真正调用主窗口关闭的操作，也会缩到托盘。阅读器标签页的 Ctrl+W 仍由 Zotero 处理。
- 独立阅读器窗口和设置对话框保持各自的关闭行为。
- 停用或卸载插件时，会恢复被隐藏的主窗口并移除托盘图标。

## 系统要求

仅支持 Windows 和 Zotero 10.0.x，已在 Zotero 10.0.6 验证。使用 Windows 自带的 Windows PowerShell 5.1 和 .NET Windows Forms，无需管理员权限或额外安装运行库。

插件以隐藏进程运行托盘辅助脚本，每 250 毫秒检查一次恢复/退出信号。辅助进程随 Zotero 退出或插件停用而结束，并清理临时文件。如果 PowerShell 被系统策略阻止或辅助进程退出，会恢复隐藏的窗口，关闭按钮退回普通最小化；托盘尚未就绪时同样只执行普通最小化。

## 开发和发布

在项目根目录运行：

```powershell
node --check bootstrap.js
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

构建生成 `dist/zotero-close-to-tray-1.0.2.xpi`，并同步生成根目录的 `updates.json`，包括版本、Release 下载地址、兼容范围和 XPI 的 SHA-256。构建不需要 npm 或第三方依赖，XPI 包含 `manifest.json`、`bootstrap.js`、`tray.ps1` 和 MIT 许可证。压缩包条目使用固定时间戳以保证重复构建结果一致。

在 `main` 分支修改版本和下载说明，执行构建，检查并提交代码与 `updates.json` 后，创建并推送对应的版本标签，例如：

```sh
git tag v1.0.2
git push origin main
git push origin v1.0.2
```

[GitHub Actions](https://github.com/p1aintiff/zotero-exit/actions) 会验证标签版本、JavaScript 语法、构建结果与更新清单哈希，成功后创建 GitHub Release 并上传 XPI。使用 GitHub 自带的 `GITHUB_TOKEN`，无需额外配置个人令牌。普通代码推送不会创建 Release。

插件更新清单位于 [updates.json](https://raw.githubusercontent.com/p1aintiff/zotero-exit/main/updates.json)，只有已发布且拥有对应安装包的版本才可用于更新。请确认标签发布成功。

## 版本记录

- **1.0.2**：接入 GitHub Releases 和在线更新清单，提供标签自动发布流程及可重复构建。
- **1.0.1**：补齐 Zotero 10 必需的 HTTPS `update_url`，修复 XPI 内脚本读取错误，并保留恢复时的最大化状态。
- **1.0.0**：初始本地版本。

## 验证

已在独立临时 Zotero 10.0.6 配置及空资料库中验证安装、启用、托盘就绪、关闭事件拦截、窗口恢复和停用清理，并通过 Windows 原生 `IsWindowVisible` 确认主窗口隐藏。Windows PowerShell 托盘进程的显示/退出菜单回调、停止信号及临时目录清理也已实际运行验证。

## 参考与许可

原创代码使用 [MIT 许可证](LICENSE)。

- [Zotero 插件开发文档](https://www.zotero.org/support/dev/zotero_7_for_developers)
- [Zotero 10.0.6 插件加载源码](https://github.com/zotero/zotero/blob/10.0.6/chrome/content/zotero/xpcom/plugins.js)
- [Zotero Rule Outline](https://github.com/p1aintiff/zotero-rule-outline)
