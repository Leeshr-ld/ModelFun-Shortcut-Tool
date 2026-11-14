# ModelFun Shortcut Tool / 模方面板快捷键助手

[![CI](https://github.com/Leeshr-ld/ModelFun-Shortcut-Tool/actions/workflows/ci.yml/badge.svg)](https://github.com/Leeshr-ld/ModelFun-Shortcut-Tool/actions/workflows/ci.yml)

一款面向 **ModelFun / 模方ModelFun** 的 Windows 快捷键与自动化工具。程序会自动识别当前置平面板，并为常用按钮提供可自定义的键盘、鼠标快捷键。

> 当前版本：`V1.2.0`
>
> 作者：`shijye`
>
> 许可证：[GNU GPL v3.0](LICENSE)

## 功能

- 自动识别道路置平、表面置平、指定置平和补洞面板。
- 支持键盘组合键和鼠标侧键映射。
- 快捷键可视化编辑、内部重复检测和模方原版快捷键冲突提示。
- 一键恢复全部默认快捷键。
- 通用备份流程：打开备份窗口 → 全选 → 立即备份。
- 模拟点击完成后恢复鼠标原位置。
- 自动适配Windows DPI和窗口尺寸，减少文字遮挡。
- 使用PerMonitorV2 DPI感知，并为100%–250%缩放、1080p/1440p/4K和超宽屏提供自适应布局规则。
- 软件内“关于”窗口包含版本历史、作者和许可证说明。

## 支持的模方面板

| 面板 | 自动识别 | 支持按钮 |
|---|---|---|
| 道路置平 | 是 | 操作、撤销、重做、确认、取消 |
| 表面置平 | 是 | 操作、应用、撤销、重做、确认、取消 |
| 指定置平 | 是 | 操作、曲线、应用、更多、撤销、重做、选项、确定、取消 |
| 补洞 | 是 | 四种填充方式、两种编辑方式、撤销、重做、确认、取消 |

## 默认快捷键

| 动作 | 快捷键 |
|---|---|
| 通用备份 | `Ctrl+Alt+B` |
| 位置按钮1~8 | `Ctrl+Alt+1~8` |
| 选项切换 | `Ctrl+Alt+H` / `Ctrl+Alt+O` |
| 撤销 / 重做 | `Ctrl+Alt+Z` / `Ctrl+Alt+R` |
| 确认 / 取消 | `Ctrl+Alt+Enter` / `Ctrl+Alt+X` |

快捷键可在软件内修改，也可通过 [config.default.json](config.default.json) 查看默认配置。

四个面板的快捷键分别保存、互不干扰。同一组合键可以在不同面板中分别使用；同一面板内部仍禁止重复。全局备份快捷键独立保存，并且不能与任何面板按钮重复。

## 安装与运行

1. 从[Releases](../../releases/latest)下载便携ZIP。
2. 解压到任意目录。
3. 打开ModelFun并显示受支持的置平面板。
4. 双击`RoadLevelHotkeys.exe`，在UAC提示中点击“是”。
5. 回到ModelFun使用快捷键。

程序需要管理员权限，因为ModelFun通常以管理员权限运行，Windows会阻止低权限进程向高权限窗口注入鼠标点击。

## 系统要求

- Windows 10 / 11
- Windows 10 / 11 内置的 Windows PowerShell 5.1（默认，完整支持PerMonitorV2）
- PowerShell 7仅作为Windows PowerShell 5.1不可用时的备用启动环境
- 运行和打包不需要第三方PowerShell模块

## 从源码运行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\RoadLevelHotkeys.ps1
```

第一次运行会在同目录生成个人配置文件`config.json`。

## 构建便携包

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\打包便携版.ps1
```

脚本会读取`version.json`，只打包运行文件，并生成ZIP和SHA256文件。详细说明见[打包说明.md](打包说明.md)。

## 测试

```powershell
pwsh -NoProfile -File .\tests\Test-ShortcutRules.ps1
pwsh -NoProfile -File .\tests\Test-PanelBindings.ps1
pwsh -NoProfile -File .\tests\Test-BackupWorkflow.ps1
pwsh -NoProfile -File .\tests\Test-VersionInfo.ps1
pwsh -NoProfile -File .\tests\Test-LayoutPolicy.ps1
powershell -NoProfile -File .\tests\Test-DpiAwareness.ps1
powershell -NoProfile -File .\tests\Test-UiStartup.ps1
pwsh -NoProfile -File .\tests\Test-ReleasePackage.ps1
```

鼠标点击与光标恢复测试涉及真实桌面输入：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-MouseClick.ps1
```

## 项目结构

```text
RoadLevelHotkeys.ps1   主程序与界面
DpiSupport.ps1         进程级PerMonitorV2 DPI初始化
ShortcutRules.ps1      快捷键规则、冲突检测和默认设置
MouseAutomation.ps1    快速鼠标点击与位置恢复
BackupWorkflow.ps1     通用备份流程
LayoutPolicy.ps1       响应式界面布局
VersionInfo.ps1        版本与关于窗口文本
version.json           版本、作者、许可证和更新历史
tests/                 自动化测试
```

## 数据安全

本工具会执行真实鼠标点击，包括“全选”和“立即备份”。首次使用或升级软件后，请先在工程副本上验证完整备份流程，并始终保留独立备份。

本项目与DASPATIAL、ModelFun官方无隶属或授权关系。ModelFun是第三方软件，其界面结构变化可能导致坐标识别失效。

## 许可证

本项目采用[GNU General Public License v3.0](LICENSE)。

你可以运行、研究、修改、再分发本软件，也可以用于商业用途。分发修改版时必须遵守GPL-3.0，提供完整对应源码，并保留许可证与作者署名。
