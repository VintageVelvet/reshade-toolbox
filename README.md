# ReShade Toolbox

VintageVelvet 的个人 ReShade 着色器与预设维护仓库。

## 着色器

| 着色器 | 用途 | 使用说明 |
|---|---|---|
| [LandscapeComposition.fx](Shaders/LandscapeComposition.fx) | 横屏构图辅助线 | [横屏构图](docs/LandscapeComposition.md) |
| [AlbumFrame.fx](Shaders/AlbumFrame.fx) | 专辑封面取景、外部遮罩与内部留边 | [专辑取景框](docs/AlbumFrame.md) |

## 安装

1. 将需要的 `.fx` 文件从 `Shaders/` 复制到 ReShade 的着色器搜索目录。
2. 确保搜索路径中存在标准 `ReShade.fxh`，然后在游戏内重新加载效果。
3. 根据对应使用说明启用效果并调整参数，构图辅助和边框通常放在效果顺序末尾。

LandscapeComposition 的构图线以完整渲染画面为基准，尚未适配 AlbumFrame 的内部窗口。组合启用时将 AlbumFrame 排在其后，以遮住画板外部的构图线。

## 文档与目录

- `Shaders/`：着色器源码。
- `Presets/`：预设。
- `docs/`：使用说明、[版本记录](docs/CHANGELOG.md)与[验证记录](docs/VALIDATION.md)。

## 许可与署名

本仓库新增代码和文档采用 [MIT License](LICENSE)，Copyright (c) 2026 VintageVelvet。第三方部分继续适用原有许可；根目录 LICENSE 不替代第三方条款。

LandscapeComposition 整合了标注 MIT 的 VerticalPreviewer 和采用 BSD-3-Clause 的 Daodan Composition，分发时须保留文件内全部许可与署名。AlbumFrame 采用 MIT，文件内同样附有完整许可正文。

详细来源与条款见[第三方来源与许可说明](docs/THIRD_PARTY_NOTICES.md)。标准 ReShade.fxh 和编译工具未随仓库分发。
