# DR DLSS 手动模块

维护分支：[`dr-dlss-module`](https://github.com/VintageVelvet/reshade-toolbox/tree/dr-dlss-module/Modules/DR-DLSS)。适配基线为 DR `2.2.2.0` / Dalamud API 15；候选版 `0.1.4.0` 已暂停分发。

这里的“本地模块”指 DR 的模块加载类别：模块通过 DR 的本地模块管理单独加载，尚未收录进 DR 官方模块包，不随 DR 版本一起发布。本模块的源码和 DLL 在本仓库独立维护与交付。

## 下载状态

0.1.4.0 收到“写入并刷新生效”后游戏崩溃的报告，已暂停公开下载。重启游戏后，维护者确认同一次游戏运行中的 2.0 → DLAA 和 DLAA → 2.0 双向热切换成功，同时报告切换后的加载明显变慢。崩溃原因和加载延迟仍需处理，当前没有通过完整稳定性验收的热切换推荐版本。定位与验证状态见 [VALIDATION.md](VALIDATION.md)。

## 功能

- 提供游戏默认、K、L、M 四个模型选项和六个默认挡位。
- **写入配置**：备份并保存 OptiScaler.ini，供下次启动读取。
- **刷新生效**：通过桥接应用已保存的模型和挡位，收到回执后执行窗口刷新，不改写 INI。
- **写入并刷新生效**：成功保存配置后请求桥接更新，再执行窗口刷新。
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

后台每秒重新读取 INI，外部改动也会更新“配置目标”，不会覆盖尚未写入的下拉选择。更换路径、手动读取或成功写入后，过期的后台结果不会覆盖新快照；读失败清除配置显示。

读取成功后，“配置目标”显示从 INI 取得的“配置模型”和“配置倍率”。例如显示 PRESET K（11）和 2×，表示最近一次读取已成功解析对应字段；倍率缺失或无效时会显示“未设置或无效”。读取失败显示“读取失败：…”及原因，尚未取得读取结果时显示“正在读取……”。界面没有单独的“读取成功”提示。需要立即确认当前文件时，点击“重新读取”。

“输出分辨率”和“DLSS”文件版本有各自的数据来源，单独显示这两项不能作为 INI 读取成功的依据。“配置已保存”表示上一次写入完成；配置读取成功也不代表当前游戏已经应用该配置。

游戏输出尺寸在框架更新线程读取 `Device.Instance()->SwapChain->Width/Height`。“配置渲染分辨率”按输出尺寸除以配置倍率并取整；仅在配置选择 DLSS 且比例覆盖开启时显示。它表示配置目标，不是 DLSS Evaluate 输入纹理的实际测量，也不能证明当前游戏进程已应用该倍率。

界面显示配置目录中 nvngx_dlss.dll 的文件版本，模块初始化和重新读取时更新；该文件版本不证明驱动覆盖后的实际模型。

当前桥接没有运行尺寸查询接口，模块尚不能读取 OptiScaler 菜单中的实际渲染尺寸。可在角色加载后按 Insert 打开 OptiScaler，查看底部的 `渲染尺寸 → 目标尺寸 [显示尺寸]`；在输出为 2560×1440 时，DLAA 应显示 2560×1440 的渲染输入。若覆盖倍率已为 1.000，但底部仍是 1280×720 → 2560×1440，实际输入仍是 2×，不能认定 DLAA 已生效。

## 安装与使用

以下是模块操作流程说明。当前候选因崩溃报告暂停分发，热切换和窗口刷新步骤暂勿执行。

1. 先完成 OptiScaler 安装并确认其在游戏中正常加载，准备好下文说明的 `OptiScaler.ini`。
2. 从发布页下载 `DR.DlssModule.dll`；自行构建时，默认产物为模块源码目录下的 `out/DR.DlssModule.dll`。
3. 在 DR 本地模块管理中添加该 DLL 的完整路径并启用。
4. 打开“DLSS档位调节”或运行 `/pdr dlss`，展开“配置文件”，点击“自动定位”，检查读取结果；自定义位置按下文手动填写。
5. 确认“配置目标”成功读取后，选择模型和挡位，使用“写入并刷新生效”。K/L/M 的热切换需要支持下述协议的 OptiScaler 桥接版。状态分别显示文件保存、桥接请求和窗口刷新结果。
6. 桥接接受请求后检查实际画面；桥接不可用或结果未确认时，配置仍保留在 INI，但不能据此认定热切换成功。游戏默认当前仅支持配置保存后重启应用。

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

“自动定位”根据当前游戏进程的可执行文件目录填写 `OptiScaler.ini` 的预期完整路径，保存路径后立即读取。首次启用时，已保存路径为空也会自动填写；已有路径会保留。这个操作不会扫描磁盘或其他目录。填写后查看“配置目标”：显示配置模型和倍率时，按上述说明确认读取结果；出现“读取失败”则检查文件及路径。

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
- `/pdr dlss refresh`：读取已保存配置，请求运行时更新并刷新窗口。
- `/pdr optidlss`：命令别名。

## 热切换与窗口刷新

“写入配置”只保存 INI。“刷新生效”读取当前文件中的模型和挡位，经 `OptiScalerDlssBridge` 命名管道请求运行时更新；“写入并刷新生效”先保存，再执行同一流程。连接、读写有统一超时，可在模块停用时取消；连接后核对服务端属于当前游戏进程，避免控制其他实例。

桥接版收到 `set ratio <倍率> preset <模型> save 0` 后，更新 OptiScaler 内存中的配置并设置 DLSS 后端重建标记。模块自行保留原字节备份和更新 INI，不让桥接重新序列化配置文件。“桥接更新已提交”仅确认运行时设置与重建请求已提交，不是对下一帧实际渲染结果的测量。收到正确回执后，模块才执行窗口刷新。

已核对的桥接协议来自 `0.7.7-pre9 (20260525_062754)` 的自定义构建；官方 OptiScaler 不保证提供该命名管道。协议只支持开启模型覆盖，无法关闭覆盖以交还游戏选择，因此“游戏默认”保存为 `RenderPresetOverride=false`，不发送旧桥接的 preset 0 请求，提示重启应用。K/L/M 配合六个挡位可请求热切换，具体结果需要游戏实测。

旧桥接服务端发出回执后立即断开，可能丢弃尚未读取的回复。模块先挂起异步读取再发送请求；只读 ping 可有界重试，set 不重试。set 发送后断开或超时会显示“结果未确认”，因为服务端可能已经修改运行时配置。完全修复服务端回执和新增关闭覆盖能力，需要对应桥接版的完整 OptiScaler 工程。

窗口刷新临时切换模式和窗口尺寸，尝试触发画面重建；在无边框模式稳定后明确请求显示器宽高，再恢复实际原窗口模式、位置和最大化状态。所有游戏配置及窗口操作在框架更新线程执行，取消或失败时也尝试恢复。窗口最小化、无法读取原状态或参数无效时不开始刷新。

窗口刷新本身不会更新 OptiScaler 内存中的倍率和模型。此前只写 INI 再刷新窗口的流程缺少桥接调用，不能保证热切换；[OptiScaler 的 FF14 说明](https://github.com/optiscaler/OptiScaler/wiki/Final-Fantasy-XIV-Dawntrail)也指出比例变更可能需要重新启用 DLSS 或重启游戏。

### 切换时画面长时间停住

尺寸刷新会触发 ReShade 运行环境重建。ReShade 6.6.1 的 [ResizeBuffers 流程](https://github.com/crosire/reshade/blob/v6.6.1/source/dxgi/dxgi_swapchain.cpp#L401)会重置效果运行环境，[效果销毁流程](https://github.com/crosire/reshade/blob/v6.6.1/source/runtime.cpp#L3634)等待效果编译线程结束；因此耗时很长的滤镜编译可能阻塞画面恢复，不能仅靠减少模块的固定等待解决。

可在 ReShade 的 Settings 中使用“Load only enabled effects”（只加载已启用效果），减少与当前预设无关的编译。6.6.1 的[跳过条件](https://github.com/crosire/reshade/blob/v6.6.1/source/runtime.cpp#L1519)要求预设的 Techniques 列表非空；空预设仍可能加载全部效果，不能保证勾选后就消除卡顿。本模块不修改 ReShade 配置或预设。

0.1.5.0 源码保留临时尺寸与完整显示器尺寸两次请求，只在实际原窗口矩形、位置和最大化状态已经一致时跳过重复恢复；最终交换链尺寸已与客户区一致且没有待处理尺寸变化时，也跳过同尺寸请求。原模式已是无边框时省去无操作等待。该构建尚未完成游戏性能与稳定性验证，未公开发布。

## 构建与验证

在 `Modules/DR-DLSS/` 目录运行：

```powershell
./Build.ps1
./tests/Test-Ini.ps1
./tests/Test-Snapshot.ps1
./tests/Test-Bridge.ps1
```

Build.ps1 使用 PowerShell 7 自带的 Roslyn 编译器；宿主需基于 .NET 10。默认从当前用户的 XIVLauncherCN 安装中找到最高版本 DR、最近的正式 Hooks 目录和 .NET 10 运行时。也可以传入 `-LauncherRoot`、`-PluginDirectory`、`-HookDirectory` 和 `-OutputDirectory`。源码、依赖哈希及输出哈希记录在 `out/build-info.json`。构建只读取依赖元数据，不执行目标插件。

INI 测试默认生成自含样本；也可通过 `-SourceIni` 指定已有 INI，测试仅操作它的临时副本。快照测试使用隔离临时配置。这两项测试无需游戏安装或运行，也不会操作游戏窗口。配置替换前检查已观察到的外部改动；检查与实际替换之间仍存在很短的竞争窗口。

## 持续维护

上游发布影响模块的更新后按需适配。源码、构建脚本、行为测试与维护记录保存在专用分支；构建输出目录 out 不纳入版本控制。DLL 和 SHA256 校验文件作为 GitHub Release 附件发布，每个版本用 `dr-dlss-v<版本>` 标签固定到对应源码提交；未完成游戏验收的版本标记为预发布。

更新来源及影响判断见 [UPSTREAM.md](UPSTREAM.md)。验证状态见 [VALIDATION.md](VALIDATION.md)。来源说明见 [PROVENANCE.md](PROVENANCE.md)。编译、文件写入检查与游戏内验证分开记录。
