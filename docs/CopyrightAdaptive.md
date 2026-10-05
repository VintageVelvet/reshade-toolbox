# 版权标志（分辨率适配）

CopyrightAdaptive 会在提高截图分辨率时同比放大版权标志。安装需要已有 Copyright 着色器及其 PNG 素材，工具箱负责安装效果和生成当前可用的款式列表。

## 安装

解压或克隆完整工具箱，在仓库根目录打开 Windows PowerShell 5.1 或 PowerShell 7，运行：

```powershell
& .\tools\Install-CopyrightAdaptive.ps1 -GameDirectory '..\game'
```

`-GameDirectory` 指向包含 `ReShade.ini` 的游戏目录。相对路径以 PowerShell 当前目录为基准；上例中的 `..\game` 是仓库目录旁的 `game` 文件夹。

安装脚本读取 `ReShade.ini`，找到已有着色器和纹理目录，生成可用款式列表并安装模块。完成后会显示安装位置；更新已有模块时先备份。

若要同时迁移原 Copyright 预设，先在游戏内保存当前参数，再在安装命令后加上 `-Preset`：

```powershell
& .\tools\Install-CopyrightAdaptive.ps1 `
    -GameDirectory '..\game' `
    -Preset '.\reshade-presets\Portrait.ini'
```

`-Preset` 的相对路径以游戏目录为基准，上例读取游戏目录下的 `reshade-presets\Portrait.ini`。脚本另存迁移后的预设，保留原文件；运行完成后，在游戏内选择输出的新预设。

## 启用

在游戏内重新加载 ReShade 效果，关闭原 `Copyright`，启用“版权标志（分辨率适配）”。选择列表和款式，调整位置、缩放、颜色与阴影后保存预设，再完整重新加载一次。

AuroraShade / ReShade-CN2 需要在面板右上角启用 `ui_bind`，才能直接用菜单切换图片。标准 ReShade 的款式选择方法见技术附录。

菜单会显示当前安装中有图片可用的款式。素材更新后，重新运行安装命令并加载效果，款式列表会随当前素材更新。

## 使用 1440 基准

“随分辨率缩放”默认开启，“基准画面高度”默认为 `1440`。在 2560 × 1440 下调好水印，切到 3840 × 2160 时，水印大小自动变为 1.5 倍；恢复原分辨率后还原。两个分辨率的宽高比相同，水印中心也会保持相同的画面位置。

若原来在 1920 × 1080 下调整，把基准画面高度改为 `1080`。需要固定位置时关闭“跟随鼠标”，再使用水平、垂直位置控制。

水印、阴影和色差轮廓一起缩放，模糊半径继续按像素设置。关闭“随分辨率缩放”后，使用原有尺寸规则。

旧款式编号、自定义 PNG 和样式生成细节见[技术附录](CopyrightAdaptive-Technical.md)。
