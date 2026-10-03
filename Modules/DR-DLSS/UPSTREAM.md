# 更新来源与适配基线

维护目标是配置持久保存、游戏默认/K/L/M 和默认挡位手动切换；保留三个操作按钮、高级刷新参数和快捷命令。自动切换、自定义比例、旧/弃用预设及运行时桥接不属于当前维护范围。

## 已核实的更新来源

| 来源 | 检查内容 |
|---|---|
| [DR 官方发布清单](https://github.com/AtmoOmen/DalamudPlugins/blob/main/pluginmaster.json) | 按 InternalName=DailyRoutines 和当前 DalamudApiLevel 筛选版本、下载地址，避免选中 API 13/14 的旧渠道 |
| [DR Releases](https://github.com/Dalamud-DailyRoutines/DailyRoutines/releases) | 发布版本、发布时间、安装包资产 |
| [DR 公开模块源码](https://github.com/Dalamud-DailyRoutines/DailyRoutines.ModulesPublic) | 模块基类、命令、配置、依赖及相关接口适配用法的变化 |
| [Omni Toolbox 发布清单](https://github.com/YouShux/DalamudPlugins/blob/main/Pluginmaster.json) | OmniToolbox 版本变化，仅作为关联插件信息；尚未证明本模块依赖它 |
| 本地 DR、OmenTools、Dalamud 和 FFXIVClientStructs DLL | 实际文件哈希、程序集身份、调用接口兼容性 |
| [NVIDIA DLSS](https://github.com/NVIDIA/DLSS)及[Streamline 预设定义](https://github.com/NVIDIA-RTX/Streamline/blob/main/include/sl_dlss.h) | 预设说明、版本支持、弃用状态发生变化时核对 PresetHelp.cs 与文档 |

[AtmoOmen 发布页](https://info.atmoomen.top/docs/changelog/v2.2.2.0/) 和 [YouShuOmni 网站](https://www.youshuomni.com/) 是用户提供的补充信息源，目前未成功读取正文。不能把读取失败当作版本未变化。OmenTools 的精确远程源码仓库尚未核实；从 DR 发布包和实际本地 DLL 核对其接口。

## 2026-10-03 基线

- DR/API 15：`2.2.2.0`；GitHub 发布于 `2026-10-02T12:24:37Z`。
- ModulesPublic main：`d0dc979059080751953530f8d8bbf4e9ddab051c`。
- Omni Toolbox 发布清单：`1.1.6.2`；不等同于 OmenTools 库版本。
- OmenTools（DR 2.2.2.0）：AssemblyVersion `1.0.0.0`，SHA-256 `C2BDFF6DD126E1B254A5250EFB3657450E551DA11FC721CEB331BCEF0DACE48B`。
- 旧模块期待 `ChatError(string, ReadOnlySeString?)` / `Chat(string, ReadOnlySeString?)`；2.2.2.0 的实例方法变为 `(ReadOnlySeString, bool)`。本模块使用仍接受 string 的 Notification 方法，消除了旧聊天签名引用。
- `Config.Load(this)` / `config.Save(this)` 扩展成员仍可用；本模块使用 ModuleBase 的 LoadConfig/SaveConfig。早期排查曾把扩展成员误判为已移除，此处以完整接口检查为准。
- 完整构建依赖和输出哈希以 `out/build-info.json` 为准，固定版本号不足以识别实际代码修订。

## 更新处理

先比较已验证基线与当前发布或文件身份，判断是否影响本模块。公开模块的普通功能提交不自动等于本地模块需要更新。OmenTools/DR/Dalamud 接口、客户端结构布局、OptiScaler 配置键或 DLSS 支持版本变化才触发相应检查。

相关变化需要检查对应接口、在工作树准备修复并重新构建，运行受影响的文件写入或快照测试。源码与编译检查通过后提供候选 DLL；窗口行为及实际 DLSS 生效继续由游戏实测确认。候选版本与用户已验证版本分开保存。

维护由用户通知触发，不设置定时任务。用户提供上游更新消息、新版本或本地依赖后，先在 `dr-dlss-module` 分支核对版本与接口，再更新模块、构建候选并记录验证结果。已完成的源码和维护文档提交到该远程分支，方便随时继续跟进。可使用的候选通过对应版本的 GitHub Release 交付 DLL 与校验文件；标签固定源码提交，不将整个 out 提交到 Git。未完成游戏验收时标记预发布版。

本地来源快照可保存在 git 忽略的 `monitor-state.local.json`，供下一次人工触发维护时比较；它不代表存在后台监控任务。游戏实测结果由用户反馈后补入 VALIDATION.md。

## 2026-10-03 桥接排查与移除

运行中的 ffxiv_dx11.exe 已加载桥接版 WINMM.dll（0.7.7.9，SHA-256 `B4E6905A3D9D4DC483AC7BFA7D3EA89F0B466BB437A7BBD771127016C075D38E`）及 DLSS 310.5.3.0。只读探针用 GetNamedPipeServerProcessId 确认 OptiScalerDlssBridge 服务端是该游戏进程；连接成功，发送唯一命令 ping 后读取 0 字节，未收到 ok bridge-ready。未发 set/save，未写游戏配置。由此确认本次不是管道不存在或连接超时，而是原生桥接无回执。

参考 C++ 源目录目前不可用，配置中的旧日志位置也不存在，不能进一步认定内部接收或关闭逻辑的原因。桥接提供运行时应用请求，配置持久写入与窗口刷新不依赖它；按用户主要要求“手动保存、下次启动生效”，0.1.2.0 移除本模块桥接功能，保留原游戏文件。
