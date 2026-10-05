# 横屏构图：LandscapeComposition

`Shaders/LandscapeComposition.fx` 从 AuroraShade 着色器包中的 `GS/VerticalPreviewer.fx` 0.3 提取构图功能，使用 ReShade FX。保留原来的构图几何和中文选项，直接在原画面上绘制辅助线。默认三等分、纯黑、100% 不透明度，半线宽为 1.00 像素。

支持中心线、三等分、四等分、五等分、黄金比例（1.618）、白银比例（沿用原文件名称及 √2 定义）、对角线 1、对角线 2、黄金分割网格、半剖网格、Harmonic Armature、Railman Ratio；下拉菜单每次选择一种，也可选择“关”。黄金比例与黄金分割网格是两个不同的原有模式。

## 安装与使用

1. 将 `Shaders/LandscapeComposition.fx` 复制到 ReShade 的着色器搜索目录，例如 `reshade-shaders/Shaders/`。无需覆盖任何原有文件。
2. 确保该搜索路径能找到标准 `ReShade.fxh`。此效果无需额外纹理或深度缓冲。
3. 在 ReShade 面板点击重新加载，搜索 `LandscapeComposition` 或“横屏构图”。
4. 只启用以下两个效果中的一个，并放到效果顺序末尾：
   - **横屏构图 - ReShade 截图不显示**：构图时看得见，ReShade 自身截图时排除本效果；要求 ReShade 5.2 或更新版本支持 `enabled_in_screenshot`。游戏截图、系统截图和录屏不受此设置控制。
   - **横屏构图 - 截图可见**：将构图线保留在输出画面中，便于检查或分享构图。
5. 在“构图线”下拉菜单选模式；颜色的 A 通道控制不透明度。可右键效果设置快捷键。

不要同时启用上述两个效果，否则会重复叠加构图线，并影响截图隐藏的预期结果。

## 线宽与画幅

线宽沿用上游的**半线宽**设置：水平/垂直线总宽约为参数的两倍，默认 1 对应约 2 像素；像素取样可能产生一像素的差别。斜线按上游规则额外加宽，不进行额外抗锯齿处理。半线宽为 0、A 为 0 或模式为“关”时不绘制任何构图线。

构图位置随实际渲染分辨率计算，横向和纵向线宽分别使用对应方向的像素尺寸，因此可覆盖 16:9、21:9、32:9 等完整画面。构图区域始终是整个渲染缓冲，画面内有黑边时也按该范围计算；不提供裁切画幅选择、黑边识别或宽屏分区。

## 实现与维护

- 全部 12 种构图来自参考文件，保留原位置、斜率及加宽规则。
- 每个效果执行一次全屏绘制，无需中间渲染纹理。
- 参数与辅助函数放入 `LandscapeComposition` 命名空间。
- 版本记录见 [CHANGELOG.md](CHANGELOG.md)；来源与许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)；验证记录见 [VALIDATION.md](VALIDATION.md)。
- 着色器位于 `Shaders/`；预设目录及提交要求见 [Presets/README.md](../Presets/README.md)。

官方参考：[ReShade FX 语法](https://github.com/crosire/reshade-shaders/blob/slim/REFERENCE.md)、[ReShade 5.2 截图排除功能](https://www.reshade.me/releases/8046-5-2)。
