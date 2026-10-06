# 版权标志（分辨率适配）

CopyrightAdaptive 是独立的版权标志效果，放在效果顺序末尾，为处理好的画面添加标志。它使用已有 AuroraShade / ReShade-CN2 安装中的版权 PNG、`ReShade.fxh` 和 `Blending.fxh`，在切换分辨率时按画面高度调整标志大小。

## 安装

下载 CopyrightAdaptive 独立压缩包，将下面的文件和文件夹解压到原 `Copyright.fx` 所在目录，保持目录结构。无需填写路径或运行安装命令：

```text
CopyrightAdaptive.fx
CopyrightAdaptive/
├── CopyrightTex_XIV_AUR.fxh
├── CopyrightTex_XIV.fxh
├── CopyrightTex_Custom.fxh
└── LICENSE.txt
```

主 FX 从同级的 `CopyrightAdaptive/` 文件夹读取新版独立的样式头文件。PNG 继续从现有有效的纹理搜索目录读取，现有安装无须为新版重复配置这些路径。原 `Copyright.fx` 在这里用于定位文件夹，新版运行需要的是已有 PNG、`ReShade.fxh` 和 `Blending.fxh`。

也可以[下载仓库源码 ZIP](https://github.com/VintageVelvet/reshade-toolbox/archive/refs/heads/main.zip)，从其中的 `Shaders/` 取出上面两项复制过去。放好后，`CopyrightAdaptive.fx` 与原 `Copyright.fx` 应在同一目录。

## 启用

在游戏内点击 ReShade 的“重新加载 / Reload”，启用“版权标志（分辨率适配）”，将它排在效果顺序末尾。在 AuroraShade / ReShade-CN2 面板右上角启用 `ui_bind` 后，选择列表和款式。若原 `Copyright` 正在启用，将其关闭。

按需调整位置、缩放、颜色与阴影。需要固定位置时，关闭“跟随鼠标”，使用水平、垂直位置控制。

## 使用 1440 基准

“随分辨率缩放”默认开启，“基准画面高度”默认为 `1440`。在 2560 × 1440 下调好水印，切到 3840 × 2160 时，水印大小自动变为 1.5 倍；恢复原分辨率后还原。两个分辨率的宽高比相同，水印中心保持相同的画面位置。

若原来在 1920 × 1080 下调整，将基准画面高度改为 `1080`。水印、阴影和色差轮廓一起缩放，模糊半径继续按像素设置。关闭“随分辨率缩放”后，使用原有尺寸规则。

## 独立效果与缺图款式

新版与原 `Copyright.fx` 可以并存，原版无需开启。新版从自己的私有头文件读取款式，并复用现有 PNG 素材。

压缩包附带参考 AuroraShade / ReShade-CN2 素材对应的款式列表，三组菜单分别为 45、63、12 项。参考安装缺图的五项——AUR 10 / 29 / 47 和 XIV 15 / 16——已从新版菜单过滤。原 `Copyright.fx` 自身的缺图或编译错误仍属于旧版，需按错误条目中的文件名查看。

旧预设引用被移除或无效的款式编号时，会回退到该组第一个可用款式；随包三个列表的回退编号均为 `0`。

需要复用旧参数、使用自定义 PNG，或当前素材集合与参考安装不同时，参阅[技术附录](CopyrightAdaptive-Technical.md)中的可选工具。
