# 来源与许可

## LandscapeComposition.fx

此文件基于 AuroraShade（原 ReShade-CN2）1207 发行包内的 `Shaders/GS/VerticalPreviewer.fx` 0.3。

参考文件 SHA-256：`6CAB70357CCE7D7FDCEC6F62228BD955874C2C5529E3681162A909E4D841DB12`。

该发行包及其中的 0.3 原始文件未纳入仓库，此记录也未提供该发行包的公开下载链接。公开可核查的英文 0.2 源码和 Composition 许可列于下文，供来源与实现比较使用。

原文件署名：CeeJay.dk、seri14、Marot Satil、prod80、uchu suzume、originalnicodr；构图部分来自 Alexander Federwisch 的 [Daodan Composition](https://github.com/Daodan317081/reshade-shaders)。中文翻译原署名为 BarridadeMKXX，已在着色器原文保留。

本版本由 VintageVelvet 维护，修改范围为横屏构图提取、参数组织、命名空间隔离及零线宽关闭行为。上游版权和作者署名继续保留。

发行包中的来源文件头标注 MIT，并内嵌 Composition 部分的 BSD 3-Clause 完整条款。公开 VerticalPreviewer 同样标注 MIT；Daodan Composition 原有部分继续适用 BSD-3-Clause。发布组合文件时须同时保留两者声明。文件头的 About/History 记录上游历史，仓库功能说明见 README。

本仓库新增部分采用根目录 `LICENSE` 中的 MIT，Copyright (c) 2026 VintageVelvet。该版权行的范围为本仓库新增内容；上述第三方部分沿用各自的版权和许可。

## 2026-09-28 来源核对

- 公开英文来源：[VerticalPreviewer.fx，固定提交 9d6d746](https://github.com/uchu-suzume/Vertical-Preview-and-Composition/blob/9d6d7463423f98135d2cb7af10df69ae696df245/VerticalPreviewer.fx)，文件标注版本 **0.2**、`License: MIT` 及上述作者列表。其仓库在该版本没有独立 LICENSE 文件，源码也未提供明确的 MIT 版权年份；本仓库按原文件提供的信息保留署名与许可标注。
- BSD 来源：[Daodan LICENSE，固定提交 f01ddb6](https://github.com/Daodan317081/reshade-shaders/blob/f01ddb6f3dce6a8fb75ffb9fee878a1489edfc16/LICENSE)，版权行是 `Copyright (c) 2018-2019, Alexander Federwisch`，与发行包来源文件的内嵌声明一致。
- 实际提取来源为 AuroraShade 1207 发行包中的汉化版 **0.3**。2026-09-28 核对时，仓库文件从 `struct sctpoint` 到最后一个构图辅助函数的代码，与英文公开来源在忽略空白及黄金/白银比例常量重命名后完全一致；12 种构图几何可追溯至该公开来源。
- 发行包来源文件另含中文翻译及缩略图改进署名。仓库首版提取构图部分，界面主要保留短中文构图名称，功能说明针对仓库版本编写；缩略图改进逻辑未纳入首版。原翻译署名已保留，但该次来源核对未找到翻译贡献的单独授权声明，翻译贡献的授权范围仍未独立确认。

## 分发范围

标准 `ReShade.fxh` 由 ReShade 使用环境提供，本仓库不再分发该依赖。

验证使用的编译工具、原始着色器包和游戏素材未纳入仓库。分发编译后的着色器或打包第三方依赖时，需一并附相应许可与署名；BSD 对二进制分发也要求在文档或随附材料中保留声明。

## 上游 Composition 许可原文

BSD 3-Clause License

	Composition.fx
	Copyright (c) 2018-2019, Alexander Federwisch
	All rights reserved.

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:

	* Redistributions of source code must retain the above copyright notice, this
	list of conditions and the following disclaimer.

	* Redistributions in binary form must reproduce the above copyright notice,
	this list of conditions and the following disclaimer in the documentation
	and/or other materials provided with the distribution.

	* Neither the name of the copyright holder nor the names of its
	contributors may be used to endorse or promote products derived from
	this software without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
	DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
	FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
	DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
	SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
	OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
	OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## MIT 许可正文（上游标注 MIT 的部分）

上游作者署名已列于本文开头并保留于着色器原始文件头。以下补充标准 MIT 授权条款及免责声明，不虚构上游未提供的版权年份；本仓库新增内容的版权与 MIT 正文见根目录 LICENSE。

```text
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## AlbumFrame.fx 构图辅助

2026-09-29 从本仓库 LandscapeComposition.fx 复用构图模式与绘制辅助函数，来源与署名沿用上文。将全屏坐标改为画板或内部窗口局部坐标，并以所选区域尺寸换算像素线宽。保留原几何和斜线加宽规则。文件包含原有 MIT、BSD-3-Clause 署名与完整条款；新增遮罩与区域适配部分采用仓库 MIT。
