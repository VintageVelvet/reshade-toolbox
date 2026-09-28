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

// Album Frame v0.1 - FFXIV Toolbox
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
    ui_label = "内部窗口比例";
    ui_items = "跟随画板\0 1:1\0 16:9\0 5:4\0 2:3\0 5:7\0自定义\0自由宽高\0";
    ui_category = "2. 内部留边";
> = 0;

uniform float2 CustomWindowRatio <
    ui_type = "drag";
    ui_label = "自定义窗口宽 : 高";
    ui_min = 0.1; ui_max = 32.0; ui_step = 0.1;
    ui_category = "2. 内部留边";
> = float2(16.0, 9.0);

uniform float WindowScale <
    ui_type = "slider";
    ui_label = "窗口大小 (%)";
    ui_min = 1.0; ui_max = 100.0; ui_step = 0.1;
    ui_tooltip = "按选定比例放到最大后等比内缩。自由宽高模式使用下方两个数值。";
    ui_category = "2. 内部留边";
> = 100.0;

uniform float2 FreeWindowSize <
    ui_type = "slider";
    ui_label = "自由宽高 (%)";
    ui_min = 1.0; ui_max = 100.0; ui_step = 0.1;
    ui_tooltip = "仅自由宽高模式生效，分别相对于画板宽和高。";
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

uniform bool ShowCanvasOutline <
    ui_label = "显示画板边界参考线";
    ui_tooltip = "在画板内侧显示一像素参考线。此线会进入截图，正式拍摄请关闭。";
    ui_category = "3. 构图辅助";
> = false;

uniform float3 OutlineColor <
    ui_type = "color";
    ui_label = "参考线颜色";
    ui_category = "3. 构图辅助";
> = float3(0.5, 0.5, 0.5);

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
    if (WindowRatio == 6)
        return max(CustomWindowRatio.x, 0.1) / max(CustomWindowRatio.y, 0.1);
    return canvasRatio;
}

float2 FitRectangle(float2 available, float ratio)
{
    float width = min(available.x, available.y * ratio);
    return float2(width, width / ratio);
}

float4 DrawFrame(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float ratio = GetCanvasRatio();
    // Integer, half-open bounds keep screenshot crop coordinates deterministic.
    // Non-integral ratios may differ by less than one pixel after rounding.
    float2 canvasSize = max(floor(FitRectangle(BUFFER_SCREEN_SIZE, ratio) + 0.5), 1.0);
    float2 canvasMin = floor((BUFFER_SCREEN_SIZE - canvasSize) * 0.5);
    float2 canvasMax = canvasMin + canvasSize;
    float2 pixel = position.xy;

    if (any(pixel < canvasMin) || any(pixel >= canvasMax))
        return float4(0.0, 0.0, 0.0, 1.0);

    if (ShowCanvasOutline &&
        (any(pixel < canvasMin + 1.0) || any(pixel >= canvasMax - 1.0)))
        return float4(OutlineColor, 1.0);

    if (EnableInnerBorder)
    {
        float2 windowSize;
        if (WindowRatio == 7)
            windowSize = canvasSize * clamp(FreeWindowSize, 1.0, 100.0) * 0.01;
        else
            windowSize = FitRectangle(canvasSize, GetWindowRatio(ratio))
                * clamp(WindowScale, 1.0, 100.0) * 0.01;

        windowSize = clamp(floor(windowSize + 0.5), 1.0, canvasSize);
        float2 windowMin = canvasMin + floor((canvasSize - windowSize)
            * (clamp(WindowPosition, -1.0, 1.0) + 1.0) * 0.5);
        if (any(pixel < windowMin) || any(pixel >= windowMin + windowSize))
            return float4(BorderColor, 1.0);
    }

    return float4(tex2D(ReShade::BackBuffer, uv).rgb, 1.0);
}
}

technique AlbumFrame
<
    ui_label = "Album Frame - 专辑取景框";
    ui_tooltip = "居中最大化封面画板与内部留边。请放在效果列表末尾，使用包含效果的截图。";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = AlbumFrame::DrawFrame;
    }
}
