/*------------------.
| :: Description :: |
'-------------------/

    Vertical Previewer and Composition (version 0.3)

    Authors: CeeJay.dk, seri14, Marot Satil, prod80, uchu suzume, originalnicodr
                    Composition https://github.com/Daodan317081/reshade-shaders
    License: MIT

    About:
    Show the preview rotated to the 90 degree angle on your screen to help you take vertical screenshot.
    Composition guides created by Daodan31708 are integrated and added new variations are built in.
    Can be used simply as a composition guide by turning off the preview.

    History:
    (*) Feature (+) Improvement (x) Bugfix (-) Information (!) Compatibility

    Version 0.3 Uchu Suzume & Marot Satil
    * Created by Uchu Suzume, with code optimization by Marot Satil.
	* Added an on/off toggle variable.
    * Added a feature to make this shader not visible in screenshots.
    * Added a guide showing thumbnail crop ratios for posting to social media.
	x Fixed a double include of ReShade.fxh.


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
*/
// Chinese Translation by BarridadeMKXX <liu.xd1998@outlook.com>
// -- Also improved the implementation of Thumbnail Guide!

/*
    AlbumFrame composition guides reuse LandscapeComposition.fx helpers.
    Upstream source: GS/VerticalPreviewer.fx from the user-provided collection.
    The original About/History above describe that historical source only.
    Changes here: adapt the 12 geometries to the selected canvas/window bounds,
    use rectangle-local pixel widths, and clip guides to that rectangle.
    Enable AlbumFrame for the mask and AlbumFrame_Guides for guides, in that order.
*/

/*
    Additional licensing notice (2026-09-28)

    The original Authors, MIT designation and BSD-3-Clause notice above
    remain applicable to their respective upstream portions.
    The VintageVelvet copyright below covers this project's additions only;
    it does not replace or assign ownership of upstream contributions.
    The MIT permission and disclaimer below also accompany the upstream
    MIT-designated portions; their original attribution is retained above.
    Redistribution of this combined file must retain both MIT and BSD notices.
    Source details and localization provenance: docs/THIRD_PARTY_NOTICES.md.

MIT License

Copyright (c) 2026 VintageVelvet

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
*/


// AlbumFrame retains its original MIT license below. Imported composition helpers
// retain the upstream MIT/BSD-3-Clause terms above; only their coordinate space changes.
/*
MIT License

Copyright (c) 2026 VintageVelvet

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
*/

// Album Frame v0.3-local - FFXIV Toolbox
// Screen-space composition mask. Original scene coordinates are preserved.
#include "ReShade.fxh"

namespace AlbumFrame
{
uniform int CanvasRatio <
    ui_type = "combo";
    ui_label = "画板比例";
    ui_items = "1:1\0 4:3\0 3:4\0 16:9\0 9:16\0自定义\0";
    ui_category = "1. 封面画板";
> = 0;

uniform float2 CustomCanvasRatio <
    ui_type = "drag";
    ui_label = "自定义画板宽 : 高";
    ui_min = 0.1; ui_max = 32.0; ui_step = 0.1;
    ui_tooltip = "画板比例选择自定义时生效。画板始终居中并在屏幕内最大化。";
    ui_category = "1. 封面画板";
> = float2(1.0, 1.0);

uniform bool EnableInnerBorder <
    ui_label = "启用内部留边";
    ui_category = "2. 内部留边";
> = false;

uniform int WindowRatio <
    ui_type = "combo";
    ui_label = "画面形状";
    ui_items = "跟随画板\0 1:1\0 16:9\0 5:4\0 2:3\0 5:7\0自定义\0";
    ui_category = "2. 内部留边";
> = 0;

uniform float WindowScale <
    ui_type = "slider";
    ui_label = "预设：画面大小 (%)";
    ui_min = 1.0; ui_max = 100.0; ui_step = 0.1;
    ui_tooltip = "适用于跟随画板和固定比例。100% 为最大，减小会等比增加留边。选择自定义时此项不生效。";
    ui_category = "2. 内部留边";
> = 100.0;

uniform float2 FreeWindowSize <
    ui_type = "slider";
    ui_label = "自定义：宽度 / 高度 (%)";
    ui_min = 1.0; ui_max = 100.0; ui_step = 0.1;
    ui_tooltip = "仅选择自定义时生效。第一个数值为画面占画板宽度的百分比，第二个为占画板高度的百分比；100% 贴边。切换模式保留各自设置，不会自动换算。";
    ui_category = "2. 内部留边";
> = float2(100.0, 100.0);

uniform float2 WindowPosition <
    ui_type = "slider";
    ui_label = "窗口位置（水平 / 垂直）";
    ui_min = -1.0; ui_max = 1.0; ui_step = 0.01;
    ui_tooltip = "0 居中；-1 贴左 / 上边，1 贴右 / 下边。窗口始终位于画板内。";
    ui_category = "2. 内部留边";
> = float2(0.0, 0.0);

uniform float3 BorderColor <
    ui_type = "color";
    ui_label = "内部边框颜色";
    ui_category = "2. 内部留边";
> = float3(1.0, 1.0, 1.0);

uniform int Composition <
    ui_type = "combo";
    ui_label = "构图线";
    ui_tooltip = "构图线相对于下方选定区域排列。需启用 Album Frame Guides，并放在取景框之后。关表示不绘制。";
    ui_items = "关\0"
               "中心线\0"
               "三等分\0"
               "四等分\0"
               "五等分\0"
               "黄金比例（1.618）\0"
               "白银比例（1.414）\0"
               "对角线1\0"
               "对角线2\0"
               "黄金分割网格\0"
               "半剖网格\0"
               "Harmonic Armature\0"
               "Railman Ratio\0";
    ui_category = "3. 构图辅助";
> = 2;

uniform float4 GridColor <
    ui_type = "color";
    ui_label = "构图线颜色与透明度（RGBA）";
    ui_tooltip = "RGB 设置颜色；A 设置不透明度，0 为完全透明，1 为不透明。";
    ui_category = "3. 构图辅助";
> = float4(0.0, 0.0, 0.0, 1.0);

uniform float GridHalfWidth <
    ui_type = "slider";
    ui_label = "构图线半线宽（像素）";
    ui_tooltip = "沿用参考文件的半线宽定义：水平/垂直线总宽约为此值的两倍。\n"
                 "斜线保留参考文件的额外加宽；设置为 0 时所有线完全隐藏。";
    ui_min = 0.0; ui_max = 5.0; ui_step = 0.01;
    ui_category = "3. 构图辅助";
> = 1.0;

uniform int CompositionArea <
    ui_type = "combo";
    ui_label = "构图参考区域";
    ui_items = "内部窗口\0整个画板\0";
    ui_tooltip = "内部窗口：跟随实际露出游戏画面的区域；未开启留边时等同画板。整个画板：包含内部留边。";
    ui_category = "3. 构图辅助";
> = 0;

float GetCanvasRatio()
{
    if (CanvasRatio == 1) return 4.0 / 3.0;
    if (CanvasRatio == 2) return 3.0 / 4.0;
    if (CanvasRatio == 3) return 16.0 / 9.0;
    if (CanvasRatio == 4) return 9.0 / 16.0;
    if (CanvasRatio == 5)
        return max(CustomCanvasRatio.x, 0.1) / max(CustomCanvasRatio.y, 0.1);
    return 1.0;
}

float GetWindowRatio(float canvasRatio)
{
    if (WindowRatio == 1) return 1.0;
    if (WindowRatio == 2) return 16.0 / 9.0;
    if (WindowRatio == 3) return 5.0 / 4.0;
    if (WindowRatio == 4) return 2.0 / 3.0;
    if (WindowRatio == 5) return 5.0 / 7.0;
    return canvasRatio;
}

float2 FitRectangle(float2 available, float ratio)
{
    float width = min(available.x, available.y * ratio);
    return float2(width, width / ratio);
}

void GetRectangles(out float2 canvasMin, out float2 canvasSize,
                   out float2 windowMin, out float2 windowSize)
{
    float ratio = GetCanvasRatio();
    // Integer, half-open bounds keep screenshot crop coordinates deterministic.
    // Non-integral ratios may differ by less than one pixel after rounding.
    canvasSize = max(floor(FitRectangle(BUFFER_SCREEN_SIZE, ratio) + 0.5), 1.0);
    canvasMin = floor((BUFFER_SCREEN_SIZE - canvasSize) * 0.5);
    windowMin = canvasMin;
    windowSize = canvasSize;
    if (EnableInnerBorder)
    {
        if (WindowRatio >= 6)
            windowSize = canvasSize * clamp(FreeWindowSize, 1.0, 100.0) * 0.01;
        else
            windowSize = FitRectangle(canvasSize, GetWindowRatio(ratio))
                * clamp(WindowScale, 1.0, 100.0) * 0.01;
        windowSize = clamp(floor(windowSize + 0.5), 1.0, canvasSize);
        windowMin = canvasMin + floor((canvasSize - windowSize)
            * (clamp(WindowPosition, -1.0, 1.0) + 1.0) * 0.5);
    }
}

float4 DrawFrame(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float2 canvasMin, canvasSize, windowMin, windowSize;
    GetRectangles(canvasMin, canvasSize, windowMin, windowSize);
    float2 pixel = position.xy;
    if (any(pixel < canvasMin) || any(pixel >= canvasMin + canvasSize))
        return float4(0.0, 0.0, 0.0, 1.0);
    if (EnableInnerBorder && (any(pixel < windowMin) || any(pixel >= windowMin + windowSize)))
        return float4(BorderColor, 1.0);
    return float4(tex2D(ReShade::BackBuffer, uv).rgb, 1.0);
}

// Imported LandscapeComposition geometries. Keep the original line-width rules;
// replace full-screen pixel size with the selected rectangle's local pixel size.
static const float LC_GOLDEN_RATIO = 1.6180339887;
static const float LC_SILVER_RATIO = 1.4142135623;
struct sctpoint {
    float3 color;
    float2 coord;
    float2 offset;
};

sctpoint NewPoint(float3 color, float2 offset, float2 coord) {
    sctpoint p;
    p.color = color;
    p.offset = offset;
    p.coord = coord;
    return p;
}

float3 DrawPoint(float3 texcolor, sctpoint p, float2 texCoord, float2 localPixelSize) {
    float2 pixelsize = localPixelSize * p.offset;

    if(p.coord.x == -1 || p.coord.y == -1)
        return texcolor;

    if(texCoord.x <= p.coord.x + pixelsize.x &&
    texCoord.x >= p.coord.x - pixelsize.x &&
    texCoord.y <= p.coord.y + pixelsize.y &&
    texCoord.y >= p.coord.y - pixelsize.y)
    return p.color;
    return texcolor;
}

float3 DrawCenterLines(float3 background, float3 gridColor, float lineWidth, float2 texCoord, float2 localPixelSize) {
    float3 result;

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(0.5, texCoord.y));
    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 0.5));

    result = DrawPoint(background, lineV1, texCoord, localPixelSize);
    result = DrawPoint(result, lineH1, texCoord, localPixelSize);

    return result;
}

float3 DrawThirds(float3 background, float3 gridColor, float lineWidth, float2 texCoord, float2 localPixelSize) {
    float3 result;

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / 3.0, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(2.0 / 3.0, texCoord.y));

    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 / 3.0));
    sctpoint lineH2 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 2.0 / 3.0));

    result = DrawPoint(background, lineV1, texCoord, localPixelSize);
    result = DrawPoint(result, lineV2, texCoord, localPixelSize);
    result = DrawPoint(result, lineH1, texCoord, localPixelSize);
    result = DrawPoint(result, lineH2, texCoord, localPixelSize);

    return result;
}

float3 DrawFourth(float3 background, float3 gridColor, float lineWidth, float2 texCoord, float2 localPixelSize) {
    float3 result;

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / 4.0, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(2.0 / 4.0, texCoord.y));
    sctpoint lineV3 = NewPoint(gridColor, lineWidth, float2(3.0 / 4.0, texCoord.y));

    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 / 4.0));
    sctpoint lineH2 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 2.0 / 4.0));
    sctpoint lineH3 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 3.0 / 4.0));

    result = DrawPoint(background, lineV1, texCoord, localPixelSize);
    result = DrawPoint(result, lineV2, texCoord, localPixelSize);
    result = DrawPoint(result, lineV3, texCoord, localPixelSize);
    result = DrawPoint(result, lineH1, texCoord, localPixelSize);
    result = DrawPoint(result, lineH2, texCoord, localPixelSize);
    result = DrawPoint(result, lineH3, texCoord, localPixelSize);

    return result;
}

float3 DrawFifths(float3 background, float3 gridColor, float lineWidth, float2 texCoord, float2 localPixelSize) {
    float3 result;

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / 5.0, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(2.0 / 5.0, texCoord.y));
    sctpoint lineV3 = NewPoint(gridColor, lineWidth, float2(3.0 / 5.0, texCoord.y));
    sctpoint lineV4 = NewPoint(gridColor, lineWidth, float2(4.0 / 5.0, texCoord.y));

    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 / 5.0));
    sctpoint lineH2 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 2.0 / 5.0));
    sctpoint lineH3 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 3.0 / 5.0));
    sctpoint lineH4 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 4.0 / 5.0));

    result = DrawPoint(background, lineV1, texCoord, localPixelSize);
    result = DrawPoint(result, lineV2, texCoord, localPixelSize);
    result = DrawPoint(result, lineV3, texCoord, localPixelSize);
    result = DrawPoint(result, lineV4, texCoord, localPixelSize);
    result = DrawPoint(result, lineH1, texCoord, localPixelSize);
    result = DrawPoint(result, lineH2, texCoord, localPixelSize);
    result = DrawPoint(result, lineH3, texCoord, localPixelSize);
    result = DrawPoint(result, lineH4, texCoord, localPixelSize);

    return result;
}

float3 DrawGoldenRatio(float3 background, float3 gridColor, float lineWidth, float2 texCoord, float2 localPixelSize) {
    float3 result;

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / LC_GOLDEN_RATIO, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(1.0 - 1.0 / LC_GOLDEN_RATIO, texCoord.y));

    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 / LC_GOLDEN_RATIO));
    sctpoint lineH2 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 - 1.0 / LC_GOLDEN_RATIO));

    result = DrawPoint(background, lineV1, texCoord, localPixelSize);
    result = DrawPoint(result, lineV2, texCoord, localPixelSize);
    result = DrawPoint(result, lineH1, texCoord, localPixelSize);
    result = DrawPoint(result, lineH2, texCoord, localPixelSize);

    return result;
}

float3 DrawSilverRatio(float3 background, float3 gridColor, float lineWidth, float2 texCoord, float2 localPixelSize) {
    float3 result;

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / LC_SILVER_RATIO, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(1.0 - 1.0 / LC_SILVER_RATIO, texCoord.y));

    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 / LC_SILVER_RATIO));
    sctpoint lineH2 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 - 1.0 / LC_SILVER_RATIO));

    result = DrawPoint(background, lineV1, texCoord, localPixelSize);
    result = DrawPoint(result, lineV2, texCoord, localPixelSize);
    result = DrawPoint(result, lineH1, texCoord, localPixelSize);
    result = DrawPoint(result, lineH2, texCoord, localPixelSize);

    return result;
}

float3 DrawDiagonalsOne(float3 background, float3 gridColor, float lineWidth, float2 texCoord, float2 localPixelSize) {
    float3 result;

    sctpoint line1 = NewPoint(gridColor, lineWidth + 1.0, float2(texCoord.x, texCoord.x));
    sctpoint line2 = NewPoint(gridColor, lineWidth + 1.0, float2(texCoord.x, 1.0 - texCoord.x));

    result = DrawPoint(background, line1, texCoord, localPixelSize);
    result = DrawPoint(result, line2, texCoord, localPixelSize);

    return result;
}

float3 DrawDiagonalsTwo(float3 background, float3 gridColor, float lineWidth, float2 texCoord, float2 localPixelSize) {
    float3 result;

    float slope = 1.50;

    sctpoint line1 = NewPoint(gridColor, lineWidth + 1.0, float2(texCoord.x, texCoord.x * slope));
    sctpoint line2 = NewPoint(gridColor, lineWidth + 1.0, float2(texCoord.x, 1.0 - texCoord.x * slope));
    sctpoint line3 = NewPoint(gridColor, lineWidth + 1.0, float2(texCoord.x, (1.0 - texCoord.x) * slope));
    sctpoint line4 = NewPoint(gridColor, lineWidth + 1.0, float2(texCoord.x, texCoord.x * slope + 1.0 - slope));

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / 3.0, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(2.0 / 3.0, texCoord.y));

    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 / 3.0));
    sctpoint lineH2 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 2.0 / 3.0));

    result = DrawPoint(background, line1, texCoord, localPixelSize);
    result = DrawPoint(result, line2, texCoord, localPixelSize);
    result = DrawPoint(result, line3, texCoord, localPixelSize);
    result = DrawPoint(result, line4, texCoord, localPixelSize);
    result = DrawPoint(result, lineV1, texCoord, localPixelSize);
    result = DrawPoint(result, lineV2, texCoord, localPixelSize);
    result = DrawPoint(result, lineH1, texCoord, localPixelSize);
    result = DrawPoint(result, lineH2, texCoord, localPixelSize);

    return result;
}

float3 DrawGoldenSection(float3 background, float3 gridColor, float lineWidth, float2 texCoord, float2 localPixelSize) {
    float3 result;

    sctpoint line1 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x, texCoord.x));
    sctpoint line2 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x,1.0 - texCoord.x));

    float slope = pow(LC_GOLDEN_RATIO, 2);

    sctpoint line3 = NewPoint(gridColor, lineWidth + 2.0, float2(texCoord.x, texCoord.x * slope));
    sctpoint line4 = NewPoint(gridColor, lineWidth + 2.0, float2(texCoord.x, 1.0 - texCoord.x * slope));

    sctpoint line5 = NewPoint(gridColor, lineWidth + 2.0, float2(texCoord.x, (1.0 - texCoord.x) * slope));
    sctpoint line6 = NewPoint(gridColor, lineWidth + 2.0, float2(texCoord.x, texCoord.x * slope + 1.0 - slope));

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / LC_GOLDEN_RATIO, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(1.0 - 1.0 / LC_GOLDEN_RATIO, texCoord.y));

    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 / LC_GOLDEN_RATIO));
    sctpoint lineH2 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 - 1.0 / LC_GOLDEN_RATIO));

    result = DrawPoint(background, line1, texCoord, localPixelSize);
    result = DrawPoint(result, line2, texCoord, localPixelSize);
    result = DrawPoint(result, line3, texCoord, localPixelSize);
    result = DrawPoint(result, line4, texCoord, localPixelSize);
    result = DrawPoint(result, line5, texCoord, localPixelSize);
    result = DrawPoint(result, line6, texCoord, localPixelSize);
    result = DrawPoint(result, lineV1, texCoord, localPixelSize);
    result = DrawPoint(result, lineV2, texCoord, localPixelSize);
    result = DrawPoint(result, lineH1, texCoord, localPixelSize);
    result = DrawPoint(result, lineH2, texCoord, localPixelSize);

    return result;
}

float3 DrawOneHalfRectangle(float3 background, float3 gridColor, float lineWidth, float2 texCoord, float2 localPixelSize) {
    float3 result;

    sctpoint line1 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x, texCoord.x));
    sctpoint line2 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x, 1.0 - texCoord.x));

    float slope = pow(1.5, 2);

    sctpoint line3 = NewPoint(gridColor, lineWidth + 2.0, float2(texCoord.x, texCoord.x * slope));
    sctpoint line4 = NewPoint(gridColor, lineWidth + 2.0, float2(texCoord.x, 1.0 - texCoord.x * slope));

    sctpoint line5 = NewPoint(gridColor, lineWidth + 2.0, float2(texCoord.x, (1.0 - texCoord.x) * slope));
    sctpoint line6 = NewPoint(gridColor, lineWidth + 2.0, float2(texCoord.x, texCoord.x * slope + 1.0 - slope));

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / 1.8, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(1.0 - 1.0 / 1.8, texCoord.y));

    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 / 1.8));
    sctpoint lineH2 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 - 1.0 /1.8));

    result = DrawPoint(background, line1, texCoord, localPixelSize);
    result = DrawPoint(result, line2, texCoord, localPixelSize);
    result = DrawPoint(result, line3, texCoord, localPixelSize);
    result = DrawPoint(result, line4, texCoord, localPixelSize);
    result = DrawPoint(result, line5, texCoord, localPixelSize);
    result = DrawPoint(result, line6, texCoord, localPixelSize);
    result = DrawPoint(result, lineV1, texCoord, localPixelSize);
    result = DrawPoint(result, lineV2, texCoord, localPixelSize);
    result = DrawPoint(result, lineH1, texCoord, localPixelSize);
    result = DrawPoint(result, lineH2, texCoord, localPixelSize);

    return result;
}

float3 DrawHarmonicArmature(float3 background, float3 gridColor, float lineWidth, float2 texCoord, float2 localPixelSize) {
    float3 result;

    sctpoint line1 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x, texCoord.x));
    sctpoint line2 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x,1.0 - texCoord.x));

    float slope1 = 0.5;

    sctpoint line3 = NewPoint(gridColor, lineWidth, float2(texCoord.x, texCoord.x * slope1));
    sctpoint line4 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 - texCoord.x * slope1));

    sctpoint line5 = NewPoint(gridColor, lineWidth, float2(texCoord.x, (1.0 - texCoord.x) * slope1));
    sctpoint line6 = NewPoint(gridColor, lineWidth, float2(texCoord.x, texCoord.x * slope1 + 1.0 - slope1));

    float slope2 = 1.5;

    sctpoint line7 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x, texCoord.x * slope2));
    sctpoint line8 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x, 1.0 - texCoord.x * slope2));

    sctpoint line9 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x, (1.0 - texCoord.x) * slope2));
    sctpoint line10 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x, texCoord.x * slope2 + 1.0 - slope2));

    result = DrawPoint(background, line1, texCoord, localPixelSize);
    result = DrawPoint(result, line2, texCoord, localPixelSize);
    result = DrawPoint(result, line3, texCoord, localPixelSize);
    result = DrawPoint(result, line4, texCoord, localPixelSize);
    result = DrawPoint(result, line5, texCoord, localPixelSize);
    result = DrawPoint(result, line6, texCoord, localPixelSize);
    result = DrawPoint(result, line7, texCoord, localPixelSize);
    result = DrawPoint(result, line8, texCoord, localPixelSize);
    result = DrawPoint(result, line9, texCoord, localPixelSize);
    result = DrawPoint(result, line10, texCoord, localPixelSize);

    return result;
}

float3 DrawRailmanRatio(float3 background, float3 gridColor, float lineWidth, float2 texCoord, float2 localPixelSize) {
    float3 result;

    sctpoint line1 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x, texCoord.x));
    sctpoint line2 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x, 1.0 - texCoord.x));

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / 4.0, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(2.0 / 4.0, texCoord.y));
    sctpoint lineV3 = NewPoint(gridColor, lineWidth, float2(3.0 / 4.0, texCoord.y));

    result = DrawPoint(background, line1, texCoord, localPixelSize);
    result = DrawPoint(result, line2, texCoord, localPixelSize);
    result = DrawPoint(result, lineV1, texCoord, localPixelSize);
    result = DrawPoint(result, lineV2, texCoord, localPixelSize);
    result = DrawPoint(result, lineV3, texCoord, localPixelSize);

    return result;
}

float4 DrawGuides(float4 pos : SV_Position, float2 texCoord : TEXCOORD) : SV_Target
{
    float4 background = tex2D(ReShade::BackBuffer, texCoord);
    // Explicitly bypass all geometries: several original diagonals add width.
    if (Composition == 0 || GridHalfWidth <= 0.0 || GridColor.a <= 0.0)
        return background;

    float2 canvasMin, canvasSize, windowMin, windowSize;
    GetRectangles(canvasMin, canvasSize, windowMin, windowSize);
    float2 targetMin = CompositionArea == 1 ? canvasMin : windowMin;
    float2 targetSize = CompositionArea == 1 ? canvasSize : windowSize;
    if (any(pos.xy < targetMin) || any(pos.xy >= targetMin + targetSize))
        return background;
    float2 localCoord = (pos.xy - targetMin) / targetSize;
    float2 localPixelSize = 1.0 / targetSize;
    float3 overlay = background.rgb;
    switch (Composition)
    {
        case 1: overlay = DrawCenterLines(background.rgb, GridColor.rgb, GridHalfWidth, localCoord, localPixelSize); break;
        case 2: overlay = DrawThirds(background.rgb, GridColor.rgb, GridHalfWidth, localCoord, localPixelSize); break;
        case 3: overlay = DrawFourth(background.rgb, GridColor.rgb, GridHalfWidth, localCoord, localPixelSize); break;
        case 4: overlay = DrawFifths(background.rgb, GridColor.rgb, GridHalfWidth, localCoord, localPixelSize); break;
        case 5: overlay = DrawGoldenRatio(background.rgb, GridColor.rgb, GridHalfWidth, localCoord, localPixelSize); break;
        case 6: overlay = DrawSilverRatio(background.rgb, GridColor.rgb, GridHalfWidth, localCoord, localPixelSize); break;
        case 7: overlay = DrawDiagonalsOne(background.rgb, GridColor.rgb, GridHalfWidth, localCoord, localPixelSize); break;
        case 8: overlay = DrawDiagonalsTwo(background.rgb, GridColor.rgb, GridHalfWidth, localCoord, localPixelSize); break;
        case 9: overlay = DrawGoldenSection(background.rgb, GridColor.rgb, GridHalfWidth, localCoord, localPixelSize); break;
        case 10: overlay = DrawOneHalfRectangle(background.rgb, GridColor.rgb, GridHalfWidth, localCoord, localPixelSize); break;
        case 11: overlay = DrawHarmonicArmature(background.rgb, GridColor.rgb, GridHalfWidth, localCoord, localPixelSize); break;
        case 12: overlay = DrawRailmanRatio(background.rgb, GridColor.rgb, GridHalfWidth, localCoord, localPixelSize); break;
    }
    return float4(lerp(background.rgb, overlay, saturate(GridColor.a)), background.a);
}
} // namespace AlbumFrame

technique AlbumFrame
<
    ui_label = "Album Frame - 专辑取景框";
    ui_tooltip = "居中最大化封面画板与内部留边。放在调色效果之后、Album Frame Guides 之前。使用包含效果的 ReShade 截图保留遮罩。";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = AlbumFrame::DrawFrame;
    }
}

technique AlbumFrame_Guides
<
    ui_label = "Album Frame Guides - 专辑构图线（ReShade 截图隐藏）";
    enabled_in_screenshot = false;
    ui_tooltip = "与 Album Frame 一起启用，并排在它之后。构图线跟随画板或内部窗口。\n"
                 "ReShade 自身截图隐藏构图线并保留取景框；需支持该标记的 ReShade 版本。\n"
                 "游戏截图、系统截图和录屏仍显示构图线。";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = AlbumFrame::DrawGuides;
    }
}
