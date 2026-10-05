// CopyrightAdaptive: independent resolution-adaptive derivative of Copyright.fx.
// Keeps upstream author credits and original style IDs for available textures.
// Adaptive additions maintained for VintageVelvet, 2026. Original PNG assets are supplied by the user installation.
/*------------------.
| :: Description :: |
'-------------------/

    Copyright (based on Layer) (version 1.1)

    Authors: CeeJay.dk, seri14, Marot Satil, uchu suzume, prod80, originalnicodr
    License: MIT

    About:
    Blends an image with the game.
    The idea is to give users with graphics skills the ability to create effects using a layer just like in an image editor.
    Maybe they could use this to create custom CRT effects, custom vignettes, logos, custom hud elements, toggable help screens and crafting tables or something I haven't thought of.

    History:
    (*) Feature (+) Improvement (x) Bugfix (-) Information (!) Compatibility

    Version 0.2 by seri14 & Marot Satil
    * Added the ability to scale and move the layer around on an x, y axis.

    Version 0.3 by seri14
    * Reduced the problem of layer color is blending with border color

    Version 0.4 by seri14 & Marot Satil
    * Added support for the additional seri14 DLL preprocessor options to minimize loaded textures.

    Version 0.5 by uchu suzume & Marot Satil
    * Rotation added.

    Version 0.6 by uchu suzume & Marot Satil
    * Added multiple blending modes thanks to the work of uchu suzume, prod80, and originalnicodr.

    Version 0.7 by uchu suzume & Marot Satil
    * Added Addition, Subtract, Divide blending modes.

    Version 0.8 by uchu suzume & Marot Satil
    * Sorted blending modes in a more logical fashion, grouping by type.

    Version 0.9 by uchu suzume
    * Added some texures.
    * Fixed blend option applying correctly to alpha pixels by changing the order of code blocks.
    * Add space of UI and collapsed some parameters for visibility.
    * Changed the order of parameter in snap rotate.
    * Experimental features added:
         * Coloring textures(invert, any color for white / black pixels).
         * Move texture to mouse position.
         * Merge and blend background pixels into logo texture(Not sure I said it correctly in English).
         * Added layer with Gaussian blur can be used for drop shadows or bloom.
         * Added chromatic aberration layer with gaussian blur.

    Version 1.0 by Marot Satil & uchu suzume
    + Implemented Blending.fxh preprocessor macros.

    Version 1.1 by Marot Satil & uchu suzume
    + Implemented game-based *Tex.fxh headers containing preprocessor macros along with supported game auto-detection.
    * Added a gaussian blur radius option that allows you to adjust the applied area.
    * Improved the accuracy of the BG Blend mode option.

    Version 1.2 by uchu suzume
    * Added scale option to gaussian layer.
    * Added more blending option to CAb layer.
    * Added Custom List.
    + Adjusted default value of CAb to more natural look and usable.
    + Adjusted gaussian blur radius opiton #3 to reduce afterglow.
    + Expanded moving range of Gaussian layer.
    + Improved the formulas of Gaussian and CAb layers to keep the coordinate base even after rotation.

    Version 1.3 by uchu suzume
    + Improved formula for recolor.

    Version 1.4 by Marot Satil & uchu suzume
    + Implemented new recolor method of changing two colors individually.
    + Color pickers are switched for in/out as needed depending on the status of recolor option.
    + Moved inversion option in recolor from a drop-down box to a single check box.

    Version 1.5 by Marot Satil & uchu suzume
    x Fixed incorrect declaration of arguments in Texture combo.
*/

// Chinese Translation by BarricadeMKXX <liu.xd1998@outlook.com>
// Also modified for ReShade usage, BUT NOT SO GOOD IN GSHADE NOW!!

#include "ReShade.fxh"
#include "Blending.fxh"


#ifndef CopyrightAdaptiveTex
#define COPYRIGHTADAPTIVE_CUSTOM_TEXTURE_PROVIDED 0
#define CopyrightAdaptiveTex "cLayerA.png" // Add your own image file to \reshade-shaders\Textures\ and provide the new file name in quotes to change the image displayed!
#else
#define COPYRIGHTADAPTIVE_CUSTOM_TEXTURE_PROVIDED 1
#endif
#ifndef CopyrightAdaptive_SIZE_X
#define CopyrightAdaptive_SIZE_X BUFFER_WIDTH
#define COPYRIGHTADAPTIVE_CUSTOM_X_USES_BUFFER 1
#else
#define COPYRIGHTADAPTIVE_CUSTOM_X_USES_BUFFER 0
#endif
#ifndef CopyrightAdaptive_SIZE_Y
#define CopyrightAdaptive_SIZE_Y BUFFER_HEIGHT
#define COPYRIGHTADAPTIVE_CUSTOM_Y_USES_BUFFER 1
#else
#define COPYRIGHTADAPTIVE_CUSTOM_Y_USES_BUFFER 0
#endif

#if CopyrightAdaptive_SINGLECHANNEL
#define TEXFORMAT R8
#else
#define TEXFORMAT RGBA8
#endif

#ifndef CopyrightAdaptive_TEXTURE_SELECTION
    #define CopyrightAdaptive_TEXTURE_SELECTION 0
#endif
#if CopyrightAdaptive_TEXTURE_SELECTION < 0 || CopyrightAdaptive_TEXTURE_SELECTION > 2
    #undef CopyrightAdaptive_TEXTURE_SELECTION
    #define CopyrightAdaptive_TEXTURE_SELECTION 0
#endif

#if CopyrightAdaptive_TEXTURE_SELECTION == 0
  #include "CopyrightAdaptive/CopyrightTex_XIV_AUR.fxh"
#elif CopyrightAdaptive_TEXTURE_SELECTION == 1
  #include "CopyrightAdaptive/CopyrightTex_XIV.fxh"
#elif CopyrightAdaptive_TEXTURE_SELECTION == 2
  #include "CopyrightAdaptive/CopyrightTex_Custom.fxh"
#endif

uniform int cLayer_SelectGame <
    ui_label = "列表选择";
    ui_tooltip = "选择版权标志系列。\n原版ReShade中不可用。AuroraShade/ReShade-CN2用户请在面板右上角启用ui_bind支持。\n如果更改没有生效，请记住这里每个选项中的数字，然后找到预处理器定义中的`CopyrightAdaptive_TEXTURE_SELECTION`填入。";
    ui_category = "列表选择";
    ui_type = "combo";
    ui_items = " 0- 最终幻想14 x AuroraShade/ReShade-CN2\0"
               " 1- 最终幻想14\0"
               " 2- 自定义\0"
               ;
    ui_bind = "CopyrightAdaptive_TEXTURE_SELECTION";
> = CopyrightAdaptive_TEXTURE_SELECTION;

COPYRIGHTADAPTIVE_TEXTURE_COMBO(
    CopyrightAdaptive_Select,
    "版权标志选择",
    "选择所需的图像/纹理，缺少素材的款式已从菜单移除。\nAuroraShade/ReShade-CN2用户请在面板右上角启用ui_bind支持。\n标准ReShade可用CopyrightAdaptive_Texture_Source填写标签中的原款式编号；手动填写前清除CopyrightAdaptive_Menu_Source。"
);

// 分辨率适配试用：以基准画面高度保持水印占画面的比例。
uniform bool cLayer_ResolutionAdaptive <
    ui_label = "随分辨率缩放";
    ui_tooltip = "开启后，水印大小随当前渲染高度缩放。\n从2560×1440切到3840×2160时自动放大1.5倍，恢复原分辨率时自动还原。\n适用于内置水印及指定了固定尺寸的自定义水印。\n手动指定Custom 47且未指定宽高时，按画面尺寸绘制，不重复放大。\n关闭后保留原版尺寸规则。";
    ui_category = "分辨率适配";
> = true;

uniform float cLayer_ReferenceHeight <
    ui_label = "基准画面高度（像素）";
    ui_tooltip = "填写原来调整水印时的画面高度。\n2560×1440使用1440；1920×1080使用1080。";
    ui_category = "分辨率适配";
    ui_type = "drag";
    ui_min = 1.0; ui_max = 8640.0;
    ui_step = 1.0;
> = 1440.0;

uniform float cLayer_Scale <
    ui_label = "缩放";
    ui_tooltip = "若需要更大的缩放范围，可以使用下面的横纵缩放选项。\n过度缩放可能会降低纹理质量。";
    ui_type = "slider";
    ui_min = 0.500; ui_max = 1.0;
    ui_step = 0.001;
> = 0.780;

 uniform float cLayer_ScaleX <
    ui_label = "水平缩放";
    ui_category = "横纵缩放";
    ui_category_closed = true;
    ui_type = "slider";
    ui_min = 0.001; ui_max = 5.0;
    ui_step = 0.001;
> = 1.0;

 uniform float cLayer_ScaleY <
    ui_label = "垂直缩放";
    ui_category = "横纵缩放";
    ui_type = "slider";
    ui_min = 0.001; ui_max = 5.0;
    ui_step = 0.001;
> = 1.0;


uniform bool  cLayer_Mouse <
    ui_label = "跟随鼠标";
    ui_tooltip = "右键点击标志使标志纹理自动跟随鼠标指针。\n再次右键返回到坐标模式。";
    ui_spacing = 2;
> = false;

uniform float cLayer_PosX <
    ui_label = "水平位置";
    ui_tooltip = "纹理的水平位置。\n坐标轴以屏幕左上角为原点。";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.001;
> = 0.680;

uniform float cLayer_PosY <
    ui_label = "垂直位置";
    ui_tooltip = "纹理的垂直位置。\n坐标轴以屏幕左上角为原点。";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.001;
> = 0.970;

uniform int cLayer_SnapRotate <
    ui_label = "快捷旋转";
    ui_tooltip = "快捷旋转至特定角度。\n按下方向键以在相应方向旋转90度。";
    ui_type = "combo";
    ui_spacing = 2;
    ui_items = "-90 度\0"
               "0 度\0"
               "90 度\0"
               "180 度\0"
               ;
> = 1;

uniform float cLayer_Rotate <
    ui_label = "旋转";
    ui_tooltip = "旋转纹理至指定角度。";
    ui_type = "slider";
    ui_min = -180.0;
    ui_max = 180.0;
    ui_step = 0.01;
> = 0;


uniform bool cLayer_Color_Invert <
    ui_label = "反转颜色";
    ui_tooltip = "反转所有颜色。";
    ui_spacing = 2;
> = 0;

// #ifndef cLayer_COLOR_OVERRIDE_COMBO
//     #define cLayer_COLOR_OVERRIDE_COMBO 0
// #endif

uniform int cLayer_Color_Override <
    ui_label = "重新着色";
    ui_tooltip = "将黑色/白色区域染为其他颜色。";
    ui_type = "combo";
    ui_items = "无\0"
               "白色区域重新着色为颜色A\0"
               "黑色区域重新着色为颜色B\0"
               "白色->颜色A，黑色->颜色B\0"
               "白色&黑色->颜色A\0"
               ;
    //ui_bind = "cLayer_COLOR_OVERRIDE_COMBO";
> = 0;

uniform float2 ColorOverrideThreshold <
    ui_label = "重新着色阈值";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "识别为黑/白色的阈值。\n(0, 1)为严格模式，只调节纯黑纯白，第一个值大于第二个值为宽松模式，调节所有颜色。\n原版Copyright默认为宽松模式。";
> = float2(0.0, 1.0);

//#if cLayer_COLOR_OVERRIDE_COMBO > 0
uniform float3 ColorOverrideA <
    ui_label = "颜色A";
    ui_tooltip = "重新着色使用的颜色。";
    ui_type = "color";
> = float3(1.0, 1.0, 1.0);
//#endif

//#if cLayer_COLOR_OVERRIDE_COMBO == 3
uniform float3 ColorOverrideB <
    ui_label = "颜色B";
    ui_tooltip = "重新着色使用的颜色。";
    ui_type = "color";
> = float3(0.0, 0.0, 0.0);
//#endif


BLENDING_COMBO(
    cLayer_BlendMode,
    "混合模式",
    "选择应用到纹理的混合模式。",
    "",
    false,
    2,
    0
);

uniform float cLayer_Blend <
    ui_label = "混合量";
    ui_tooltip = "应用到纹理的混合程度。";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.001;
> = 1.0;


uniform float Gauss_Blend <
    ui_label = "高斯图层混合量";
    ui_tooltip = "应用到高斯图层的混合程度。";
    ui_category = "高斯图层";
    ui_category_closed = true;
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 3.0;
    ui_step = 0.001;
> = 0.0;

uniform float cLayer_PosX_Gauss <
    ui_label = "高斯图层水平偏移";
    ui_tooltip = "高斯图层基于纹理坐标的水平偏移。";
    ui_category = "高斯图层";
    ui_type = "slider";
    ui_spacing = 2;
    ui_min = -0.35; ui_max = 0.35;
    ui_step = 0.001;
> = 0.025;

uniform float cLayer_PosY_Gauss <
    ui_label = "高斯图层垂直偏移";
    ui_tooltip = "高斯图层基于纹理坐标的垂直偏移。";
    ui_category = "高斯图层";
    ui_type = "slider";
    ui_min = -0.35; ui_max = 0.35;
    ui_step = 0.001;
> = 0.050;

uniform float cLayer_Scale_Gauss <
    ui_label = "高斯图层缩放";
    ui_tooltip = "高斯图层缩放。";
    ui_category = "高斯图层";
    ui_type = "slider";
    ui_min = 0.75; ui_max = 1.5;
    ui_step = 0.001;
> = 1.000;

uniform int GaussianBlurRadius <
    ui_label = "高斯模糊半径";
    ui_tooltip = "[0|1|2|3] 调整模糊半径。\n各个值适用于不同尺寸的标志。设为3可能有一定挑战。";
    ui_category = "高斯图层";
    ui_type = "slider";
    ui_spacing = 2;
    ui_min = 0;
    ui_max = 3;
    ui_step = 1;
> = 1;

uniform float GaussWeight <
    ui_label = "高斯权重";
    ui_tooltip = "高斯模糊的权重。增加该值会增加模糊。";
    ui_category = "高斯图层";
    ui_type = "slider";
    ui_min = 0.001;
    ui_max = 3.0;
    ui_step = 0.001;
> = 0.600;

uniform float GaussWeightH <
    ui_label = "水平高斯权重";
    ui_tooltip = "高斯模糊的权重。增加该值会增加模糊。";
    ui_category = "高斯图层";
    ui_type = "slider";
    ui_min = 0.001;
    ui_max = 10.0;
    ui_step = 0.001;
> = 0.001;

uniform float GaussWeightV <
    ui_label = "垂直高斯权重";
    ui_tooltip = "高斯模糊的权重。增加该值会增加模糊。";
    ui_category = "高斯图层";
    ui_type = "slider";
    ui_min = 0.001;
    ui_max = 10.0;
    ui_step = 0.001;
> = 0.001;

uniform float3 GaussColor <
    ui_label = "高斯图层";
    ui_tooltip = "应用于高斯图层的颜色。";
    ui_category = "高斯图层";
    ui_type = "color";
    ui_spacing = 2;
    ui_tooltip = "阴影图层的颜色。";
> = float3(0.0, 0.0, 0.0);

BLENDING_COMBO(
    cLayer_BlendMode_Gauss,
    "高斯图层混合模式",
    "选择应用于高斯图层的混合模式。",
    "高斯图层",
    false,
    2,
    0
);


BLENDING_COMBO(
    cLayer_BlendMode_BG,
    "背景混合模式",
        "选择应用于背景纹理的混合模式。\n\
    - 备注 -   \n使用该模式时，需要减少标志纹理的混合程度。\n此模式的优先级被设为稍后。",
    "背景混合模式",
    false,
    2,
    0
);

uniform float cLayer_Blend_BG <
    ui_label = "背景混合量";
    ui_tooltip = "应用于背景纹理的混合量。";
    ui_category = "背景混合模式";
    ui_category_closed = true;
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.001;
> = 0.0;


uniform float4 cLayer_CAb_Color_A <
    ui_label = "色差 颜色A";
    ui_tooltip = "应用于色差图层的颜色。";
    ui_category = "色差";
    ui_category_closed = true;
    ui_type = "color";
> = float4(1.0, 0.0, 0.0, 1.0);

uniform float4 cLayer_CAb_Color_B <
    ui_label = "色差 颜色B";
    ui_tooltip = "应用于色差图层的颜色。";
    ui_category = "色差";
    ui_type = "color";
> = float4(0.0, 1.0, 1.0, 1.0);

uniform float2 cLayer_CAb_Shift <
    ui_label = "色差移位";
    ui_tooltip = "色差效果的程度。";
    ui_category = "色差";
    ui_type = "slider";
    ui_min = -0.2;
    ui_max = 0.2;
    > = float2(0.015, -0.015);

uniform float cLayer_CAb_Strength <
    ui_label = "色差强度";
    ui_tooltip = "色差图层的混合量。";
    ui_category = "色差";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.0;

uniform float cLayer_CAb_Blur <
    ui_label = "色差模糊";
    ui_tooltip = "色差图层的简易模糊。";
    ui_category = "色差";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.5;
> = 0.015;

uniform int cLayer_BlendMode_CAb <
    ui_label = "色差混合模式";
    ui_tooltip = "选择应用于色差图层的混合模式。\n观感因背景亮度而异。";
    ui_category = "色差";
    ui_type = "combo";
    ui_items = "滤色\0"
               "线性减淡\0"
               "辉光\0"
               "线性光\0"
               "颜色\0"
               "颗粒合并\0"
               "划分\0"
               "划分 (替代)\0"
               "普通\0"
               ;
> = 0;


uniform float cLayer_Depth <
    ui_label = "深度位置";
    ui_type = "slider";
    ui_tooltip = "将纹理置于角色或地形等后面。";
    ui_spacing = 2;
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.001;
> = 1.0;

uniform float2 MouseCoords < source = "mousepoint"; >;
uniform bool LeftMouseDown < source = "mousebutton"; keycode = 0; toggle = true; >;
uniform bool RightMouseDown < source = "mousebutton"; keycode = 1; toggle = true; >;


// If you get an error about COPYRIGHTADAPTIVE_SOURCE_FILE, check to make sure you're not missing a referenced *Tex.fxh game header.
texture CopyrightAdaptive_Texture <
    source = COPYRIGHTADAPTIVE_SOURCE_FILE;
> {
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA8;
};

texture CopyrightAdaptive_Texture_Gauss_H
{
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
};

texture CopyrightAdaptive_Texture_Gauss_V
{
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
};

texture CopyrightAdaptive_Texture_Gauss_Out
{
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
};

texture CopyrightAdaptive_Texture_CAb_Gauss_H
{
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
};

texture CopyrightAdaptive_Texture_CAb_Gauss_Out
{
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
};

texture CopyrightAdaptive_Texture_CAb_A
{
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
};

texture CopyrightAdaptive_Texture_CAb_B
{
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
};

sampler CopyrightAdaptive_Sampler
{
    Texture = CopyrightAdaptive_Texture;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

sampler CopyrightAdaptive_Sampler_Gauss_H
{
    Texture = CopyrightAdaptive_Texture_Gauss_H;
};

sampler CopyrightAdaptive_Sampler_Gauss_V
{
    Texture = CopyrightAdaptive_Texture_Gauss_Out;
};

sampler CopyrightAdaptive_Sampler_CAb_Gauss_H
{
    Texture = CopyrightAdaptive_Texture_CAb_Gauss_H;
};

sampler CopyrightAdaptive_Sampler_CAb_Gauss_V
{
    Texture = CopyrightAdaptive_Texture_CAb_Gauss_Out;
};

sampler CopyrightAdaptive_Sampler_CAb_A
{
    Texture = CopyrightAdaptive_Texture_CAb_A;
};

sampler CopyrightAdaptive_Sampler_CAb_B
{
    Texture = CopyrightAdaptive_Texture_CAb_B;
};

// -------------------------------------
// Entrypoints
// -------------------------------------

#define PIXEL_SIZE float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)

#define pivot float3(0.5, 0.5, 0.0)
#define mulUV float3(texCoord.x, texCoord.y, 1)
#define CopyrightAdaptiveResolutionScale (cLayer_ResolutionAdaptive ? (BUFFER_HEIGHT / max(cLayer_ReferenceHeight, 1.0)) : 1.0)

// Custom 47 defaults already use the current frame size. Compensate only explicitly fixed dimensions.
#if CopyrightAdaptive_TEXTURE_SELECTION == 0 && COPYRIGHTADAPTIVE_EFFECTIVE_SOURCE == 47 && COPYRIGHTADAPTIVE_CUSTOM_X_USES_BUFFER
    #define COPYRIGHTADAPTIVE_SCALE_X 1.0
#else
    #define COPYRIGHTADAPTIVE_SCALE_X CopyrightAdaptiveResolutionScale
#endif
#if CopyrightAdaptive_TEXTURE_SELECTION == 0 && COPYRIGHTADAPTIVE_EFFECTIVE_SOURCE == 47 && COPYRIGHTADAPTIVE_CUSTOM_Y_USES_BUFFER
    #define COPYRIGHTADAPTIVE_SCALE_Y 1.0
#else
    #define COPYRIGHTADAPTIVE_SCALE_Y CopyrightAdaptiveResolutionScale
#endif
#define CopyrightAdaptiveResolutionScaleXY float2(COPYRIGHTADAPTIVE_SCALE_X, COPYRIGHTADAPTIVE_SCALE_Y)
#define ScaleSize float2(float2(COPYRIGHTADAPTIVE_SOURCE_SIZE) * cLayer_Scale * CopyrightAdaptiveResolutionScaleXY)
#define ScaleX float(ScaleSize.x * cLayer_ScaleX)
#define ScaleY float(ScaleSize.y * cLayer_ScaleY)
#define PosX float(cLayer_Mouse && RightMouseDown? MouseCoords.x * BUFFER_PIXEL_SIZE.x : cLayer_PosX)
#define PosY float(cLayer_Mouse && RightMouseDown? MouseCoords.y * BUFFER_PIXEL_SIZE.y : cLayer_PosY)
#define PosX_Gauss float(cLayer_PosX_Gauss * 0.1)
#define PosY_Gauss float(cLayer_PosY_Gauss * 0.1)
#define ScaleSize_Gauss float2(float2(COPYRIGHTADAPTIVE_SOURCE_SIZE) * ((cLayer_Scale) + (-1 + cLayer_Scale_Gauss)) * CopyrightAdaptiveResolutionScaleXY)
#define ScaleX_Gauss float(ScaleSize_Gauss.x)
#define ScaleY_Gauss float(ScaleSize_Gauss.y)


float3x3 positionMatrix (in float coord_X, in float coord_Y) {
    return float3x3 (
    1, 0, 0,
    0, 1, 0,
    -coord_X, -coord_Y, 1
    );
}

float3x3 scaleMatrix (in float width_X, in float width_Y) {
    return float3x3 (
        1/width_X, 0, 0,
        0,  1/width_Y, 0,
        0, 0, 1
    );
}

float3x3 rotateMatrix (in float angle) {
    float Rotate = angle * (3.1415926 / 180.0);
    switch(cLayer_SnapRotate)
    {
        case 0:
            Rotate = (angle * (3.1415926 / 180.0)) + (-90.0 * (3.1415926 / 180.0));
            break;
        case 1:
            break;
        case 2:
            Rotate = (angle * (3.1415926 / 180.0)) + (90.0 * (3.1415926 / 180.0));
            break;
        case 3:
            Rotate = (angle * (3.1415926 / 180.0)) + (180.0 * (3.1415926 / 180.0));
            break;
    }

    return float3x3 (
    cos(Rotate), -sin(Rotate), 0,
    sin(Rotate), cos(Rotate), 0,
    0, 0, 1
    );
}

float3x3 rotateMatrix_Alt (in float angle) {
    return float3x3 (
    cos(angle), -sin(angle), 0,
    sin(angle), cos(angle), 0,
    0, 0, 1
    );
}


float4 PS_cLayer_Gauss_H(in float4 pos : SV_Position, in float2 texCoord : TEXCOORD) : COLOR  {

        float4 color = tex2D(CopyrightAdaptive_Sampler_Gauss_V, texCoord);
        switch(GaussianBlurRadius)
        {
             default:
                 const float sampleOffsets[4] = { 0.0, 1.1824255238, 3.0293122308, 5.0040701377 };
                 const float sampleWeights[4] = { 0.39894, 0.2959599993, 0.0045656525, 0.00000149278686458842 };
                 color *= sampleWeights[0];
                 for(int i = 1; i < 4; ++i)
                 {
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_V, float4(texCoord + float2(sampleOffsets[i] * (GaussWeight * (GaussWeightH + 0.5)) * PIXEL_SIZE.x, 0.0), 0.0, 0.0)) * sampleWeights[i];
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_V, float4(texCoord - float2(sampleOffsets[i] * (GaussWeight * (GaussWeightH + 0.5)) * PIXEL_SIZE.x, 0.0), 0.0, 0.0)) * sampleWeights[i];
                 }
                 break;
             case 1:
                 const float sampleOffsets[6] = { 0.0, 1.4584295168, 3.40398480678, 5.3518057801, 7.302940716, 9.2581597095 };
                 const float sampleWeights[6] = { 0.13298, 0.23227575, 0.1353261595, 0.0511557427, 0.01253922, 0.0019913644 };
                 color *= sampleWeights[0];
                 for(int i = 1; i < 6; ++i)
                 {
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_V, float4(texCoord + float2(sampleOffsets[i] * (GaussWeight * (GaussWeightH + 0.5)) * PIXEL_SIZE.x, 0.0), 0.0, 0.0)) * sampleWeights[i];
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_V, float4(texCoord - float2(sampleOffsets[i] * (GaussWeight * (GaussWeightH + 0.5)) * PIXEL_SIZE.x, 0.0), 0.0, 0.0)) * sampleWeights[i];
                 }
                 break;
             case 2:
                 const float sampleOffsets[11] = { 0.0, 1.4895848401, 3.4757135714, 5.4618796741, 7.4481042327, 9.4344079746, 11.420811147, 13.4073334, 15.3939936778, 17.3808101174, 19.3677999584 };
                 const float sampleWeights[11] = { 0.06649, 0.1284697563, 0.111918249, 0.0873132676, 0.0610011113, 0.0381655709, 0.0213835661, 0.0107290241, 0.0048206869, 0.0019396469, 0.0006988718 };
                 color *= sampleWeights[0];
                 for(int i = 1; i < 11; ++i)
                 {
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_V, float4(texCoord + float2(sampleOffsets[i] * (GaussWeight * (GaussWeightH + 0.5)) * PIXEL_SIZE.x, 0.0), 0.0, 0.0)) * sampleWeights[i];
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_V, float4(texCoord - float2(sampleOffsets[i] * (GaussWeight * (GaussWeightH + 0.5)) * PIXEL_SIZE.x, 0.0), 0.0, 0.0)) * sampleWeights[i];
                 }
                 break;
             case 3:
                 const float sampleOffsets[6] = { 0.0, 0.25, 0.50, 0.75, 1.00, 1.25 };
                 const float sampleWeights[6] = { 0.15, 0.25, 0.135, 0.055, 0.0135, 0.0015 };
                 color *= sampleWeights[0];
                 for(int i = 1; i < 6; ++i)
                 {
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_V, float4(texCoord + float2(sampleOffsets[i] * (GaussWeight * (GaussWeightH + 0.5)) * PIXEL_SIZE.x, 0.0), 0.0, 0.0)) * sampleWeights[i];
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_V, float4(texCoord - float2(sampleOffsets[i] * (GaussWeight * (GaussWeightH + 0.5)) * PIXEL_SIZE.x, 0.0), 0.0, 0.0)) * sampleWeights[i];
                 }
                 break;
        }
        color.rgb = (GaussColor.rgb);
        return color;
}

float4 PS_cLayer_Gauss_V(in float4 pos : SV_Position, in float2 texCoord : TEXCOORD) : COLOR  {

        const float3 SumUV = mul (mul (mul (mulUV, positionMatrix(0.5 + PosX_Gauss, 0.5 + PosY_Gauss)), rotateMatrix_Alt(0)) * float3(BUFFER_SCREEN_SIZE, 1.0f), scaleMatrix(ScaleX_Gauss, ScaleY_Gauss));
        float4 color = tex2D(CopyrightAdaptive_Sampler, SumUV.rg + pivot.rg);
        switch(GaussianBlurRadius)
        {
             default:
                 const float sampleOffsets[4] = { 0.0, 1.1824255238, 3.0293122308, 5.0040701377 };
                 const float sampleWeights[4] = { 0.39894, 0.2959599993, 0.0045656525, 0.00000149278686458842 };
                 color *= sampleWeights[0];
                 for(int i = 1; i < 4; ++i)
                 {
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_H, float4(texCoord + float2(0.0, sampleOffsets[i] * (GaussWeight * (GaussWeightV + 0.5)) * PIXEL_SIZE.y), 0.0, 0.0)) * sampleWeights[i];
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_H, float4(texCoord - float2(0.0, sampleOffsets[i] * (GaussWeight * (GaussWeightV + 0.5)) * PIXEL_SIZE.y), 0.0, 0.0)) * sampleWeights[i];
                 }
                 break;
             case 1:
                 const float sampleOffsets[6] = { 0.0, 1.4584295168, 3.40398480678, 5.3518057801, 7.302940716, 9.2581597095 };
                 const float sampleWeights[6] = { 0.13298, 0.23227575, 0.1353261595, 0.0511557427, 0.01253922, 0.0019913644 };
                 color *= sampleWeights[0];
                 for(int i = 1; i < 6; ++i)
                 {
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_H, float4(texCoord + float2(0.0, sampleOffsets[i] * (GaussWeight * (GaussWeightV + 0.5)) * PIXEL_SIZE.y), 0.0, 0.0)) * sampleWeights[i];
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_H, float4(texCoord - float2(0.0, sampleOffsets[i] * (GaussWeight * (GaussWeightV + 0.5)) * PIXEL_SIZE.y), 0.0, 0.0)) * sampleWeights[i];
                 }
                 break;
             case 2:
                 const float sampleOffsets[11] = { 0.0, 1.4895848401, 3.4757135714, 5.4618796741, 7.4481042327, 9.4344079746, 11.420811147, 13.4073334, 15.3939936778, 17.3808101174, 19.3677999584 };
                 const float sampleWeights[11] = { 0.06649, 0.1284697563, 0.111918249, 0.0873132676, 0.0610011113, 0.0381655709, 0.0213835661, 0.0107290241, 0.0048206869, 0.0019396469, 0.0006988718 };
                 color *= sampleWeights[0];
                 for(int i = 1; i < 11; ++i)
                 {
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_H, float4(texCoord + float2(0.0, sampleOffsets[i] * (GaussWeight * (GaussWeightV + 0.5)) * PIXEL_SIZE.y), 0.0, 0.0)) * sampleWeights[i];
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_H, float4(texCoord - float2(0.0, sampleOffsets[i] * (GaussWeight * (GaussWeightV + 0.5)) * PIXEL_SIZE.y), 0.0, 0.0)) * sampleWeights[i];
                 }
                 break;
             case 3:
                 const float sampleOffsets[6] = { 0.0, 0.25, 0.50, 0.75, 1.00, 1.25 };
                 const float sampleWeights[6] = { 0.15, 0.25, 0.135, 0.055, 0.0135, 0.0015 };
                 color *= sampleWeights[0];
                 for(int i = 1; i < 6; ++i)
                 {
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_H, float4(texCoord + float2(0.0, sampleOffsets[i] * (GaussWeight * (GaussWeightV + 0.5)) * PIXEL_SIZE.y), 0.0, 0.0)) * sampleWeights[i];
                 color += tex2Dlod(CopyrightAdaptive_Sampler_Gauss_H, float4(texCoord - float2(0.0, sampleOffsets[i] * (GaussWeight * (GaussWeightV + 0.5)) * PIXEL_SIZE.y), 0.0, 0.0)) * sampleWeights[i];
                 }
                 break;
        }
        color.rgb = (GaussColor.rgb);
        return color;
}

float4 PS_cLayer_CAb_Gauss_H(in float4 pos : SV_Position, in float2 texCoord : TEXCOORD) : COLOR  {

        float4 color = tex2D(CopyrightAdaptive_Sampler_CAb_Gauss_V, texCoord);
        const float sampleOffsets[6] = { 0.0, 1.4584295168, 3.40398480678, 5.3518057801, 7.302940716, 9.2581597095 };
        const float sampleWeights[6] = { 0.13298, 0.23227575, 0.1353261595, 0.0511557427, 0.01253922, 0.0019913644 };
        color *= sampleWeights[0];
        for(int i = 1; i < 6; ++i)
        {
        color += tex2Dlod(CopyrightAdaptive_Sampler_CAb_Gauss_V, float4(texCoord + float2(sampleOffsets[i] * cLayer_CAb_Blur * PIXEL_SIZE.x, 0.0), 0.0, 0.0)) * sampleWeights[i];
        color += tex2Dlod(CopyrightAdaptive_Sampler_CAb_Gauss_V, float4(texCoord - float2(sampleOffsets[i] * cLayer_CAb_Blur * PIXEL_SIZE.x, 0.0), 0.0, 0.0)) * sampleWeights[i];
        }
        return color;
}

float4 PS_cLayer_CAb_Gauss_V(in float4 pos : SV_Position, in float2 texCoord : TEXCOORD) : COLOR  {

        const float3 SumUV = mul (mul (mul (mulUV, positionMatrix(0.5, 0.5)) * float3(BUFFER_SCREEN_SIZE, 1.0f), rotateMatrix_Alt(0)), scaleMatrix(ScaleX, ScaleY));
        float4 color = tex2D(CopyrightAdaptive_Sampler, SumUV.rg + float2(0.5, 0.5));
        const float sampleOffsets[6] = { 0.0, 1.4584295168, 3.40398480678, 5.3518057801, 7.302940716, 9.2581597095 };
        const float sampleWeights[6] = { 0.13298, 0.23227575, 0.1353261595, 0.0511557427, 0.01253922, 0.0019913644 };
        color *= sampleWeights[0];
        for(int i = 1; i < 6; ++i)
        {
        color += tex2Dlod(CopyrightAdaptive_Sampler_CAb_Gauss_H, float4(texCoord + float2(0.0, sampleOffsets[i] * cLayer_CAb_Blur * PIXEL_SIZE.y), 0.0, 0.0)) * sampleWeights[i];
        color += tex2Dlod(CopyrightAdaptive_Sampler_CAb_Gauss_H, float4(texCoord - float2(0.0, sampleOffsets[i] * cLayer_CAb_Blur * PIXEL_SIZE.y), 0.0, 0.0)) * sampleWeights[i];
        }
        return color;
}

float4 PS_cLayer_CAb_A(in float4 pos : SV_Position, in float2 texCoord : TEXCOORD) : COLOR  {

        const float2 CAb_Shift = cLayer_CAb_Shift * 0.05;
        const float3 SumUV = mul (mul (mulUV, positionMatrix(0.5 + CAb_Shift.x, 0.5 + CAb_Shift.y * BUFFER_WIDTH / BUFFER_HEIGHT)), scaleMatrix(1, 1));
        float4 color = tex2D(CopyrightAdaptive_Sampler_CAb_Gauss_H, SumUV.rg + pivot.rg) * all(SumUV.rg + pivot.rg == saturate(SumUV.rg + pivot.rg));
        color = float4(cLayer_CAb_Color_A.r, cLayer_CAb_Color_A.g, cLayer_CAb_Color_A.b, color.a * cLayer_CAb_Color_A.a);
        return color;
}

float4 PS_cLayer_CAb_B(in float4 pos : SV_Position, in float2 texCoord : TEXCOORD) : COLOR  {

        const float2 CAb_Shift = cLayer_CAb_Shift * 0.05;
        const float3 SumUV = mul (mul (mulUV, positionMatrix(0.5 - CAb_Shift.x, 0.5 - CAb_Shift.y * BUFFER_WIDTH / BUFFER_HEIGHT)), scaleMatrix(1, 1));
        float4 color = tex2D(CopyrightAdaptive_Sampler_CAb_Gauss_H, SumUV.rg + pivot.rg) * all(SumUV.rg + pivot.rg == saturate(SumUV.rg + pivot.rg));
        color = float4(cLayer_CAb_Color_B.r, cLayer_CAb_Color_B.g, cLayer_CAb_Color_B.b, color.a * cLayer_CAb_Color_B.a);
        return color;
}

void PS_cLayer(in float4 pos : SV_Position, float2 texCoord : TEXCOORD, out float4 passColor : SV_Target) {

    const float Depth = 0.999 - ReShade::GetLinearizedDepth(texCoord).x;
    float4 backColorOrig = tex2D(ReShade::BackBuffer, texCoord);
    if (Depth < cLayer_Depth)
    {
        const float3 SumUV = mul (mul (mul (mulUV, positionMatrix(PosX, PosY)) * float3(BUFFER_SCREEN_SIZE, 1.0f), rotateMatrix(cLayer_Rotate)), scaleMatrix(ScaleX, ScaleY));
        const float3 SumUV_Gauss = mul (mul (mul (mulUV, positionMatrix(PosX, PosY)) * float3(BUFFER_SCREEN_SIZE, 1.0f), rotateMatrix(cLayer_Rotate)), scaleMatrix(BUFFER_WIDTH, BUFFER_HEIGHT));
        float4 GaussOut = tex2D(CopyrightAdaptive_Sampler_Gauss_H, SumUV_Gauss.rg + pivot.rg);
        const float3 SumUV_CAb = mul (mul (mul (mulUV, positionMatrix(PosX, PosY)) * float3(BUFFER_SCREEN_SIZE, 1.0f), rotateMatrix(cLayer_Rotate)), scaleMatrix(BUFFER_WIDTH, BUFFER_HEIGHT));
        float4 CAb_A = tex2D(CopyrightAdaptive_Sampler_CAb_A, SumUV_CAb.rg + pivot.rg);
        float4 CAb_B = tex2D(CopyrightAdaptive_Sampler_CAb_B, SumUV_CAb.rg + pivot.rg);
        float4 DrawTex = tex2D(CopyrightAdaptive_Sampler, SumUV.rg + pivot.rg) * all(SumUV.rg + pivot.rg == saturate(SumUV.rg + pivot.rg));

        GaussOut.rgb = ComHeaders::Blending::Blend(cLayer_BlendMode_Gauss, backColorOrig.rgb, GaussOut.rgb, GaussOut.a * Gauss_Blend);

        switch(cLayer_BlendMode_CAb)
        {
            case 0:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::Screen(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::Screen(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 1:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::LinearDodge(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::LinearDodge(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 2:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::Glow(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::Glow(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 3:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::LinearLight(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::LinearLight(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 4:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::ColorB(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::ColorB(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 5:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::GrainMerge(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::GrainMerge(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 6:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::Divide(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::Divide(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 7:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::DivideAlt(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::DivideAlt(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 8:
                GaussOut = lerp(GaussOut.rgb, CAb_A.rgb, CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, CAb_B.rgb, CAb_B.a * cLayer_CAb_Strength);
                break;
        }

        float4 ColorFactor = DrawTex;
        if(ComHeaders::Blending::Lum(ColorFactor.xyz) <= ColorOverrideThreshold.x || ComHeaders::Blending::Lum(ColorFactor.xyz) >= ColorOverrideThreshold.y)
        {
            switch(cLayer_Color_Override){
            case 1:
            //#if cLayer_COLOR_OVERRIDE_COMBO == 1
                ColorFactor = saturate(DrawTex.rgb * ColorOverrideA.rgb);
                break;
            case 2:
            //#elif cLayer_COLOR_OVERRIDE_COMBO == 2
                ColorFactor = saturate(ColorFactor.rgb + ColorOverrideB.rgb);
                break;
            case 3:
            //#elif cLayer_COLOR_OVERRIDE_COMBO == 3
                ColorFactor = lerp(lerp(ColorOverrideB.rgb, ColorOverrideA.rgb, ColorFactor.rgb), ColorOverrideA.rgb, ColorFactor.rgb);
                break;
            case 4:
            //#elif cLayer_COLOR_OVERRIDE_COMBO == 4
                ColorFactor = ColorOverrideA.rgb;
                break;
            //#endif
            default:
                break;
            }
        }

        float4 backColor = GaussOut;
        passColor = lerp(GaussOut, backColorOrig, DrawTex.a);

        passColor.rgb = ComHeaders::Blending::Blend(cLayer_BlendMode_BG, backColor.rgb, passColor.rgb, DrawTex.a * cLayer_Blend_BG);

        switch (cLayer_BlendMode)
        {
            case 0:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::Screen(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::Screen(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 1:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::LinearDodge(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::LinearDodge(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 2:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::Glow(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::Glow(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 3:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::LinearLight(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::LinearLight(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 4:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::ColorB(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::ColorB(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 5:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::GrainMerge(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::GrainMerge(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 6:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::Divide(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::Divide(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 7:
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::DivideAlt(GaussOut.rgb, CAb_A.rgb), CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, ComHeaders::Blending::DivideAlt(GaussOut.rgb, CAb_B.rgb), CAb_B.a * cLayer_CAb_Strength);
                break;
            case 8:
                GaussOut = lerp(GaussOut.rgb, CAb_A.rgb, CAb_A.a * cLayer_CAb_Strength);
                GaussOut = lerp(GaussOut.rgb, CAb_B.rgb, CAb_B.a * cLayer_CAb_Strength);
                break;
        }

        float3 ColorFactorBlended;

        switch (cLayer_BlendMode)
        {
            // Normal
            default:
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactor.rgb : ColorFactor.rgb, DrawTex.a * cLayer_Blend);
                break;
            // Darken
            case 1:
                ColorFactorBlended = ComHeaders::Blending::Darken(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Multiply
            case 2:
                ColorFactorBlended = ComHeaders::Blending::Multiply(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Color Burn
            case 3:
                ColorFactorBlended = ComHeaders::Blending::ColorBurn(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Linear Burn
            case 4:
                ColorFactorBlended = ComHeaders::Blending::LinearBurn(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Lighten
            case 5:
                ColorFactorBlended = ComHeaders::Blending::Lighten(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Screen
            case 6:
                ColorFactorBlended = ComHeaders::Blending::Screen(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Color Dodge
            case 7:
                ColorFactorBlended = ComHeaders::Blending::ColorDodge(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Linear Dodge
            case 8:
                ColorFactorBlended = ComHeaders::Blending::LinearDodge(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Addition
            case 9:
                ColorFactorBlended = ComHeaders::Blending::Addition(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Glow
            case 10:
                ColorFactorBlended = ComHeaders::Blending::Glow(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Overlay
            case 11:
                ColorFactorBlended = ComHeaders::Blending::Overlay(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Soft Light
            case 12:
                ColorFactorBlended = ComHeaders::Blending::SoftLight(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Hard Light
            case 13:
                ColorFactorBlended = ComHeaders::Blending::HardLight(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Vivid Light
            case 14:
                ColorFactorBlended = ComHeaders::Blending::VividLight(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Linear Light
            case 15:
                ColorFactorBlended = ComHeaders::Blending::LinearLight(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Pin Light
            case 16:
                ColorFactorBlended = ComHeaders::Blending::PinLight(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Hard Mix
            case 17:
                ColorFactorBlended = ComHeaders::Blending::HardMix(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Difference
            case 18:
                ColorFactorBlended = ComHeaders::Blending::Difference(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Exclusion
            case 19:
                ColorFactorBlended = ComHeaders::Blending::Exclusion(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Subtract
            case 20:
                ColorFactorBlended = ComHeaders::Blending::Subtract(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Divide
            case 21:
                ColorFactorBlended = ComHeaders::Blending::Divide(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Divide (Alternative)
            case 22:
                ColorFactorBlended = ComHeaders::Blending::DivideAlt(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Divide (Photoshop)
            case 23:
                ColorFactorBlended = ComHeaders::Blending::DividePS(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Reflect
            case 24:
                ColorFactorBlended = ComHeaders::Blending::Reflect(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Grain Merge
            case 25:
                ColorFactorBlended = ComHeaders::Blending::GrainMerge(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Grain Extract
            case 26:
                ColorFactorBlended = ComHeaders::Blending::GrainExtract(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Hue
            case 27:
                ColorFactorBlended = ComHeaders::Blending::Hue(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Saturation
            case 28:
                ColorFactorBlended = ComHeaders::Blending::Saturation(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Color
            case 29:
                ColorFactorBlended = ComHeaders::Blending::ColorB(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
            // Luminosity
            case 30:
                ColorFactorBlended = ComHeaders::Blending::Luminosity(backColorOrig.rgb, ColorFactor.rgb);
                passColor = lerp(passColor.rgb, cLayer_Color_Invert ? float3(1, 1, 1) - ColorFactorBlended : ColorFactorBlended, DrawTex.a * cLayer_Blend);
                break;
        }
        passColor.a = backColorOrig.a;
    }
   else
   passColor = backColorOrig;
}

// -------------------------------------
// Techniques
// -------------------------------------

technique CopyrightAdaptive < ui_label = "版权标志（分辨率适配）"; ui_label_zh = "版权标志（分辨率适配）"; >
{
    pass pass0
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_cLayer_Gauss_H;
        RenderTarget = CopyrightAdaptive_Texture_Gauss_H;
    }
    pass pass1
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_cLayer_Gauss_V;
        RenderTarget = CopyrightAdaptive_Texture_Gauss_Out;
    }

    pass pass2
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_cLayer_CAb_Gauss_H;
        RenderTarget = CopyrightAdaptive_Texture_CAb_Gauss_H;
    }
    pass pass3
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_cLayer_CAb_Gauss_V;
        RenderTarget = CopyrightAdaptive_Texture_CAb_Gauss_Out;
    }
    pass pass4
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_cLayer_CAb_A;
        RenderTarget = CopyrightAdaptive_Texture_CAb_A;
    }
    pass pass5
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_cLayer_CAb_B;
        RenderTarget = CopyrightAdaptive_Texture_CAb_B;
    }
    pass pass6
   {
        VertexShader = PostProcessVS;
        PixelShader = PS_cLayer;
    }
}
