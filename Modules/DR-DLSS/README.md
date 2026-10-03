# DR DLSS 手动模块

维护分支：[`dr-dlss-module`](https://github.com/VintageVelvet/reshade-toolbox/tree/dr-dlss-module/Modules/DR-DLSS)。当前候选版 `0.1.2.0` 面向 DR `2.2.2.0` / Dalamud API 15。

这里的“本地模块”指 DR 的模块加载类别：模块通过 DR 的本地模块管理单独加载，尚未收录进 DR 官方模块包，不随 DR 版本一起发布。本模块的源码和 DLL 在本仓库独立维护与交付。

## 下载 DLL

[直接下载 DR.DlssModule.dll](https://github.com/VintageVelvet/reshade-toolbox/releases/download/dr-dlss-v0.1.2.0/DR.DlssModule.dll) · [版本发布页与安装说明](https://github.com/VintageVelvet/reshade-toolbox/releases/tag/dr-dlss-v0.1.2.0) · [SHA256 校验文件](https://github.com/VintageVelvet/reshade-toolbox/releases/download/dr-dlss-v0.1.2.0/SHA256SUMS.txt)

当前版本标记为预发布版，游戏验收进度见 VALIDATION.md。发布页提供可直接使用的 DLL，无需自行编译。

## 功能

- 提供游戏默认、K、L、M 四个模型选项和六个默认挡位。
- **写入配置**：备份并保存 OptiScaler.ini，供下次启动读取。
- **刷新生效**：执行窗口刷新，不写入模型或挡位。
- **写入并刷新生效**：成功保存配置后执行窗口刷新。
- 高级刷新默认参数：窗口模式 1、无边框模式 2、等待 800 毫秒、临时窗口比例 0.95、调整窗口尺寸和 SwapChain 请求开启。
- 每秒读取磁盘配置，显示配置模型、倍率、覆盖开关、游戏输出分辨率及估算的 DLSS 输入分辨率。

| 挡位 | 比例 | 命令 |
|---|---:|---|
| DLAA | 1.0 | `dlaa` |
| Ultra Quality | 1.3 | `uq` |
| Quality | 1.5 | `quality` |
| Balanced | 1.7 | `balanced` |
| Performance | 2.0 | `performance` |
| Ultra Performance | 3.0 | `up` |

配置中的模型和比例会如实显示；如果模型不在可选范围内，写入前需选择游戏默认、K、L 或 M。

## 预设选择提示

模型选择框的宽度至少容纳最长完整选项名称，模型与挡位之间保留间距。配置路径输入框使用整行可用宽度，并按完整路径测量最小宽度，单行显示。下拉选项直接显示用途；选择只改变待写入设置，点击按钮后应用。计算方式、兼容说明、刷新原理和命令用法见本文档，模块界面提供操作、当前配置及结果。

| 预设 | 提示 |
|---|---|
| 游戏默认 | 关闭 OptiScaler 模型覆盖，将模型请求交还 FF14；缩放挡位仍单独保存 |
| K | DLAA / Quality / Balanced 的常用起点；RTX 20/30 系列可优先考虑 |
| M | 面向 Performance（比例 2.0），需要支持 DLSS 4.5 的文件版本 |
| L | 面向 4K Ultra Performance（比例 3.0），计算开销较高 |

建议依据 [NVIDIA 官方 DLSS 4.5 说明](https://www.nvidia.com/en-us/geforce/news/dlss-4-5-dynamic-multi-frame-gen-6x-2nd-gen-transformer-super-res/)、[SDK v310.5.3 预设定义](https://github.com/NVIDIA/DLSS/blob/v310.5.3/include/nvsdk_ngx_defs.h)和[当前 Streamline 定义](https://github.com/NVIDIA-RTX/Streamline/blob/main/include/sl_dlss.h)。根据 [310.2 系列发布说明](https://github.com/NVIDIA/DLSS/releases/tag/v310.2.1)和 [310.5.0 发布说明](https://github.com/NVIDIA/DLSS/releases/tag/v310.5.0)，K 要求文件版本至少 310.2.0，L/M 至少 310.5.0；列表按检测到的文件版本过滤，命令与写入也拒绝不支持的选择。未知文件版本时只提供游戏默认。

游戏默认写入 `RenderPresetOverride=false`、`RenderPresetForAll=0`，不是选择 G/H/I/N/O 等占位值；[OptiScaler 配置定义](https://github.com/optiscaler/OptiScaler/blob/master/OptiScaler.ini)说明模型覆盖关闭时不强制预设。这不替换当前使用的 DLSS DLL。

## 当前配置与分辨率

后台每秒重新读取 INI，外部改动也会更新“当前配置”，不会覆盖尚未写入的下拉选择。更换路径、手动读取或成功写入后，过期的后台结果不会覆盖新快照；读失败清除配置显示。

读取成功后，“当前配置”显示从 INI 取得的“配置模型”和“缩放倍率”。例如显示 PRESET K（11）和 2×，表示最近一次读取已成功解析对应字段；倍率缺失或无效时会显示“未设置或无效”。读取失败显示“读取失败：…”及原因，尚未取得读取结果时显示“正在读取……”。界面没有单独的“读取成功”提示。需要立即确认当前文件时，点击“重新读取”。

“输出分辨率”和“DLSS”文件版本有各自的数据来源，单独显示这两项不能作为 INI 读取成功的依据。“配置已保存”表示上一次写入完成；配置读取成功也不代表当前游戏已经应用该配置。

游戏输出尺寸在框架更新线程读取 `Device.Instance()->SwapChain->Width/Height`。配置对应的输入尺寸按输出尺寸除以配置倍率并取整；仅在配置选择 DLSS 且比例覆盖开启时显示。主界面的“当前配置”只显示倍率、渲染分辨率和输出分辨率，不显示计算方式。实现上它是配置估算，不是 DLSS Evaluate 输入纹理的实际测量，也不能证明当前游戏进程已重新读取 INI。

界面显示配置目录中 nvngx_dlss.dll 的文件版本，模块初始化和重新读取时更新；该文件版本不证明驱动覆盖后的实际模型。

## 安装与使用

1. 先完成 OptiScaler 安装并确认其在游戏中正常加载，准备好下文说明的 `OptiScaler.ini`。
2. 从发布页下载 `DR.DlssModule.dll`；自行构建时，默认产物为模块源码目录下的 `out/DR.DlssModule.dll`。
3. 在 DR 本地模块管理中添加该 DLL 的完整路径并启用。
4. 打开“DLSS档位调节”或运行 `/pdr dlss`，展开“配置文件”，点击“自动定位”，检查读取结果；自定义位置按下文手动填写。
5. 确认“当前配置”成功读取后，选择模型和挡位，使用“写入并刷新生效”。状态分别显示文件保存结果和窗口刷新结果。
6. 下次启动游戏后检查配置及实际画面。游戏内即时生效和重启后生效需要实际验证。

需要回退模块版本时，在 DR 中停用当前版本，再添加对应版本的 DLL。每次写入的 INI 备份放在配置文件旁边，名称为 `OptiScaler.ini.drbackup-*`；需要回退配置时，在游戏关闭后恢复对应备份。

### OptiScaler.ini 从哪里取得

`OptiScaler.ini` 是 OptiScaler 的配置文件，FF14 或 DR 的默认安装不会提供它。安装方法见 [OptiScaler 官方安装说明](https://github.com/optiscaler/OptiScaler/wiki/Manual-Installation)，游戏相关要求见 [FF14 专页](https://github.com/optiscaler/OptiScaler/wiki/Final-Fantasy-XIV-Dawntrail)。

已经安装 OptiScaler 时，先在资源管理器打开正在运行的 `ffxiv_dx11.exe` 所在目录，通常是游戏安装目录下的 `game`。也可以在任务管理器“详细信息”中右键 `ffxiv_dx11.exe`，选择“打开文件所在的位置”。正常安装布局中的配置文件位于该程序旁。

配置路径示意：

```text
<游戏安装目录>\game\OptiScaler.ini
```

如果目录中没有该文件，从 [OptiScaler 官方发布页](https://github.com/optiscaler/OptiScaler/releases)取得与已安装版本对应的安装包，按安装说明将其中的 `OptiScaler.ini` 放到游戏程序旁，并保持文件名不变。已有配置则继续使用现有文件。本模块读取、备份和修改已有 INI，不负责安装 OptiScaler，也不会自动下载或生成缺失的 INI。

### 自动定位与手动路径

“自动定位”根据当前游戏进程的可执行文件目录填写 `OptiScaler.ini` 的预期完整路径，保存路径后立即读取。首次启用时，已保存路径为空也会自动填写；已有路径会保留。这个操作不会扫描磁盘或其他目录。填写后查看“当前配置”：显示配置模型和倍率时，按上述说明确认读取结果；出现“读取失败”则检查文件及路径。

如果 OptiScaler 使用自定义配置位置，在“配置文件”的输入框中填写它实际读取的 INI 完整路径，结束编辑后模块会保存并读取；“重新读取”重读当前路径。读取失败时先确认文件存在及路径正确；缺失文件时写入也会失败。每秒状态更新只读取当前指定文件，不会重新定位。

### 自行构建的输出目录

`out/` 是 `Build.ps1` 默认创建的构建产出目录，位于 `Modules/DR-DLSS/` 下，包含 `DR.DlssModule.dll` 和 `build-info.json`；可通过 `-OutputDirectory` 改变位置。它是通用的源码目录结构。直接下载发布 DLL 时无需创建 out，游戏中的 INI 路径也不指向这里。

## 快捷命令

- `/pdr dlss`：打开界面。
- `/pdr dlss quality` 等六个挡位名：选择、写入并刷新。
- `/pdr dlss set quality`：选择、写入并刷新。
- `/pdr dlss select quality`：只选择挡位，尚未写入。
- `/pdr dlss preset default` 或 `preset 0`：恢复游戏模型选择、写入并刷新。
- `/pdr dlss preset K|L|M` 或 `preset 11|12|13`：选择模型、写入并刷新。
- `/pdr dlss apply`：写入配置。
- `/pdr dlss refresh`：只刷新画面。
- `/pdr optidlss`：命令别名。

## 窗口刷新

窗口刷新临时切换模式和窗口尺寸，尝试触发画面重建；本版最后恢复实际原窗口模式、位置和最大化状态。所有游戏配置及窗口操作在框架更新线程执行，取消或失败时也尝试恢复。窗口最小化、无法读取原状态或参数无效时不开始刷新。

窗口刷新请求画面重建；配置持久保存和下次启动读取是主要验收条件，当前进程即时重读 INI 仍需游戏验证。

## 构建与验证

在 `Modules/DR-DLSS/` 目录运行：

```powershell
./Build.ps1
./tests/Test-Ini.ps1
./tests/Test-Snapshot.ps1
```

Build.ps1 使用 PowerShell 7 自带的 Roslyn 编译器；宿主需基于 .NET 10。默认从当前用户的 XIVLauncherCN 安装中找到最高版本 DR、最近的正式 Hooks 目录和 .NET 10 运行时。也可以传入 `-LauncherRoot`、`-PluginDirectory`、`-HookDirectory` 和 `-OutputDirectory`。源码、依赖哈希及输出哈希记录在 `out/build-info.json`。构建只读取依赖元数据，不执行目标插件。

INI 测试默认生成自含样本；也可通过 `-SourceIni` 指定已有 INI，测试仅操作它的临时副本。快照测试使用隔离临时配置。这两项测试无需游戏安装或运行，也不会操作游戏窗口。配置替换前检查已观察到的外部改动；检查与实际替换之间仍存在很短的竞争窗口。

## 持续维护

上游发布影响模块的更新后按需适配。源码、构建脚本、行为测试与维护记录保存在专用分支；构建输出目录 out 不纳入版本控制。DLL 和 SHA256 校验文件作为 GitHub Release 附件发布，每个版本用 `dr-dlss-v<版本>` 标签固定到对应源码提交；未完成游戏验收的版本标记为预发布。

更新来源及影响判断见 [UPSTREAM.md](UPSTREAM.md)。验证状态见 [VALIDATION.md](VALIDATION.md)。来源说明见 [PROVENANCE.md](PROVENANCE.md)。编译、文件写入检查与游戏内验证分开记录。
