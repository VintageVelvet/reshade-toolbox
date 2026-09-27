# 来源与许可

## LandscapeComposition.fx

此文件基于用户现有 AuroraShade（原 ReShade-CN2）1207 包内的 `Shaders/GS/VerticalPreviewer.fx` 0.3。

参考文件 SHA-256：`6CAB70357CCE7D7FDCEC6F62228BD955874C2C5529E3681162A909E4D841DB12`。

原文件署名：CeeJay.dk、seri14、Marot Satil、prod80、uchu suzume、originalnicodr；构图部分来自 Alexander Federwisch 的 [Daodan Composition](https://github.com/Daodan317081/reshade-shaders)。中文翻译原署名为 BarridadeMKXX，已在着色器原文保留。

本版本由 VintageVelvet 维护，修改范围为横屏构图提取、参数组织、命名空间隔离及零线宽关闭行为。保留所有上游版权，不将原作者工作重新署名为本仓库原创。

本地来源文件头标注 MIT，并内嵌 Composition 部分的 BSD 3-Clause 完整条款。公开 VerticalPreviewer 同样标注 MIT；Daodan Composition 原有部分继续适用 BSD-3-Clause。发布组合文件时须保留两者声明，不能将其理解为任选一种许可证。文件头的 About/History 是上游历史说明，当前功能以本仓库 README 为准。

本仓库新增部分采用根目录 `LICENSE` 中的 MIT，Copyright (c) 2026 VintageVelvet。该版权行仅针对本仓库新增内容，不替代上述第三方权利或把原作者贡献归到维护者名下。

## 2026-09-28 来源核对

- 公开英文来源：[VerticalPreviewer.fx，固定提交 9d6d746](https://github.com/uchu-suzume/Vertical-Preview-and-Composition/blob/9d6d7463423f98135d2cb7af10df69ae696df245/VerticalPreviewer.fx)，文件标注版本 **0.2**、`License: MIT` 及上述作者列表。其仓库在该版本没有独立 LICENSE 文件，源码也未提供明确的 MIT 版权年份；本仓库不自行补造上游版权年份。
- BSD 来源：[Daodan LICENSE，固定提交 f01ddb6](https://github.com/Daodan317081/reshade-shaders/blob/f01ddb6f3dce6a8fb75ffb9fee878a1489edfc16/LICENSE)，版权行是 `Copyright (c) 2018-2019, Alexander Federwisch`，与本地来源内嵌声明一致。
- 实际提取来源是前述本地汉化包 **0.3**，不是声称从英文 0.2 原样复制整个文件。核对后，当前文件从 `struct sctpoint` 到最后一个构图辅助函数的代码，与英文公开来源在忽略空白及黄金/白银比例常量重命名后完全一致；12 种构图几何可追溯至该公开来源。
- 本地来源另含中文翻译及缩略图改进署名。首版没有保留缩略图改进逻辑，界面主要保留短中文构图名称，功能说明已针对本版本编写。已保留原翻译署名；未找到这份本地汉化包针对翻译贡献的单独授权声明，因此不宣称已独立确认该贡献的授权范围。补许可正文不等于取得一份原本不存在的授权。

## 分发范围

标准 `ReShade.fxh` 由用户现有安装提供，本仓库不再分发该依赖。

验证使用的编译工具、原始着色器包和游戏素材没有提交到仓库。若未来分发编译后的着色器或打包第三方依赖，需一并附相应许可与署名，尤其 BSD 对二进制分发也要求在文档或随附材料中保留声明。

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
