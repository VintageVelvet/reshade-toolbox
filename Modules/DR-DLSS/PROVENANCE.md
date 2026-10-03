# 来源、许可与分发范围

模块参考 `OptiScalerDlssController.cs`，原文件 UI 作者字段为 `DeepSeek`，SHA-256：`D392B8FF90996286576E241226F608FCE9F0AB5FD2673F3536F9FDDE70F035C1`。对应参考 DLL SHA-256：`B668989D9C1BD151C7FF212717368C90333D5C4C3A8E81DD62E5C5C5E2F98733`。

DR.DlssModule 由 VintageVelvet 维护，提供手动模型与挡位控制、配置持久保存、状态读取和窗口刷新。上述参考材料的原署名记录在此。

提供的参考 C# 源码未附许可证，其许可状态尚未核实；根目录 MIT 不覆盖未核实的参考部分。

DR 公开模块仓库（AGPL-3.0）仅作 API 用法参考。构建依赖来自已安装的 DR、OmenTools、Dalamud 及客户端结构程序集。

`DlssBridge.cpp` / `.h` 作为通信协议的参考材料，用于核对命名管道请求、运行时配置更新与后端重建标记；0.1.3.0 恢复模块端的桥接客户端。

桥接参考源码和原生 OptiScaler 桥接版 DLL 不随 DR.DlssModule 发布附件分发。

## 分发范围

发布附件为独立本地模块 `DR.DlssModule.dll` 和 `SHA256SUMS.txt`，通过 DR 的本地模块管理加载。DR、OmenTools、Dalamud、OptiScaler、DLSS 及游戏文件由使用环境提供，不随模块附件分发。来源、许可和分发范围统一在本文记录。
