# DR DLSS 手动模块

手动切换 DLSS 模型与挡位，保存 OptiScaler 配置，并通过桥接请求热切换。通过 DR 的本地模块管理单独加载。

当前版本 **0.1.5.0**（预发布），适配 **DR 2.2.2.0 / Dalamud API 15**。游戏内验证范围见 [VALIDATION.md](VALIDATION.md)。

[下载 DLL](https://github.com/VintageVelvet/reshade-toolbox/releases/download/dr-dlss-v0.1.5.0/DR.DlssModule.dll) · [发布页](https://github.com/VintageVelvet/reshade-toolbox/releases/tag/dr-dlss-v0.1.5.0) · [SHA256 校验](https://github.com/VintageVelvet/reshade-toolbox/releases/download/dr-dlss-v0.1.5.0/SHA256SUMS.txt)

## 安装与使用

1. 安装并确认 OptiScaler 在游戏中正常加载。热切换需要带本模块桥接接口的版本，普通官方版不保证支持。
2. 准备已有的 `OptiScaler.ini`，通常位于 `ffxiv_dx11.exe` 旁。FF14 和 DR 不会自带此文件；缺失时按 [OptiScaler 安装说明](https://github.com/optiscaler/OptiScaler/wiki/Manual-Installation)，从对应版本安装包取得。
3. 下载 `DR.DlssModule.dll`，在 DR 本地模块管理中添加该 DLL 的完整路径并启用。
4. 运行 `/pdr dlss`，展开“配置文件”，点击“自动定位”。它使用当前游戏进程目录；自定义配置位置需手动填写完整路径。
5. “配置目标”出现有效的配置模型、倍率后，选择模型和挡位，点击“写入并刷新生效”。

| 按钮 | 用途 |
|---|---|
| 写入配置 | 备份并保存 INI，供下次启动读取 |
| 刷新生效 | 对已保存配置请求桥接更新并刷新窗口 |
| 写入并刷新生效 | 保存配置，然后请求桥接更新并刷新窗口 |

成功时显示 `OptiScaler：ok applied；窗口刷新已完成`。刷新可能短暂停顿，结束后恢复原窗口状态；“结果未确认”不能作为热切换成功的依据。

## 模型与挡位

- **游戏默认**：将模型选择交还 FF14，挡位仍单独保存；当前需要重启游戏应用。
- **K**：DLAA / Quality / Balanced 的常用选择。
- **M**：面向 Performance；**L**：面向 4K Ultra Performance。

K 要求 DLSS 文件版本至少 310.2.0，L/M 至少 310.5.0。模块按检测版本过滤选项，版本未知时只提供游戏默认。

挡位：DLAA **1×**、Ultra Quality **1.3×**、Quality **1.5×**、Balanced **1.7×**、Performance **2×**、Ultra Performance **3×**。

“配置渲染分辨率”是按倍率计算的目标尺寸。确认实际倍率时，按 **Insert** 打开 OptiScaler，查看底部的输入与输出尺寸。没有桥接时可保存配置，重启游戏应用。

## 更多说明

| 文档 | 内容 |
|---|---|
| [使用说明](USAGE.md) | 配置路径、读取判断、快捷命令、备份与常见问题 |
| [技术说明](TECHNICAL.md) | 桥接协议、窗口刷新、ReShade 重建、构建与测试 |
| [验证记录](VALIDATION.md) | 游戏内验收范围与版本记录 |
| [来源与许可](PROVENANCE.md) | 来源、许可与分发范围 |

## 持续维护

在 [`dr-dlss-module`](https://github.com/VintageVelvet/reshade-toolbox/tree/dr-dlss-module/Modules/DR-DLSS) 分支按需适配，上游与检查范围见 [UPSTREAM.md](UPSTREAM.md)。自行构建默认产物为 `out/DR.DlssModule.dll`，构建方法见 [技术说明](TECHNICAL.md#构建与隔离验证)。
