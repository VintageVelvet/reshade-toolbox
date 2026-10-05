# CopyrightAdaptive 技术附录

日常安装、启用和分辨率设置见[使用说明](CopyrightAdaptive.md)。本页记录预设兼容、手动自定义图片和样式生成方式。

## 相对路径的基准

| 路径 | 相对于哪里 |
|---|---|
| 安装入口的 `-GameDirectory` | PowerShell 当前目录 |
| 安装入口的 `-Preset` | 指定的游戏目录 |
| 单独同步、迁移工具的输入和输出 | PowerShell 当前目录 |
| `EffectSearchPaths`、`TextureSearchPaths` | ReShade 搜索基准，通常是 DLL 所在的游戏目录 |
| 图片参数 `CopyrightAdaptiveTex` | 有效的纹理搜索目录 |

安装入口读取游戏目录中的 `ReShade.ini`。搜索基准也支持已有 `[INSTALL] BasePath` 和当前安装进程的 `RESHADE_BASE_PATH_OVERRIDE`，运行时会显示实际基准。普通搜索路径只查该目录，末尾为 `/**` 的路径才递归查找子目录；INI 路径里的逗号按 ReShade 的双逗号转义规则读取。

`.fxh` 包含文件可从包含语句所在文件的目录读取。PNG 则通过纹理搜索路径查找，所以把 PNG 放到 FX 旁边时，也需要让那个目录成为有效纹理搜索目录。

## 旧款式编号与菜单位置

新菜单使用紧凑的连续序号，旧款式编号继续用于读取原预设。标签中的原编号与菜单位置是两个值：

| 设置 | 含义 |
|---|---|
| `CopyrightAdaptive_TEXTURE_SELECTION` | 列表编号：0 为 AuroraShade / ReShade-CN2，1 为最终幻想 XIV，2 为 Custom 列表 |
| `CopyrightAdaptive_Texture_Source` | 原款式编号，与标签中的编号对应 |
| `CopyrightAdaptive_Menu_Source` | 新菜单位置，已保存时优先于原款式编号 |
| `CopyrightAdaptive_Select` | 新版菜单控件；旧 `cLayer_Select` 保存值不会覆盖它 |

AuroraShade / ReShade-CN2 启用 `ui_bind` 后，可直接使用菜单。标准 ReShade 可以在预处理器中设置列表与原款式编号。手动修改 `CopyrightAdaptive_Texture_Source` 前，先清除 `CopyrightAdaptive_Menu_Source`。

缺图或无效的旧编号会回退到该列表的第一个可用款式。现有参考列表的回退编号为 `0`；实际安装的可用列表由当前素材生成。

## 参考安装中的缺图项

最初核对的参考安装保留三组菜单 **45、63、12 项**，包括仍有图片可用的占位项和分隔线。下列项目因图片缺失从默认菜单移除：

| 列表 | 原编号 | 款式 |
|---|---|---|
| AuroraShade / ReShade-CN2（0） | 10、29 | SportsCenter Dawntrail、Italiano 0 |
| AuroraShade / ReShade-CN2（0） | 47 | Custom，默认 `cLayerA.png` 未提供 |
| 最终幻想 XIV（1） | 15、16 | With AuroraShade Dark、With AuroraShade White |

这些数量和缺图项描述的是参考安装。安装脚本会重新检查本机素材，因此其他安装的可用项目可能不同。

## 使用自己的 PNG

AuroraShade / ReShade-CN2 列表的手动 Custom 47 保留原设置语法。将图片放入有效纹理搜索目录，清除 `CopyrightAdaptive_Menu_Source`，再设置：

```ini
CopyrightAdaptive_TEXTURE_SELECTION=0
CopyrightAdaptive_Texture_Source=47
CopyrightAdaptiveTex="Signatures/MySignature.png"
```

`CopyrightAdaptiveTex` 的相对路径以纹理搜索目录为基准。上例对应该目录中的 `Signatures` 子目录及 `MySignature.png`。例如，纹理搜索目录若为游戏目录下的 `reshade-shaders/Textures`，图片就放在该目录的 `Signatures/MySignature.png`；路径中应写出子目录名称。

只有显式提供 `CopyrightAdaptiveTex` 时，手动 Custom 47 才启用。未提供时使用可用的默认款式。

未指定宽高时，Custom 47 按画面尺寸绘制，各轴不会再次乘以分辨率倍率。若需要固定基准绘制尺寸，可以同时设置：

```ini
CopyrightAdaptive_SIZE_X=800.0
CopyrightAdaptive_SIZE_Y=100.0
```

固定数值轴随分辨率缩放，未指定的轴继续跟随画面尺寸。需要跟随画面尺寸时，将对应宽高宏留空，不显式填写 `BUFFER_WIDTH` 或 `BUFFER_HEIGHT`。

## 样式生成

安装入口读取 `ReShade.ini` 中的着色器、纹理搜索路径，生成新模块的私有样式头文件，再把模块放入着色器搜索目录。样式生成工具根据原 Copyright 列表和可用 PNG 筛选项目，保留原款式编号、标签和声明的显示尺寸。

三个私有头文件为 `CopyrightTex_XIV_AUR.fxh`、`CopyrightTex_XIV.fxh` 和 `CopyrightTex_Custom.fxh`，安装在 `CopyrightAdaptive/` 子目录。生成的 `styles-manifest.json` 记录移除原因、菜单位置与原编号的对应关系；它包含本机目录，用于本地检查。

需要单独调用生成工具时，从工具箱仓库根目录运行：

```powershell
& .\tools\Sync-CopyrightAdaptiveStyles.ps1 `
    -SourceShaderDirectory '..\game\reshade-shaders\Shaders' `
    -TextureDirectory '..\game\reshade-shaders\Textures' `
    -DestinationDirectory '..\game\reshade-shaders\Shaders\CopyrightAdaptive'
```

以上三个相对目录都以 PowerShell 当前目录为基准；上例假设仓库旁有 `game` 文件夹，且游戏使用示例中的着色器、纹理目录。调用时应填写实际目录。同步完成后重新加载效果；可用项目变化可能改变菜单位置，需要重新选择款式并保存预设。

单独同步默认递归检查给出的纹理目录。需要严格采用 ReShade 搜索范围时，加 `-ExactSearchPaths`，并仅给需要递归的路径添加 `/**`。`-TextureDirectory` 可接受多个目录；安装入口会自动传入当前有效的搜索范围。

## 单独迁移预设

安装入口的 `-Preset` 会另存迁移后的预设。也可以单独调用原迁移工具：

```powershell
& .\tools\Convert-CopyrightAdaptivePreset.ps1 `
    -SourcePreset '..\game\reshade-presets\Portrait.ini' `
    -DestinationPreset '..\game\reshade-presets\Portrait-Adaptive.ini'
```

从工具箱仓库根目录运行时，以上两个相对路径以 PowerShell 当前目录为基准，与安装入口中相对于游戏目录的 `-Preset` 不同。

工具复制位置、缩放、颜色、阴影、混合和样式编号等设置，启用独立的 `CopyrightAdaptive@CopyrightAdaptive.fx`。源文件保留，输出必须是尚不存在的新文件。已含 `CopyrightAdaptive.fx` 段的预设可直接使用，工具会拒绝再次添加同名段。

## 来源与验证

模块基于实际 AuroraShade / ReShade-CN2 安装提供的 `Copyright.fx` 和三个 `CopyrightTex` 头文件，保留作者、翻译署名和 MIT 标注。新增代码负责分辨率适配、独立命名、素材筛选、菜单映射和预设迁移。来源及分发范围见[第三方说明](THIRD_PARTY_NOTICES.md)。

ReShade FX 预处理、DX11 SM5 编译、素材检查和脚本验证的具体范围见[验证记录](VALIDATION.md)。游戏内菜单绑定及切换分辨率后的显示，可以按使用说明中的步骤观察。
