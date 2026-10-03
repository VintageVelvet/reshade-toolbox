# 技术说明

本文面向实现与适配维护。下载、安装和日常操作见 [README.md](README.md)，版本验收记录见 [VALIDATION.md](VALIDATION.md)。

## 配置写入与模型检查

模块备份 INI 原始字节，再更新相关配置键，保留其他内容。写入由模块完成，桥接负责运行时更新。替换前会检查外部改动；如果其他程序恰好在检查后、替换前写入文件，仍可能发生冲突。

“游戏默认”写入 `RenderPresetOverride=false`、`RenderPresetForAll=0`，将模型请求交还游戏；比例覆盖仍单独保存。[OptiScaler 配置定义](https://github.com/optiscaler/OptiScaler/blob/master/OptiScaler.ini)说明模型覆盖关闭时不强制预设。

K 的最低文件版本为 310.2.0，L/M 为 310.5.0。列表、命令与写入共用限制，文件版本未知时只允许游戏默认。模型用途及门槛依据 [NVIDIA DLSS 4.5 说明](https://www.nvidia.com/en-us/geforce/news/dlss-4-5-dynamic-multi-frame-gen-6x-2nd-gen-transformer-super-res/)、[SDK v310.5.3 预设定义](https://github.com/NVIDIA/DLSS/blob/v310.5.3/include/nvsdk_ngx_defs.h)、[Streamline 定义](https://github.com/NVIDIA-RTX/Streamline/blob/main/include/sl_dlss.h)、[310.2 系列发布说明](https://github.com/NVIDIA/DLSS/releases/tag/v310.2.1)及 [310.5.0 发布说明](https://github.com/NVIDIA/DLSS/releases/tag/v310.5.0)。

## 桥接请求与回执

“写入配置”只保存 INI。“刷新生效”读取当前文件中的模型和挡位，经 `OptiScalerDlssBridge` 命名管道请求运行时更新；“写入并刷新生效”先保存，再执行同一流程。连接、读写有统一超时，可在模块停用时取消；连接后核对服务端属于当前游戏进程。

客户端发送：

```text
ping
set ratio <倍率> preset <模型> save 0
```

只读探测要求 `ok bridge-ready`，设置请求要求完整的 `ok applied`。桥接收到设置后更新 OptiScaler 内存中的模型、倍率及覆盖开关，并设置 DLSS 后端重建标记；`save 0` 避免桥接重新写入 INI。

现有协议只支持开启模型覆盖，无法关闭覆盖以交还游戏选择。因此游戏默认保存为 `RenderPresetOverride=false`，不发送 preset 0，请求用户重启应用。桥接材料与对应构建的识别信息见 [PROVENANCE.md](PROVENANCE.md)。

服务端发出回执后立即断开，可能丢弃尚未读取的回复。客户端先挂起异步读取，再发送请求；只读 ping 可以有界重试，set 不重试。set 发送后断开或超时显示“结果未确认”，因为服务端可能已经修改运行时配置。[Windows 断开说明](https://learn.microsoft.com/en-us/windows/win32/api/namedpipeapi/nf-namedpipeapi-disconnectnamedpipe)说明断开时可能丢弃未读取的数据。

要让服务端发送后等待回执读完，或增加关闭模型覆盖的命令，还需要桥接版的完整 OptiScaler 工程。

界面在操作结束后显示结果。收到 ok applied 且窗口刷新完成时显示“OptiScaler：ok applied；窗口刷新已完成”，失败时显示具体原因；新操作会清除旧回执。实际渲染输入的查看方法见下节。

## 窗口刷新与资源重建

桥接更新运行时设置，窗口刷新则尝试促使游戏重新查询输入尺寸并创建对应资源。只重建 OptiScaler 后端可能继续沿用旧输入尺寸；[OptiScaler 的 FF14 说明](https://github.com/optiscaler/OptiScaler/wiki/Final-Fantasy-XIV-Dawntrail)也指出比例变化可能需要重新启用 DLSS 或重启游戏。

刷新临时切换模式与窗口尺寸，在无边框模式稳定后明确请求显示器宽高，再恢复原窗口模式、位置与最大化状态。所有游戏配置和窗口操作在框架更新线程执行，取消或失败时也尝试恢复。窗口最小化、无法读取原状态或参数无效时不开始刷新。

默认参数为窗口模式 1、无边框模式 2、等待 800 毫秒、临时窗口比例 0.95，开启窗口尺寸调整和 SwapChain 请求。框架回调检查经过的时间，达到等待时长后执行下一步。

临时尺寸和完整显示器尺寸两次请求保留。最终恢复前分别观察窗口矩形、完整 WindowPlacement 和交换链状态；只有对应状态已一致时才跳过该操作。交换链尺寸与客户区一致且没有待处理尺寸请求时，不再请求同尺寸重建。原模式已是无边框时跳过无操作等待，恢复阶段没有实际操作时也省去最后等待。

刷新流程按窗口状态和交换链尺寸判断是否结束。DLSS 输入纹理尺寸由 OptiScaler 菜单显示，确认实际倍率时查看该菜单。

## 配置快照与尺寸数据

后台每秒读取 INI，输出尺寸在框架更新线程读取 `Device.Instance()->SwapChain->Width/Height`。快照按路径与 generation 筛除过期结果；更换路径、手动读取和写入后的新结果不会被旧任务覆盖，外部文件更新不会覆盖待写入选择，读取失败清除配置显示。

“配置渲染分辨率”按输出尺寸除以配置倍率并取整，在配置选择 DLSS 且比例覆盖开启时显示。现有桥接没有运行尺寸查询接口，因此模块用计算值展示配置对应的目标尺寸。

DLSS 版本取自配置目录中的 nvngx_dlss.dll，初始化和重新读取时更新。使用驱动模型覆盖时，实际模型还取决于驱动设置。

## ReShade 与尺寸重建

窗口尺寸变化会触发 ReShade 运行环境重建。ReShade 6.6.1 的 [ResizeBuffers 流程](https://github.com/crosire/reshade/blob/v6.6.1/source/dxgi/dxgi_swapchain.cpp#L401)重置效果运行环境，[效果销毁流程](https://github.com/crosire/reshade/blob/v6.6.1/source/runtime.cpp#L3634)会等待效果编译线程结束。因此，即使缩短模块自身的等待，画面也要等效果加载完成后才能恢复。

“Load only enabled effects”对应 `SkipLoadingDisabledEffects`。[6.6.1 的筛选条件](https://github.com/crosire/reshade/blob/v6.6.1/source/runtime.cpp#L1519)要求预设的 Techniques 列表非空，空预设可能仍加载全部效果。开启此选项可减少未启用效果的加载；挑选新效果时可能需要强制加载全部效果。模块不修改 ReShade 配置或预设。

效果缓存可以减少加载时的编译工作，尺寸变化后仍需重建运行环境。缓存加载与完整着色器编译可能使用同类日志消息，分析耗时时需结合加载路径和时间记录。具体测试结果见 [VALIDATION.md](VALIDATION.md)。

## 构建与隔离验证

在模块目录中运行：

```powershell
./Build.ps1
./tests/Test-Ini.ps1
./tests/Test-Snapshot.ps1
./tests/Test-Bridge.ps1
```

Build.ps1 使用 PowerShell 7 自带的 Roslyn 编译器，宿主需基于 .NET 10。默认从当前用户的 XIVLauncherCN 安装中寻找最高版本 DR、最近的正式 Hooks 目录及 .NET 10 运行时；可传入 `-LauncherRoot`、`-PluginDirectory`、`-HookDirectory` 和 `-OutputDirectory`。构建只读取依赖元数据，不执行目标插件；源码、依赖与产物哈希记录在 out/build-info.json。

INI 测试默认生成自含样本，也可用 `-SourceIni` 指定已有 INI，测试操作临时副本。快照测试使用隔离配置，桥接测试使用隔离命名管道。游戏内复验另需检查实际尺寸、窗口恢复和稳定性，结果记入 [VALIDATION.md](VALIDATION.md)。
