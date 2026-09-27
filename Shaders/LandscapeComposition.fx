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
    LandscapeComposition: full-frame composition extraction, 2026-09-27.
    Source: GS/VerticalPreviewer.fx from the user-provided shader collection.
    Original notices above are preserved verbatim; the original About/History
    describe the upstream shader, not this reduced version.
    Changes: remove rotation, preview, thumbnail crop, intermediate textures;
    retain all 12 composition geometries and the source's rasterization widths.
    Enable exactly ONE of the two techniques below. The screenshot annotation
    depends on the installed ReShade version and only concerns its own capture.
*/

#include "ReShade.fxh"

namespace LandscapeComposition
{
static const float LC_GOLDEN_RATIO = 1.6180339887;
static const float LC_SILVER_RATIO = 1.4142135623;

uniform int Composition <
    ui_type = "combo";
    ui_label = "构图线";
    ui_tooltip = "单选一种构图线，直接覆盖整个画面。关表示不绘制。";
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
> = 2;

uniform float4 GridColor <
    ui_type = "color";
    ui_label = "构图线颜色与透明度（RGBA）";
    ui_tooltip = "RGB 设置颜色；A 设置不透明度，0 为完全透明，1 为不透明。";
> = float4(1.0, 1.0, 1.0, 0.294);

uniform float GridHalfWidth <
    ui_type = "slider";
    ui_label = "构图线半线宽（像素）";
    ui_tooltip = "沿用参考文件的半线宽定义：水平/垂直线总宽约为此值的两倍。\n"
                 "斜线保留参考文件的额外加宽；设置为 0 时所有线完全隐藏。";
    ui_min = 0.0; ui_max = 5.0; ui_step = 0.01;
> = 2.0;

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

float3 DrawPoint(float3 texcolor, sctpoint p, float2 texCoord) {
    float2 pixelsize = BUFFER_PIXEL_SIZE * p.offset;
    
    if(p.coord.x == -1 || p.coord.y == -1)
        return texcolor;

    if(texCoord.x <= p.coord.x + pixelsize.x &&
    texCoord.x >= p.coord.x - pixelsize.x &&
    texCoord.y <= p.coord.y + pixelsize.y &&
    texCoord.y >= p.coord.y - pixelsize.y)
    return p.color;
    return texcolor;
}

float3 DrawCenterLines(float3 background, float3 gridColor, float lineWidth, float2 texCoord) {
    float3 result;

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(0.5, texCoord.y));
    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 0.5));
    
    result = DrawPoint(background, lineV1, texCoord);
    result = DrawPoint(result, lineH1, texCoord);

    return result;
}

float3 DrawThirds(float3 background, float3 gridColor, float lineWidth, float2 texCoord) {
    float3 result;

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / 3.0, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(2.0 / 3.0, texCoord.y));

    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 / 3.0));
    sctpoint lineH2 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 2.0 / 3.0));
    
    result = DrawPoint(background, lineV1, texCoord);
    result = DrawPoint(result, lineV2, texCoord);
    result = DrawPoint(result, lineH1, texCoord);
    result = DrawPoint(result, lineH2, texCoord);

    return result;
}

float3 DrawFourth(float3 background, float3 gridColor, float lineWidth, float2 texCoord) {
    float3 result;

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / 4.0, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(2.0 / 4.0, texCoord.y));
    sctpoint lineV3 = NewPoint(gridColor, lineWidth, float2(3.0 / 4.0, texCoord.y));

    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 / 4.0));
    sctpoint lineH2 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 2.0 / 4.0));
    sctpoint lineH3 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 3.0 / 4.0));
    
    result = DrawPoint(background, lineV1, texCoord);
    result = DrawPoint(result, lineV2, texCoord);
    result = DrawPoint(result, lineV3, texCoord);
    result = DrawPoint(result, lineH1, texCoord);
    result = DrawPoint(result, lineH2, texCoord);
    result = DrawPoint(result, lineH3, texCoord);

    return result;
}

float3 DrawFifths(float3 background, float3 gridColor, float lineWidth, float2 texCoord) {
    float3 result;

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / 5.0, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(2.0 / 5.0, texCoord.y));
    sctpoint lineV3 = NewPoint(gridColor, lineWidth, float2(3.0 / 5.0, texCoord.y));
    sctpoint lineV4 = NewPoint(gridColor, lineWidth, float2(4.0 / 5.0, texCoord.y));

    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 / 5.0));
    sctpoint lineH2 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 2.0 / 5.0));
    sctpoint lineH3 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 3.0 / 5.0));
    sctpoint lineH4 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 4.0 / 5.0));
    
    result = DrawPoint(background, lineV1, texCoord);
    result = DrawPoint(result, lineV2, texCoord);
    result = DrawPoint(result, lineV3, texCoord);
    result = DrawPoint(result, lineV4, texCoord);
    result = DrawPoint(result, lineH1, texCoord);
    result = DrawPoint(result, lineH2, texCoord);
    result = DrawPoint(result, lineH3, texCoord);
    result = DrawPoint(result, lineH4, texCoord);

    return result;
}

float3 DrawGoldenRatio(float3 background, float3 gridColor, float lineWidth, float2 texCoord) {
    float3 result;

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / LC_GOLDEN_RATIO, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(1.0 - 1.0 / LC_GOLDEN_RATIO, texCoord.y));

    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 / LC_GOLDEN_RATIO));
    sctpoint lineH2 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 - 1.0 / LC_GOLDEN_RATIO));
    
    result = DrawPoint(background, lineV1, texCoord);
    result = DrawPoint(result, lineV2, texCoord);
    result = DrawPoint(result, lineH1, texCoord);
    result = DrawPoint(result, lineH2, texCoord);

    return result;
}

float3 DrawSilverRatio(float3 background, float3 gridColor, float lineWidth, float2 texCoord) {
    float3 result;

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / LC_SILVER_RATIO, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(1.0 - 1.0 / LC_SILVER_RATIO, texCoord.y));

    sctpoint lineH1 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 / LC_SILVER_RATIO));
    sctpoint lineH2 = NewPoint(gridColor, lineWidth, float2(texCoord.x, 1.0 - 1.0 / LC_SILVER_RATIO));
    
    result = DrawPoint(background, lineV1, texCoord);
    result = DrawPoint(result, lineV2, texCoord);
    result = DrawPoint(result, lineH1, texCoord);
    result = DrawPoint(result, lineH2, texCoord);

    return result;
}

float3 DrawDiagonalsOne(float3 background, float3 gridColor, float lineWidth, float2 texCoord) {
    float3 result;

    sctpoint line1 = NewPoint(gridColor, lineWidth + 1.0, float2(texCoord.x, texCoord.x));
    sctpoint line2 = NewPoint(gridColor, lineWidth + 1.0, float2(texCoord.x, 1.0 - texCoord.x));
    
    result = DrawPoint(background, line1, texCoord);
    result = DrawPoint(result, line2, texCoord);

    return result;
}

float3 DrawDiagonalsTwo(float3 background, float3 gridColor, float lineWidth, float2 texCoord) {
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

    result = DrawPoint(background, line1, texCoord);
    result = DrawPoint(result, line2, texCoord);
    result = DrawPoint(result, line3, texCoord);
    result = DrawPoint(result, line4, texCoord);
    result = DrawPoint(result, lineV1, texCoord);
    result = DrawPoint(result, lineV2, texCoord);
    result = DrawPoint(result, lineH1, texCoord);
    result = DrawPoint(result, lineH2, texCoord);

    return result;
}

float3 DrawGoldenSection(float3 background, float3 gridColor, float lineWidth, float2 texCoord) {
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

    result = DrawPoint(background, line1, texCoord);
    result = DrawPoint(result, line2, texCoord);
    result = DrawPoint(result, line3, texCoord);
    result = DrawPoint(result, line4, texCoord);
    result = DrawPoint(result, line5, texCoord);
    result = DrawPoint(result, line6, texCoord);
    result = DrawPoint(result, lineV1, texCoord);
    result = DrawPoint(result, lineV2, texCoord);
    result = DrawPoint(result, lineH1, texCoord);
    result = DrawPoint(result, lineH2, texCoord);
    
    return result;
}

float3 DrawOneHalfRectangle(float3 background, float3 gridColor, float lineWidth, float2 texCoord) {
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

    result = DrawPoint(background, line1, texCoord);
    result = DrawPoint(result, line2, texCoord);
    result = DrawPoint(result, line3, texCoord);
    result = DrawPoint(result, line4, texCoord);
    result = DrawPoint(result, line5, texCoord);
    result = DrawPoint(result, line6, texCoord);
    result = DrawPoint(result, lineV1, texCoord);
    result = DrawPoint(result, lineV2, texCoord);
    result = DrawPoint(result, lineH1, texCoord);
    result = DrawPoint(result, lineH2, texCoord);
    
    return result;
}

float3 DrawHarmonicArmature(float3 background, float3 gridColor, float lineWidth, float2 texCoord) {
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

    result = DrawPoint(background, line1, texCoord);
    result = DrawPoint(result, line2, texCoord);
    result = DrawPoint(result, line3, texCoord);
    result = DrawPoint(result, line4, texCoord);
    result = DrawPoint(result, line5, texCoord);
    result = DrawPoint(result, line6, texCoord);
    result = DrawPoint(result, line7, texCoord);
    result = DrawPoint(result, line8, texCoord);
    result = DrawPoint(result, line9, texCoord);
    result = DrawPoint(result, line10, texCoord);
    
    return result;
}

float3 DrawRailmanRatio(float3 background, float3 gridColor, float lineWidth, float2 texCoord) {
    float3 result;

    sctpoint line1 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x, texCoord.x));
    sctpoint line2 = NewPoint(gridColor, lineWidth + 0.6, float2(texCoord.x, 1.0 - texCoord.x));

    sctpoint lineV1 = NewPoint(gridColor, lineWidth, float2(1.0 / 4.0, texCoord.y));
    sctpoint lineV2 = NewPoint(gridColor, lineWidth, float2(2.0 / 4.0, texCoord.y));
    sctpoint lineV3 = NewPoint(gridColor, lineWidth, float2(3.0 / 4.0, texCoord.y));

    result = DrawPoint(background, line1, texCoord);
    result = DrawPoint(result, line2, texCoord);
    result = DrawPoint(result, lineV1, texCoord);
    result = DrawPoint(result, lineV2, texCoord);
    result = DrawPoint(result, lineV3, texCoord);

    return result;
}

float4 PS_Composition(float4 pos : SV_Position, float2 texCoord : TEXCOORD) : SV_Target
{
    float4 background = tex2D(ReShade::BackBuffer, texCoord);
    // Explicitly bypass all geometries: several original diagonals add width.
    if (Composition == 0 || GridHalfWidth <= 0.0 || GridColor.a <= 0.0)
        return background;

    float3 overlay = background.rgb;
    switch (Composition)
    {
        case 1: overlay = DrawCenterLines(background.rgb, GridColor.rgb, GridHalfWidth, texCoord); break;
        case 2: overlay = DrawThirds(background.rgb, GridColor.rgb, GridHalfWidth, texCoord); break;
        case 3: overlay = DrawFourth(background.rgb, GridColor.rgb, GridHalfWidth, texCoord); break;
        case 4: overlay = DrawFifths(background.rgb, GridColor.rgb, GridHalfWidth, texCoord); break;
        case 5: overlay = DrawGoldenRatio(background.rgb, GridColor.rgb, GridHalfWidth, texCoord); break;
        case 6: overlay = DrawSilverRatio(background.rgb, GridColor.rgb, GridHalfWidth, texCoord); break;
        case 7: overlay = DrawDiagonalsOne(background.rgb, GridColor.rgb, GridHalfWidth, texCoord); break;
        case 8: overlay = DrawDiagonalsTwo(background.rgb, GridColor.rgb, GridHalfWidth, texCoord); break;
        case 9: overlay = DrawGoldenSection(background.rgb, GridColor.rgb, GridHalfWidth, texCoord); break;
        case 10: overlay = DrawOneHalfRectangle(background.rgb, GridColor.rgb, GridHalfWidth, texCoord); break;
        case 11: overlay = DrawHarmonicArmature(background.rgb, GridColor.rgb, GridHalfWidth, texCoord); break;
        case 12: overlay = DrawRailmanRatio(background.rgb, GridColor.rgb, GridHalfWidth, texCoord); break;
    }
    return float4(lerp(background.rgb, overlay, saturate(GridColor.a)), background.a);
}
} // namespace LandscapeComposition

// Mutually exclusive use: enable only one of these techniques.
technique LandscapeComposition_ScreenOnly <
    ui_label = "横屏构图 - ReShade 截图不显示";
    enabled_in_screenshot = false;
    ui_tooltip = "仅启用本项或下方截图可见项，两项必须二选一。\n"
                 "沿用原文件的截图隐藏标记；是否生效取决于 ReShade 版本。\n"
                 "游戏截图、系统截图和录屏不受本标记控制。";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = LandscapeComposition::PS_Composition;
    }
}

technique LandscapeComposition_Capture <
    ui_label = "横屏构图 - 截图可见";
    ui_tooltip = "仅启用本项或上方截图不可见项，两项必须二选一。\n"
                 "构图线叠加到输出画面；建议将本效果放在效果列表最后。";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = LandscapeComposition::PS_Composition;
    }
}
