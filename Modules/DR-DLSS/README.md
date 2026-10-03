# DR DLSS 手动模块

维护分支：[`dr-dlss-module`](https://github.com/VintageVelvet/reshade-toolbox/tree/dr-dlss-module/Modules/DR-DLSS)。当前候选版 `0.1.1.0` 面向 DR `2.2.2.0` / Dalamud API 15，以用户实际安装的依赖构建。

## 功能

- DLSS Render Preset A–O（1–15）和六个默认挡位。
- **写入配置**：备份并保存 OptiScaler.ini，供下次启动读取；启用桥接时也会发送运行时应用请求。
- **刷新生效**：执行窗口刷新，不写入模型或挡位。
- **写入并刷新生效**：成功保存配置后执行刷新；桥接不可用也继续刷新。
- 高级刷新参数保留旧默认值：窗口模式 1、无边框模式 2、等待 800 毫秒、临时窗口比例 0.95、调整窗口尺寸和 SwapChain 请求开启。
- 桥接和桥接检测保留，首版迁移时默认关闭。只有手动开启后，写入操作才请求桥接。
- 自定义缩放比例、自动切换及其命令已移除。

| 挡位 | 比例 | 命令 |
|---|---:|---|
| DLAA | 1.0 | `dlaa` |
| Ultra Quality | 1.3 | `uq` |
| Quality | 1.5 | `quality` |
| Balanced | 1.7 | `balanced` |
| Performance | 2.0 | `performance` |
| Ultra Performance | 3.0 | `up` |

Preset 列表沿用原模块，不代表每个模型值均经过当前 DLSS DLL 实测。配置中的未知模型值或非默认比例会显示出来，写入前需要选择支持的值。

## 预设选择提示

下拉选项包含简短用途标签，悬停可查看解释；选择后，选项下方显示说明和与当前挡位的搭配提示。选择仍只改变待写入设置，由用户点击手动按钮应用。

| 预设 | 提示 |
|---|---|
| K | DLAA / Quality / Balanced 的常用起点；RTX 20/30 系列可优先考虑 |
| M | 面向 Performance（比例 2.0），需要支持 DLSS 4.5 的文件版本 |
| L | 面向 4K Ultra Performance（比例 3.0），计算开销较高 |
| J | 与 K 对照；可能略少拖影，但更容易闪烁，通常优先 K |
| A–F | 旧版兼容或弃用预设，保留选项并标明状态 |
| G / H / I / N / O | 官方标记为回退默认行为，不推荐手动选择 |

建议依据 [NVIDIA 官方 DLSS 4.5 说明](https://www.nvidia.com/en-us/geforce/news/dlss-4-5-dynamic-multi-frame-gen-6x-2nd-gen-transformer-super-res/)、[SDK v310.5.3 预设定义](https://github.com/NVIDIA/DLSS/blob/v310.5.3/include/nvsdk_ngx_defs.h)和[当前 Streamline 定义](https://github.com/NVIDIA-RTX/Streamline/blob/main/include/sl_dlss.h)。L/M 从 [310.5.0 SDK](https://github.com/NVIDIA/DLSS/releases/tag/v310.5.0)加入。310.5.3 SDK 已移除 A–E，F 标记弃用；当前新版 SDK 重新列出 E，但仍标弃用。头文件移除并不证明实际 DLL 必然拒绝历史数值。

界面显示配置文件所在目录中 nvngx_dlss.dll 的文件版本；这不等同于验证游戏实际加载或驱动覆盖后的模型。字母顺序不代表画质等级，推荐方向仍需结合游戏画面和帧率比较。

## 使用本地构建

1. 构建产物为 `out/DR.DlssModule.dll`，不要用它覆盖 DR 官方的 DailyRoutines.ModulesPublic.dll。
2. 在 DR 本地模块管理中停用并移除旧的自定义 DLL 条目，再添加新 DLL 的路径。保留旧文件用于回退。两份自定义模块使用同一模块类名，不能同时启用。
3. 打开“DLSS档位调节”或运行 `/pdr dlss`。配置文件路径沿用现有配置；确认它指向正在使用的游戏目录。
4. 选择模型和挡位，然后使用“写入并刷新生效”。状态分别显示文件保存结果和窗口刷新结果。
5. 下次启动游戏后检查配置及实际画面。游戏内即时生效和重启后生效需要实际验证。

回退时停用新模块，重新添加旧 DLL 条目。每次写入的原始 INI 备份放在配置文件旁边，名称为 `OptiScaler.ini.drbackup-*`；需要回退配置时，在游戏关闭后恢复对应备份。

## 快捷命令

- `/pdr dlss`：打开界面。
- `/pdr dlss quality` 等六个挡位名：选择、写入并刷新。
- `/pdr dlss set quality`：相同操作，保留旧用法。
- `/pdr dlss select quality`：只选择挡位，尚未写入。
- `/pdr dlss preset K` 或 `preset 11`：选择模型、写入并刷新。
- `/pdr dlss apply`：写入配置。
- `/pdr dlss refresh`：只刷新画面。
- `/pdr optidlss`：旧命令别名。

## 刷新和桥接

窗口刷新临时切换模式和窗口尺寸，尝试触发画面重建；本版最后恢复实际原窗口模式、位置和最大化状态。所有游戏配置及窗口操作在框架更新线程执行，取消或失败时也尝试恢复。窗口最小化、无法读取原状态或参数无效时不开始刷新。

桥接通过消息模式命名管道 `OptiScalerDlssBridge` 发送 `set ratio <比例> preset <模型> save 1`。`ok applied` 表示桥接接受配置并请求切换，不能代替画面验证。桥接使用异步连接及收发，总请求有统一超时，不同步阻塞游戏更新。它使用定制 OptiScaler 的 INI 保存机制，可能重新序列化配置；模块自己的五键写入保留无关内容及原始换行。桥接关闭时不会发出请求。

## 构建与验证

```powershell
./Build.ps1
./tests/Test-Ini.ps1
./tests/Test-Bridge.ps1
```

Build.ps1 使用 PowerShell 7 自带的 Roslyn 编译器；宿主需基于 .NET 10。默认从当前用户的 XIVLauncherCN 安装中找到最高版本 DR、最近的正式 Hooks 目录和 .NET 10 运行时。也可以传入 `-LauncherRoot`、`-PluginDirectory`、`-HookDirectory` 和 `-OutputDirectory`。源码、依赖哈希及输出哈希记录在 `out/build-info.json`。构建只读取依赖元数据，不执行目标插件。

INI 测试只操作临时副本；桥接测试使用随机测试管道。测试不会操作游戏窗口或游戏管道。配置替换前检查已观察到的外部改动；检查与实际替换之间仍存在很短的竞争窗口。

## 持续维护

由用户通知上游更新后按需维护，不设置定时任务。源码、构建脚本、行为测试与维护记录保存在专用远程分支；候选 DLL 在本地构建，构建产物和含本机路径的构建信息不提交到 Git。

更新来源及影响判断见 [UPSTREAM.md](UPSTREAM.md)。验证状态见 [VALIDATION.md](VALIDATION.md)。来源说明见 [PROVENANCE.md](PROVENANCE.md)。编译、文件写入检查与游戏内验证分开记录。
