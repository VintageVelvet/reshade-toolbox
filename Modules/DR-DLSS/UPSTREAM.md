# 更新来源与适配基线

维护目标是配置持久保存、游戏默认/K/L/M 和默认挡位手动切换、当前状态读取、三个操作按钮、高级刷新参数和快捷命令。

## 依赖关系

本模块由 DR 加载，使用 DailyRoutines.Common 的模块基类、配置和界面容器；通过 OmenTools 获取服务、注册命令和发送通知。框架、游戏配置与界面接口来自 Dalamud，窗口句柄和图形设备结构来自 FFXIVClientStructs。配置写入的使用方是 OptiScaler，模型支持范围由使用中的 DLSS 文件决定。

`OmenTools.OmenService` 是 OmenTools 的服务命名空间。[DR 公开模块工程](https://github.com/Dalamud-DailyRoutines/DailyRoutines.ModulesPublic/blob/main/DailyRoutines.ModulesPublic.csproj)明确引用 OmenTools，并允许从 DR 的 Dev 目录取得该 DLL。适配时既要查工具库源码变化，也要核对 DR 实际携带的二进制。

## 已核实的更新来源

| 组件 | 主要来源 | 更新后检查内容 |
|---|---|---|
| DR 宿主与 Common | [官方清单 main/pluginmaster.json](https://github.com/AtmoOmen/DalamudPlugins/blob/main/pluginmaster.json)、[DR Releases](https://github.com/Dalamud-DailyRoutines/DailyRoutines/releases)、[公开模块源码](https://github.com/Dalamud-DailyRoutines/DailyRoutines.ModulesPublic) | 按 InternalName=DailyRoutines 和当前 DalamudApiLevel 选择渠道；检查实际发布包中的宿主、Common、OmenTools。重点核对 ModuleBase 生命周期、LoadConfig/SaveConfig、ModuleInfo/Permission、Overlay 及本地模块加载方式 |
| OmenTools 工具库 | [AtmoOmen/OmenTools](https://github.com/AtmoOmen/OmenTools)、[main 提交记录](https://github.com/AtmoOmen/OmenTools/commits/main/) | DService 的服务取得与初始化、CommandManager 的子命令注册/移除、NotifyHelper 的 Notification/Chat 接口。当前没有独立 Release，应跟源码提交，并检查 DR 实际携带的 DLL |
| 国服 Dalamud | [ottercorp/Dalamud](https://github.com/ottercorp/Dalamud)、[Dalamud API 版本说明](https://dalamud.dev/versions/)、[国服启动器的框架更新实现](https://github.com/ottercorp/FFXIVQuickLauncher/blob/CN/src/XIVLauncher.Common/Dalamud/DalamudUpdater.cs) | API Level、.NET 宿主、IFramework.Update/线程约束、IGameConfig/ScreenMode、CommandInfo 和 Dalamud.Bindings.ImGui。以实际安装的 Hooks 为构建基准；国际服 API 公告作为迁移预告，不能直接等同于国服已发布版本 |
| 国服客户端结构库 | [ottercorp/FFXIVClientStructs](https://github.com/ottercorp/FFXIVClientStructs)、[Dalamud 子模块声明](https://github.com/ottercorp/Dalamud/blob/master/.gitmodules) | Framework/GameWindow/WindowHandle、Device/SwapChain 的尺寸、NewWidth/NewHeight/RequestResolutionChange。国服游戏补丁或框架携带的结构库更新后，重新核对布局与窗口刷新；上层源码参考 [aers/FFXIVClientStructs](https://github.com/aers/FFXIVClientStructs) |
| OptiScaler | [Releases](https://github.com/optiscaler/OptiScaler/releases)、[配置定义](https://github.com/optiscaler/OptiScaler/blob/master/OptiScaler.ini) | DLSS 选择、模型覆盖开关、RenderPresetForAll、比例覆盖与六个挡位键的含义及默认值；启动时的配置读取与刷新后的重新读取行为 |
| NVIDIA DLSS | [SDK Releases](https://github.com/NVIDIA/DLSS/releases)、[SDK 预设定义](https://github.com/NVIDIA/DLSS/blob/main/include/nvsdk_ngx_defs.h)、[Streamline 预设定义](https://github.com/NVIDIA-RTX/Streamline/blob/main/include/sl_dlss.h) | K/L/M 的支持版本、用途、弃用和默认行为。变化影响 PresetHelp.cs、选项过滤及写入限制；以配置目录中实际 nvngx_dlss.dll 文件版本核对 |

[AtmoOmen 更新说明页](https://info.atmoomen.top/docs/changelog/v2.2.2.0/)可补充 DR 发布内容；版本与依赖接口以实际发布包核对。

## OmenTools 报错的已知原因

2026-10-02 的 OmenTools 提交[“精简聊天 API”](https://github.com/AtmoOmen/OmenTools/commit/26ef570bde7168123cc9afe152abdafa1f182b5f)修改了 [NotifyHelper.cs](https://github.com/AtmoOmen/OmenTools/blob/main/OmenService/Implementations/Helpers/Notify/NotifyHelper.cs)：实例方法 `ChatError(string, ReadOnlySeString?)` / `Chat(string, ReadOnlySeString?)` 被移除，替换为 `(ReadOnlySeString, bool useDefaultPrefix = true)`。

经 DLL 元数据核对，DR 2.2.1.0 与 2.2.2.0 携带的 OmenTools 存在同样的签名差异。调用旧签名的已编译 DLL 会出现 `Method not found: ...NotifyHelper.ChatError(System.String, Nullable<ReadOnlySeString>)`；错误发生在通知接口，不足以据此认定 INI 文件损坏或 DLSS 本身失效。当前本模块使用 NotificationInfo/Success/Warning/Error，已针对 DR 2.2.2.0 的依赖编译。

两份 OmenTools 的 AssemblyVersion 都是 `1.0.0.0`，而文件 SHA-256 和方法签名不同。因此每次 DR 更新，即使 OmenTools 显示版本不变，也要比较文件哈希与所调用的接口。源码 main 的提交是预警信息，不证明该提交已进入某个 DR 发布包。

## 根据故障定位检查范围

| 表现或日志 | 优先核对 |
|---|---|
| MissingMethodException / Method not found，指向 NotifyHelper、CommandManager 或 DService | 完整方法签名、模块构建时与当前实际加载的 OmenTools DLL。接口未变化时再排查是否加载了另一份依赖或旧模块 |
| “服务 … 尚未注册或初始化” | OmenTools 的服务注册、DR 初始化顺序、模块启用/卸载时机，以及前面的首个异常；这是服务生命周期问题，不能直接归为聊天方法签名变化 |
| ModuleBase/Common 的 TypeLoadException、加载失败或配置调用失败 | 当前 DR/Common 接口、模块加载要求和对应 API 渠道 |
| Dalamud/ImGui 接口找不到或 API Level 不匹配 | 实际 Hooks、Dalamud 与绑定 DLL、当前 .NET 宿主及 DR 渠道 |
| 更新游戏后窗口刷新异常、输出尺寸异常或访问错误 | 对应国服客户端版本、Hooks 携带的 FFXIVClientStructs 和所使用字段/函数；编译通过不能验证原生结构布局仍正确 |
| INI 已保存，重启后倍率或模型仍不符合预期 | 游戏实际使用的 OptiScaler 路径/版本、配置键与覆盖开关、DLSS 文件支持情况，再检查其他程序是否改写配置 |

故障记录应包含完整异常栈、DR 版本、实际 Hooks 目录、有关 DLL 的哈希和游戏/OptiScaler/DLSS 版本。只看到 OmenService 字样不能确定所有失效都来自同一种原因。

## 2026-10-03 基线

- DR/API 15：`2.2.2.0`；GitHub 发布于 `2026-10-02T12:24:37Z`。
- ModulesPublic main：`d0dc979059080751953530f8d8bbf4e9ddab051c`。
- OmenTools 源码 main：`c726d53456d56b82074a3ee8dafdef6ac1831811`；聊天 API 变化提交：`26ef570bde7168123cc9afe152abdafa1f182b5f`。未证明 DR 包内 DLL 精确对应哪个源码提交。
- OmenTools（DR 2.2.1.0）：AssemblyVersion `1.0.0.0`，SHA-256 `61CB46F2B99A838C96C1D3B0F965CEA03A3EF53CAAA5A170DEE4D5276365FB9B`。
- OmenTools（DR 2.2.2.0）：AssemblyVersion `1.0.0.0`，SHA-256 `C2BDFF6DD126E1B254A5250EFB3657450E551DA11FC721CEB331BCEF0DACE48B`。
- DR 2.2.2.0 的 `ChatError` / `Chat` 实例方法签名为 `(ReadOnlySeString, bool)`；本模块使用 string 参数的 Notification 方法。
- 配置通过 ModuleBase 的 LoadConfig/SaveConfig 读写。
- Dalamud：`15.0.3.6`；FFXIVClientStructs：`7.56.2.9373`；Common 的 AssemblyVersion 也是 `1.0.0.0`，需同时记录哈希。
- 国服 Dalamud 的 .gitmodules 已确认客户端结构库来自 ottercorp/FFXIVClientStructs。源码分支和子模块最新提交不自动代表已发布的 Hooks 内容。
- 完整构建依赖和输出哈希以 `out/build-info.json` 为准，固定版本号不足以识别实际代码修订。

## 更新处理

DR 更新后，先比较官方清单、Release、实际安装包和运行环境中的 DLL，再查看 OmenTools 的相关提交与 DR 公开模块的适配用法。每次 DR 包更新均比较 Common/OmenTools 文件哈希；有差异时核对本模块实际调用的接口，即使程序集版本号没有改变。

Dalamud 或游戏更新时，补查国服框架和结构库；OptiScaler 或 DLSS 更新时，补查对应配置键和预设支持范围。公开模块的普通功能提交或无关库变动不自动等于需要修改本模块。

相关变化需要检查对应接口、修复并重新构建，运行受影响的文件写入或快照测试。源码与编译检查通过后提供候选 DLL；窗口行为及实际 DLSS 生效由游戏实测确认。验证结果记录在 [VALIDATION.md](VALIDATION.md)。

维护在 `dr-dlss-module` 分支按需进行。适配提交应记录目标版本、受影响接口和验证结果；版本交付方式见 [README](README.md#持续维护)。
