# 版权标志（分辨率适配）

`Shaders/CopyrightAdaptive.fx` 是独立的版权标志效果。它复用 AuroraShade / ReShade-CN2 安装中的 PNG，在切换截图分辨率时按画面高度调整水印大小。原来的 `Copyright.fx` 可以继续保留；新效果的完整标识是 `CopyrightAdaptive@CopyrightAdaptive.fx`。

## 安装与使用

1. 将 `Shaders/CopyrightAdaptive.fx` 和 `Shaders/CopyrightAdaptive/` 文件夹复制到实际生效的 ReShade 着色器目录。该文件夹中的三个 `.fxh` 需要一同安装。
2. 确保现有安装提供 `ReShade.fxh`、`Blending.fxh` 及列表引用的 PNG，且 PNG 所在目录已加入 `TextureSearchPaths`。本仓库不包含这些图片和依赖文件。
3. 在游戏内重新加载，让新版出现在列表中。关闭原 `Copyright`，启用“版权标志（分辨率适配）”，选择列表和款式后保存预设，再完整重新加载一次。
4. 默认基准画面高度为 `1440`。在 2560 × 1440 调好位置和缩放后，切到 3840 × 2160，再恢复原分辨率，检查大小与位置。可以保持“跟随鼠标”关闭，用水平、垂直位置固定水印。

更新时覆盖主 `.fx` 和三个私有 `.fxh`，再完整重新加载。旧错误提示会随重新加载刷新。

## 分辨率适配

“随分辨率缩放”默认开启。固定绘制尺寸的水印按 `当前渲染高度 / 基准画面高度` 调整：

| 分辨率 | 基准高度 1440 时的倍率 |
|---|---:|
| 2560 × 1440 | 1 倍 |
| 3840 × 2160 | 1.5 倍 |

水印、阴影和色差轮廓一起缩放，模糊半径继续使用像素单位。水平、垂直位置仍按画面比例设置；上述两种相同宽高比的分辨率切换时，水印中心保持相同相对位置。

若原来在 1920 × 1080 调整，基准高度填写 `1080`。关闭适配开关后使用原有尺寸规则。

## 款式与旧预设

当前三组菜单分别保留 **45、63、12 项**，包括仍有可用图片的占位项和分隔线。由于参考安装缺少对应 PNG，下列默认菜单项已移除：

| 列表 | 原编号 | 款式 |
|---|---|---|
| AuroraShade / ReShade-CN2（0） | 10、29 | SportsCenter Dawntrail、Italiano 0 |
| AuroraShade / ReShade-CN2（0） | 47 | Custom，默认 `cLayerA.png` 未提供 |
| 最终幻想 XIV（1） | 15、16 | With AuroraShade Dark、With AuroraShade White |

旧预设继续按原款式编号读取。被移除或无效的编号会回退到该列表的第一个可用款式，当前为编号 `0`；剩余款式保留原 PNG、显示尺寸和标签中的编号。

AuroraShade / ReShade-CN2 启用 `ui_bind` 后，可直接用菜单选择。新菜单通过 `CopyrightAdaptive_Menu_Source` 保存菜单位置，它与标签中的原编号不同；已保存的菜单选择优先于 `CopyrightAdaptive_Texture_Source`。

标准 ReShade 可在预处理器中设置 `CopyrightAdaptive_TEXTURE_SELECTION`（列表 0 / 1 / 2）和 `CopyrightAdaptive_Texture_Source`（标签中的原编号）。手动修改原编号时，先清除 `CopyrightAdaptive_Menu_Source`。新版菜单使用 `CopyrightAdaptive_Select`，旧 `cLayer_Select` 保存值不会覆盖新菜单。

### 迁移原 Copyright 预设

先在游戏内保存当前参数，然后在仓库根目录运行：

```powershell
& .\tools\Convert-CopyrightAdaptivePreset.ps1 `
    -SourcePreset 'D:\Presets\MyPreset.ini' `
    -DestinationPreset 'D:\Presets\MyPreset-Adaptive.ini'
```

脚本生成新的预设，复制位置、缩放、样式编号等参数，并改用独立效果。源文件保留，输出必须是尚不存在的文件。已有 `CopyrightAdaptive.fx` 段的预设可以直接加载新版，迁移工具会拒绝再次添加同名段。被移除的款式由新版自动回退。

## 使用自己的 PNG

Custom 47 保留为手动预处理选项。把图片放入有效纹理搜索目录，清除 `CopyrightAdaptive_Menu_Source`，再设置：

```ini
CopyrightAdaptive_TEXTURE_SELECTION=0
CopyrightAdaptive_Texture_Source=47
CopyrightAdaptiveTex="MySignature.png"
```

文件名应与实际 PNG 一致。只有显式提供 `CopyrightAdaptiveTex` 时，手动 Custom 47 才启用；未提供时加载可用的默认款式。

未指定宽高时，Custom 47 按画面尺寸绘制，各轴不会重复乘分辨率倍率。如果需要固定基准绘制尺寸，可另外设置：

```ini
CopyrightAdaptive_SIZE_X=800.0
CopyrightAdaptive_SIZE_Y=100.0
```

固定数值轴随分辨率缩放，未指定的轴继续跟随画面尺寸。需要跟随画面尺寸时，将对应宽高宏留空，不显式填写 `BUFFER_WIDTH` 或 `BUFFER_HEIGHT`。

## 同步安装中的样式

更新 AuroraShade / ReShade-CN2 或素材集合后，可从仓库根目录重新生成私有列表：

```powershell
& .\tools\Sync-CopyrightAdaptiveStyles.ps1 `
    -SourceShaderDirectory 'D:\Game\reshade-shaders\Shaders' `
    -TextureDirectory 'D:\Game\reshade-shaders\Textures'
```

两个输入目录都必需。工具根据原列表及当前素材目录筛选可用 PNG，将三个头文件写入 `Shaders/CopyrightAdaptive/`，保留原款式编号和声明的显示尺寸。它同时生成本地 `styles-manifest.json`，记录移除原因及菜单位置与原编号的映射；清单包含所选本机目录，用于本地检查，不纳入公开仓库。

同步后将三个头文件更新到游戏中并重新加载。可用项变化可能改变菜单位置，请重新选择款式并保存预设。

## 来源与验证

基于实际 AuroraShade / ReShade-CN2 安装提供的 `Copyright.fx` 和三个 `CopyrightTex` 头文件，保留作者、翻译署名和 MIT 标注。新增分辨率适配、独立命名、素材筛选、菜单映射和预设迁移。来源及分发范围见[第三方说明](THIRD_PARTY_NOTICES.md)。

已完成真实 ReShade FX 预处理、DX11 SM5 编译、素材检查和脚本验证，具体范围见[验证记录](VALIDATION.md)。游戏内新版菜单绑定及强制切换分辨率后的显示，按上面的安装步骤观察。
