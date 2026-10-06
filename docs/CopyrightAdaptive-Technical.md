# CopyrightAdaptive 技术附录

复制安装、启用和分辨率设置见[使用说明](CopyrightAdaptive.md)。本页说明路径读取、预设兼容、自定义 PNG，以及素材集合不同时使用的可选工具。

## 新旧效果与文件关系

`CopyrightAdaptive.fx` 与原 `Copyright.fx` 并列存放，新版的三个样式头文件独立放在同级 `CopyrightAdaptive/` 文件夹中。新版使用独立的 `CopyrightAdaptive@CopyrightAdaptive.fx` technique，PNG 则继续通过现有 `TextureSearchPaths` 读取。原 `Copyright.fx` 用于定位安装目录，也可留作旧版对照；新版运行依赖已有 PNG、`ReShade.fxh` 和 `Blending.fxh`。

独立的样式头文件用于保留原款式编号，同时过滤参考安装缺图的五项：AUR 10 / 29 / 47 和 XIV 15 / 16。原版仍使用自己的列表，因此原 `Copyright.fx` 自身的缺图或编译错误不会随新版过滤消失。重新加载后可按错误条目中的文件名区分新旧效果。

## 路径读取

主 FX 通过 `CopyrightAdaptive/` 相对路径读取三个私有样式头文件，路径以主 FX 所在目录为基准。PNG 则从已有的有效纹理搜索目录读取。

| 路径 | 相对路径的基准 |
|---|---|
| FX 中的 `CopyrightAdaptive/*.fxh` | 主 FX 所在目录 |
| 图片参数 `CopyrightAdaptiveTex` | 有效的纹理搜索目录 |
| 单独同步、迁移工具的输入和输出 | PowerShell 当前目录 |
| 可选安装工具的 `-GameDirectory` | PowerShell 当前目录 |
| 可选安装工具的 `-Preset` | 指定的游戏目录 |

ReShade 的 `EffectSearchPaths`、`TextureSearchPaths` 使用搜索基准，通常为 DLL 所在的游戏目录。普通搜索路径只查指定目录，末尾为 `/**` 的路径才递归查找子目录。自定义 PNG 放在子目录时，应在图片参数中写出子目录。

## 旧款式编号与菜单位置

菜单使用紧凑的连续序号，旧款式编号继续用于读取原预设。标签中的原编号与菜单位置是两个值：

| 设置 | 含义 |
|---|---|
| `CopyrightAdaptive_TEXTURE_SELECTION` | 列表编号：0 为 AuroraShade / ReShade-CN2，1 为最终幻想 XIV，2 为 Custom 列表 |
| `CopyrightAdaptive_Texture_Source` | 原款式编号，与标签中的编号对应 |
| `CopyrightAdaptive_Menu_Source` | 新菜单位置，已保存时优先于原款式编号 |
| `CopyrightAdaptive_Select` | 新版菜单控件；旧 `cLayer_Select` 保存值不会覆盖它 |

AuroraShade / ReShade-CN2 启用 `ui_bind` 后，可直接使用菜单。标准 ReShade 可以在预处理器中设置列表与原款式编号。手动修改 `CopyrightAdaptive_Texture_Source` 前，先清除 `CopyrightAdaptive_Menu_Source`。

被列表移除或无效的旧编号会回退到该列表的第一个可用款式。压缩包中三个列表的回退编号均为 `0`。

## 随包款式列表

压缩包使用按参考安装生成的固定列表，三组菜单分别保留 **45、63、12 项**，包括仍有图片可用的占位项和分隔线。参考素材缺少以下图片，因此对应项目已从默认菜单移除：

| 列表 | 原编号 | 款式 |
|---|---|---|
| AuroraShade / ReShade-CN2（0） | 10、29 | SportsCenter Dawntrail、Italiano 0 |
| AuroraShade / ReShade-CN2（0） | 47 | Custom，默认 `cLayerA.png` 未提供 |
| 最终幻想 XIV（1） | 15、16 | With AuroraShade Dark、With AuroraShade White |

复制安装会直接使用这些列表。其他安装若增加、减少或更换了素材，可用下文的同步工具重新生成列表；游戏重新加载只会读取已有头文件。

## 使用自己的 PNG

AuroraShade / ReShade-CN2 列表的手动 Custom 47 保留原设置语法。将图片放入有效纹理搜索目录，清除 `CopyrightAdaptive_Menu_Source`，再设置：

```ini
CopyrightAdaptive_TEXTURE_SELECTION=0
CopyrightAdaptive_Texture_Source=47
CopyrightAdaptiveTex="Signatures/MySignature.png"
```

`CopyrightAdaptiveTex` 的相对路径以纹理搜索目录为基准。上例读取该目录中的 `Signatures/MySignature.png`，示例文件名可换成实际图片名。例如，纹理搜索目录若为游戏目录下的 `reshade-shaders/Textures`，图片就放在该目录的 `Signatures` 子目录。

只有显式提供 `CopyrightAdaptiveTex` 时，手动 Custom 47 才启用。未提供时使用可用的默认款式。

未指定宽高时，Custom 47 按画面尺寸绘制，各轴不会再次乘以分辨率倍率。若需要固定基准绘制尺寸，可以同时设置：

```ini
CopyrightAdaptive_SIZE_X=800.0
CopyrightAdaptive_SIZE_Y=100.0
```

固定数值轴随分辨率缩放，未指定的轴继续跟随画面尺寸。需要跟随画面尺寸时，将对应宽高宏留空，不显式填写 `BUFFER_WIDTH` 或 `BUFFER_HEIGHT`。

## 迁移旧 Copyright 预设

只有希望复用旧 Copyright 参数时，才需要使用迁移工具。

迁移工具随仓库的 `tools/` 提供。从工具箱仓库根目录打开 PowerShell，运行：

```powershell
& .\tools\Convert-CopyrightAdaptivePreset.ps1 `
    -SourcePreset '..\game\reshade-presets\Portrait.ini' `
    -DestinationPreset '..\game\reshade-presets\Portrait-Adaptive.ini'
```

两个相对路径都以 PowerShell 当前目录为基准；上例假设仓库旁有 `game` 文件夹，原预设位于游戏目录下的 `reshade-presets` 文件夹。

工具复制位置、缩放、颜色、阴影、混合和样式编号等设置，启用独立的 `CopyrightAdaptive@CopyrightAdaptive.fx`。源文件保留，输出必须是尚不存在的新文件。运行完成后，在游戏内选择新预设。已含 `CopyrightAdaptive.fx` 段的预设可直接使用，工具会拒绝再次添加同名段。

## 素材集合不同时同步列表

同步工具随仓库的 `tools/` 提供，根据原 Copyright 列表和可用 PNG 筛选项目，保留原款式编号、标签和声明的显示尺寸。它将三个私有样式头文件及 `styles-manifest.json` 写入指定目录；清单记录移除原因和编号对应关系，包含本机路径，供本地检查。

从工具箱仓库根目录运行：

```powershell
& .\tools\Sync-CopyrightAdaptiveStyles.ps1 `
    -SourceShaderDirectory '..\game\reshade-shaders\Shaders' `
    -TextureDirectory '..\game\reshade-shaders\Textures' `
    -DestinationDirectory '..\game\reshade-shaders\Shaders\CopyrightAdaptive'
```

三个相对目录都以 PowerShell 当前目录为基准；上例假设仓库旁有 `game` 文件夹，且游戏使用示例中的着色器、纹理目录。调用时应填写实际目录。同步后重新加载效果；可用项目变化可能改变菜单位置，需要重新选择款式。

单独同步默认递归检查给出的纹理目录。需要严格采用 ReShade 搜索范围时，加 `-ExactSearchPaths`，并仅给需要递归的路径添加 `/**`。`-TextureDirectory` 可以接受多个目录。

### 使用可选安装工具读取搜索路径

如果需要从 `ReShade.ini` 读取当前搜索路径并按本机素材重新生成列表，可从工具箱仓库根目录运行：

```powershell
& .\tools\Install-CopyrightAdaptive.ps1 -GameDirectory '..\game'
```

`-GameDirectory` 相对于 PowerShell 当前目录，上例中的 `..\game` 是仓库旁的游戏目录。该工具读取 `ReShade.ini`，生成列表并安装模块，不修改全局 `ReShade.ini`。搜索基准也支持已有 `[INSTALL] BasePath` 和当前安装进程的 `RESHADE_BASE_PATH_OVERRIDE`，运行时会显示实际基准。

需要同时迁移预设时，可以加上 `-Preset '.\reshade-presets\Portrait.ini'`。这个参数的相对路径以游戏目录为基准，工具另存迁移后的预设。日常复制安装直接使用随包列表。

## 维护者：生成独立安装包

仓库维护者在仓库根目录运行：

```powershell
& .\tools\Build-CopyrightAdaptivePackage.ps1
```

生成 `dist/CopyrightAdaptive.zip`，包含主 FX、三个私有头文件及许可，共五个文件。打包从 Git 的 `HEAD` 读取已提交内容；可用 `-Ref` 指定其他提交，`-DestinationPath` 指定新输出。已有输出会被拒绝，需要选择新的输出文件或先移走旧包。相对输出路径以 PowerShell 当前目录为基准。

压缩包顶层直接是主 FX 和 `CopyrightAdaptive/`，用户解压到原 `Copyright.fx` 所在目录即可。PNG 和标准依赖由已有 AuroraShade / ReShade-CN2 安装提供。

## 来源与验证

模块基于实际 AuroraShade / ReShade-CN2 安装提供的 `Copyright.fx` 和三个 `CopyrightTex` 头文件，保留作者、翻译署名和 MIT 标注。来源及分发范围见[第三方说明](THIRD_PARTY_NOTICES.md)。

ReShade FX 预处理、DX11 SM5 编译、素材检查和脚本验证的具体范围见[验证记录](VALIDATION.md)。游戏内菜单绑定及切换分辨率后的显示，可按使用说明中的步骤观察。
