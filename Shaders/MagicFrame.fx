/*
Magic Frame v0.1 - portrait composition with depth-based foreground pop-out.
Copyright (c) 2026 VintageVelvet

MIT License

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

Canvas/window geometry reuses this project's MIT AlbumFrame mask helpers.
Depth compositing and the basic guides are implemented independently here.
Scene color and linear depth use the same original screen UV coordinates.
*/

#include "ReShade.fxh"

namespace MagicFrame
{
uniform int CanvasRatio <
    ui_type = "combo";
    ui_label = "画板比例";
    ui_items = "1:1\0 4:3\0 3:4\0 16:9\0 9:16\0 2:3\0自定义\0";
    ui_tooltip = "决定最终成片范围。画板始终居中、在屏幕内最大化；截图后沿画板边界裁切。";
    ui_category = "1. 成片画板";
> = 4;

uniform float2 CustomCanvasRatio <
    ui_type = "drag";
    ui_label = "自定义画板宽 : 高";
    ui_min = 0.1; ui_max = 32.0; ui_step = 0.1;
    ui_tooltip = "画板比例选择自定义时生效。";
    ui_category = "1. 成片画板";
> = float2(9.0, 16.0);

uniform float3 OutsideColor <
    ui_type = "color";
    ui_label = "画板外颜色";
    ui_tooltip = "裁图后舍弃的区域。与成片中的留边颜色独立，可用对比色辨认裁切边界。";
    ui_category = "1. 成片画板";
> = float3(0.18, 0.18, 0.18);

uniform bool EnableInnerBorder <
    ui_label = "启用内部留边";
    ui_tooltip = "关闭后内部窗口铺满画板；纯色背景仍可使用，画板范围不变。";
    ui_category = "2. 内部窗口";
> = true;

uniform int WindowRatio <
    ui_type = "combo";
    ui_label = "窗口形状";
    ui_items = "跟随画板\0 1:1\0 16:9\0 5:4\0 2:3\0 5:7\0自定义\0";
    ui_tooltip = "决定人物背后的背景窗口形状。自定义时分别设置占画板的宽度和高度。";
    ui_category = "2. 内部窗口";
> = 0;

uniform float WindowScale <
    ui_type = "slider";
    ui_label = "预设窗口大小 (%)";
    ui_min = 1.0; ui_max = 100.0; ui_step = 0.1;
    ui_tooltip = "跟随画板或固定比例时生效。等比缩放窗口，100% 为画板内可容纳的最大尺寸。";
    ui_category = "2. 内部窗口";
> = 80.0;

uniform float2 FreeWindowSize <
    ui_type = "slider";
    ui_label = "自定义窗口：宽度 / 高度 (%)";
    ui_min = 1.0; ui_max = 100.0; ui_step = 0.1;
    ui_tooltip = "仅窗口形状选择自定义时生效。分别占画板宽、高的百分比；100% 贴边。";
    ui_category = "2. 内部窗口";
> = float2(80.0, 80.0);

uniform float2 WindowPosition <
    ui_type = "slider";
    ui_label = "窗口位置（水平 / 垂直）";
    ui_min = -1.0; ui_max = 1.0; ui_step = 0.01;
    ui_tooltip = "0 居中，-1 贴左 / 上边，1 贴右 / 下边。只移动背景窗口；人物通过游戏镜头调整。";
    ui_category = "2. 内部窗口";
> = float2(0.0, 0.0);

uniform int BackgroundMode <
    ui_type = "combo";
    ui_label = "框内背景";
    ui_items = "原场景\0纯色\0";
    ui_tooltip = "原场景：窗口内保留游戏画面。纯色：用背景颜色替换远景，深度选中的近景仍保留。";
    ui_category = "3. 背景与留边";
> = 0;

uniform float3 WindowBackgroundColor <
    ui_type = "color";
    ui_label = "纯色背景颜色";
    ui_tooltip = "仅框内背景选择纯色时生效，不影响窗口外留边。";
    ui_category = "3. 背景与留边";
> = float3(0.85, 0.38, 0.65);

uniform float3 BorderColor <
    ui_type = "color";
    ui_label = "留边颜色";
    ui_tooltip = "画板内、背景窗口外的颜色。人物穿框时可覆盖这部分留边。";
    ui_category = "3. 背景与留边";
> = float3(0.0, 0.0, 0.0);

uniform bool EnablePopOut <
    ui_label = "允许人物越过窗口";
    ui_tooltip = "允许深度选中的近景覆盖窗口外留边。关闭时只限制越框，纯色背景窗口内的人物仍保留。";
    ui_category = "4. 深度穿框";
> = true;

uniform float WindowDepth <
    ui_type = "drag";
    ui_label = "窗口深度";
    ui_min = 0.0; ui_max = 1000.0; ui_step = 0.01;
    ui_tooltip = "ReShade 线性深度乘以 1000 的相对值，不是米。越小越靠近镜头。\n"
                 "调大可让更多近景保留；用前景选区检查人物完整、背景不过多露出。";
    ui_category = "4. 深度穿框";
> = 10.0;

uniform float DepthTransition <
    ui_type = "drag";
    ui_label = "深度过渡宽度";
    ui_min = 0.0; ui_max = 10.0; ui_step = 0.01;
    ui_tooltip = "与窗口深度使用相同单位。0 为直接分界；少量增大可缓和分界附近的混合。\n"
                 "这是深度过渡，不是轮廓模糊，也无法补回未写入深度的透明材质。";
    ui_category = "4. 深度穿框";
> = 0.0;

uniform int DisplayMode <
    ui_type = "combo";
    ui_label = "显示模式（拍摄前选正常画面）";
    ui_items = "正常画面\0前景选区\0深度预览\0";
    ui_tooltip = "前景选区：绿色表示画板内深度选中的近景，不受越框开关限制。\n"
                 "深度预览：近黑远白，以窗口深度为中灰。两种预览都会进入截图，拍前切回正常画面。";
    ui_category = "4. 深度穿框";
> = 0;

uniform int GuidePattern <
    ui_type = "combo";
    ui_label = "构图辅助";
    ui_items = "关闭\0中心线\0三等分\0窗口轮廓\0画板轮廓\0";
    ui_tooltip = "需要另外启用 Magic Frame Guides，并放在主效果后面。轮廓模式直接跟随对应矩形。";
    ui_category = "5. 构图辅助";
> = 2;

uniform int GuideArea <
    ui_type = "combo";
    ui_label = "中心 / 三等分参考区域";
    ui_items = "内部窗口\0整个画板\0";
    ui_tooltip = "仅中心线与三等分使用此项；窗口轮廓和画板轮廓分别使用其对应区域。";
    ui_category = "5. 构图辅助";
> = 0;

uniform float4 GuideColor <
    ui_type = "color";
    ui_label = "辅助线颜色与透明度 (RGBA)";
    ui_category = "5. 构图辅助";
> = float4(1.0, 1.0, 1.0, 0.7);

uniform float GuideWidth <
    ui_type = "slider";
    ui_label = "辅助线宽度（像素）";
    ui_min = 0.0; ui_max = 5.0; ui_step = 0.1;
    ui_tooltip = "水平 / 垂直线的总宽度；轮廓向矩形内部绘制。0 时隐藏所有辅助线。";
    ui_category = "5. 构图辅助";
> = 1.0;

float GetCanvasRatio()
{
    if (CanvasRatio == 1) return 4.0 / 3.0;
    if (CanvasRatio == 2) return 3.0 / 4.0;
    if (CanvasRatio == 3) return 16.0 / 9.0;
    if (CanvasRatio == 4) return 9.0 / 16.0;
    if (CanvasRatio == 5) return 2.0 / 3.0;
    if (CanvasRatio == 6)
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
    // Integer half-open bounds match the documented post-screenshot crop.
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

bool InRectangle(float2 pixel, float2 rectMin, float2 rectSize)
{
    return all(pixel >= rectMin) && all(pixel < rectMin + rectSize);
}

float ForegroundWeight(float depth)
{
    float threshold = clamp(WindowDepth, 0.0, 1000.0) * 0.001;
    float transition = max(DepthTransition, 0.0) * 0.001;
    // A zero-width transition must not call smoothstep with equal endpoints.
    if (transition <= 0.0)
        return depth < threshold ? 1.0 : 0.0;
    return 1.0 - smoothstep(threshold - transition * 0.5,
                            threshold + transition * 0.5, depth);
}

float4 DrawFrame(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float2 canvasMin, canvasSize, windowMin, windowSize;
    GetRectangles(canvasMin, canvasSize, windowMin, windowSize);
    // The final crop boundary always takes priority, including in previews.
    if (!InRectangle(position.xy, canvasMin, canvasSize))
        return float4(OutsideColor, 1.0);

    float3 scene = tex2D(ReShade::BackBuffer, uv).rgb;
    float depth = ReShade::GetLinearizedDepth(uv);
    float foreground = ForegroundWeight(depth);

    if (DisplayMode == 1)
    {
        float luminance = dot(scene, float3(0.2126, 0.7152, 0.0722));
        float3 selected = lerp(scene, float3(0.12, 1.0, 0.24), 0.6);
        return float4(lerp(luminance * 0.35, selected, foreground), 1.0);
    }
    if (DisplayMode == 2)
    {
        float previewRange = max(clamp(WindowDepth, 0.0, 1000.0) * 0.002, 0.000001);
        float preview = saturate(depth / previewRange);
        return float4(preview, preview, preview, 1.0);
    }

    bool inWindow = InRectangle(position.xy, windowMin, windowSize);
    if (inWindow)
    {
        if (BackgroundMode == 0)
            return float4(scene, 1.0);
        // Solid backgrounds need foreground depth even when pop-out is off.
        return float4(lerp(WindowBackgroundColor, scene, foreground), 1.0);
    }
    return float4(lerp(BorderColor, scene, EnablePopOut ? foreground : 0.0), 1.0);
}

bool OnGuideAxes(float2 pixel, float2 center, float width)
{
    float2 offset = pixel - center;
    float halfWidth = width * 0.5;
    // Half-open spans avoid doubling a 1-pixel line at integer boundaries.
    return (offset.x >= -halfWidth && offset.x < halfWidth)
        || (offset.y >= -halfWidth && offset.y < halfWidth);
}

float4 DrawGuides(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 scene = tex2D(ReShade::BackBuffer, uv);
    if (GuidePattern == 0 || GuideWidth <= 0.0 || GuideColor.a <= 0.0)
        return scene;

    float2 canvasMin, canvasSize, windowMin, windowSize;
    GetRectangles(canvasMin, canvasSize, windowMin, windowSize);
    bool useCanvas = GuidePattern == 4 || (GuidePattern < 3 && GuideArea == 1);
    float2 targetMin = useCanvas ? canvasMin : windowMin;
    float2 targetSize = useCanvas ? canvasSize : windowSize;
    if (!InRectangle(position.xy, targetMin, targetSize))
        return scene;

    float2 pixel = position.xy - targetMin;
    bool onLine = false;
    if (GuidePattern == 1)
        onLine = OnGuideAxes(pixel, targetSize * 0.5, GuideWidth);
    else if (GuidePattern == 2)
        onLine = OnGuideAxes(pixel, targetSize / 3.0, GuideWidth)
            || OnGuideAxes(pixel, targetSize * (2.0 / 3.0), GuideWidth);
    else
    {
        float2 edgeDistance = min(pixel, targetSize - pixel);
        onLine = min(edgeDistance.x, edgeDistance.y) <= GuideWidth;
    }
    return onLine ? float4(lerp(scene.rgb, GuideColor.rgb, saturate(GuideColor.a)), scene.a) : scene;
}
} // namespace MagicFrame

technique MagicFrame
<
    ui_label = "Magic Frame - 魔法取景框";
    ui_tooltip = "竖幅画板、背景窗口与深度穿框。放在调色 / 景深之后，Magic Frame Guides 之前。\n"
                 "从原场景模式调好人物和窗口深度，再试纯色背景。拍摄前将显示模式切回正常画面。";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = MagicFrame::DrawFrame;
    }
}

technique MagicFrame_Guides
<
    ui_label = "Magic Frame Guides - 魔法取景构图线（ReShade 截图隐藏）";
    enabled_in_screenshot = false;
    ui_tooltip = "与 Magic Frame 一起启用，并排在它之后。ReShade 自身截图隐藏辅助线，保留主效果。\n"
                 "游戏截图、系统截图和录屏仍包含可见辅助线；拍前可关闭此效果。";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = MagicFrame::DrawGuides;
    }
}
