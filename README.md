# ReShade Toolbox

VintageVelvet 维护的 ReShade 着色器、预设与 DR 本地模块仓库。

## 着色器

| 着色器 | 用途 | 使用说明 |
|---|---|---|
| [LandscapeComposition.fx](Shaders/LandscapeComposition.fx) | 横屏构图辅助线 | [横屏构图](docs/LandscapeComposition.md) |
| [AlbumFrame.fx](Shaders/AlbumFrame.fx) | 专辑封面取景、内部留边与区域构图线 | [专辑取景框](docs/AlbumFrame.md) |
| [CopyrightAdaptive.fx](Shaders/CopyrightAdaptive.fx) | 随分辨率缩放的版权标志，过滤缺图款式 | [版权标志](docs/CopyrightAdaptive.md) |
| [MagicFrame.fx](Shaders/MagicFrame.fx) | 横屏取竖幅、深度穿框与纯色人物背景 | [魔法取景框](docs/MagicFrame.md) |

## 安装

1. 将需要的 `.fx` 文件从 `Shaders/` 复制到 ReShade 的着色器搜索目录。
2. 确保搜索路径中存在标准 `ReShade.fxh`，然后在游戏内重新加载效果。
3. 根据对应使用说明启用效果并调整参数，构图辅助和边框通常放在效果顺序末尾。

CopyrightAdaptive 是独立的版权标志效果，通常在调色完成后放到效果顺序末尾。下载解压后，将 `CopyrightAdaptive.fx` 和 `CopyrightAdaptive/` 文件夹放到原 `Copyright.fx` 所在目录，再在游戏内 Reload、启用并选择款式。新版从相邻文件夹读取已过滤参考缺图项的样式表，PNG 复用现有纹理搜索目录；原 `Copyright.fx` 用于定位目录，新版运行无需开启旧效果。安装和分辨率设置见[使用说明](docs/CopyrightAdaptive.md)。

LandscapeComposition 适合全屏构图。封面画板或内部照片窗口的构图，请使用 AlbumFrame 自带的 AlbumFrame_Guides，并排在 AlbumFrame 遮罩之后。

MagicFrame 默认 9:16 竖版画板，让近景人物越过内部窗口覆盖留边，拍后沿画板裁切。排序为：调色、景深 → MagicFrame → MagicFrame_Guides；使用时关闭 AlbumFrame 和旧 MagicBorder 的遮罩，避免先盖掉人物颜色。

## DR 模块

[DR DLSS 手动模块](Modules/DR-DLSS/README.md)通过 DR 的本地模块管理加载，提供 DLSS 模型与挡位选择、配置保存、状态读取和手动刷新。安装说明、独立发布的 DLL 及兼容版本见模块文档。

## 文档与目录

- `Shaders/`：着色器源码。
- `tools/`：CopyrightAdaptive 的安装包生成、可选安装、预设迁移与样式同步工具。
- `Presets/`：预设。
- `Modules/DR-DLSS/`：[模块使用说明](Modules/DR-DLSS/README.md)与[来源记录](Modules/DR-DLSS/PROVENANCE.md)。
- `docs/`：使用说明、[版本记录](docs/CHANGELOG.md)与[验证记录](docs/VALIDATION.md)。
- [取景工具扩展需求](docs/FrameToolsRequirements.md)：模板继承与按画板自动裁图的预期行为，规划中，尚未实现。

## 许可与署名

本仓库新增代码和文档采用 [MIT License](LICENSE)，Copyright (c) 2026 VintageVelvet。第三方部分继续适用原有许可；根目录 LICENSE 不替代第三方条款。

LandscapeComposition 整合了标注 MIT 的 VerticalPreviewer 和采用 BSD-3-Clause 的 Daodan Composition，分发时须保留文件内全部许可与署名。AlbumFrame 的构图辅助复用上述构图代码，相关部分同样保留上游条款；新增的遮罩和区域适配代码采用 MIT。两个文件均附完整许可正文。

CopyrightAdaptive 从现有 Copyright 着色器适配，保留上游作者和来源署名，完整条款随私有目录的 LICENSE.txt 分发。版权标志 PNG 由现有安装提供。

详细来源与条款见[第三方来源与许可说明](docs/THIRD_PARTY_NOTICES.md)。标准 ReShade.fxh、Blending.fxh 和编译工具未随仓库分发。
