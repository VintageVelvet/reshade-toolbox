# 编译验证

验证日期：2026-09-27。

## 工具与来源

使用 [ReShade Testing Initiative v6.8.0.5](https://github.com/CeeJayDK/ReShade-Testing-Initiative/releases/tag/v6.8.0.5) 的 Windows x64 `reshadefx_cli.exe`。版本输出为 `ReShade 6.8.0 (ReShade Testing Initiative build)`。

这是社区提供的官方 ReShade FX 编译器源码构建，**不是 ReShade 官方发布的二进制**。该项目将普通 `reshadefx_cli` 标为未修改的官方 `tools/fxc.cpp`；本次未使用带补丁的 `reshadefx_cli_fixed` 编译最终结果，仅用其列出入口名称。DXBC 模式通过 Windows 的 Microsoft D3DCompiler 编译实际顶点、像素着色器。

- 官方源码：[crosire/reshade](https://github.com/crosire/reshade)
- 社区构建说明：[ReShade Testing Initiative README](https://github.com/CeeJayDK/ReShade-Testing-Initiative#readme)
- 编译器 SHA-256：`986FFD4ABE4BBDDAA504D2A68044F0B676AEFA958B8BCE8B90B468EB02DC408A`
- 被验证的 `LandscapeComposition.fx` SHA-256：`E8E69C4C6777A8DA456BC60EFA76E2A39E7C2C1BF15325C863BAF9B9BB03C819`
- 使用用户现有 AuroraShade 着色器目录中的 `ReShade.fxh`，SHA-256：`2FFFB6009B9593BC43473861E5B189A6FAEE1BD7465913FA8799B85D77DF066F`

工具处理包含中文的 include 路径时曾异常退出且未给出诊断。将原始 `.fx` 和 `ReShade.fxh` 原样复制到临时 ASCII 路径后正常编译；已核对原文件与待编译副本哈希相同。

## 已完成检查

| 检查 | 分辨率 | 结果 |
| --- | --- | --- |
| DXBC Shader Model 5.0，顶点及像素入口分别编译 | 1920 × 1080，16:9 | 两入口均退出码 0，生成非空字节码 |
| DXBC Shader Model 5.0，顶点及像素入口分别编译 | 2560 × 1080，常见 21:9 显示器规格 | 两入口均退出码 0，生成非空字节码 |
| DXBC Shader Model 5.0，顶点及像素入口分别编译 | 5120 × 1440，32:9 | 两入口均退出码 0，生成非空字节码 |
| OpenGL GLSL 源码生成 | 1920 × 1080 | 退出码 0，生成非空 GLSL |
| Vulkan SPIR-V，顶点及像素入口分别生成 | 1920 × 1080 | 两入口均退出码 0，生成非空 SPIR-V |

编译时保留运行时 uniform，所有构图分支均参与编译；没有仅使用默认选项进行常量折叠。没有收到编译错误或警告。

## 复现命令

下面以临时目录中原样复制的源文件为输入。`-I` 指向含 `ReShade.fxh` 的目录，编译器和临时输入不纳入此仓库。

```powershell
$compiler = '.\work\reshade-validation\reshadefx_cli.exe'
$inputFile = '.\work\compiler-input\LandscapeComposition.fx'
$includeDir = '.\work\compiler-input'

# 对 1920 × 1080、2560 × 1080、5120 × 1440 分别执行：
foreach ($size in @(@(1920,1080), @(2560,1080), @(5120,1440))) {
    foreach ($entry in @('F__PostProcessVS', 'F__LandscapeComposition__PS_Composition')) {
        & $compiler --dxbc --shader-model 50 --width $size[0] --height $size[1] `
            -D __RENDERER__=0xb000 -I $includeDir -E $entry `
            -Fo ".\work\composition-$($size[0])x$($size[1])-$entry.dxbc" $inputFile
        if ($LASTEXITCODE -ne 0) { throw "DXBC compilation failed: $entry" }
    }
}

& $compiler --glsl --width 1920 --height 1080 -D __RENDERER__=0x10000 `
    -I $includeDir -Fo '.\work\composition.glsl' $inputFile

foreach ($entry in @('E__PostProcessVS', 'E__LandscapeComposition__PS_Composition')) {
    & $compiler --spirv --vulkan-semantics --width 1920 --height 1080 `
        -D __RENDERER__=0x20000 -I $includeDir -E $entry `
        -Fo ".\work\composition-$entry.spv" $inputFile
}
```

为独立编译器显式提供 `__RENDERER__`，使 include 中的后端条件与被测试后端一致。DXBC 与 SPIR-V 使用具体入口，避免独立工具在未指定入口时不生成实际字节码。

## 验证边界

上述结果证明 ReShade FX 前端与 DX11 对应的 SM5 后端接受当前源码；GLSL 检查仅覆盖代码生成，未交给实际 OpenGL 驱动编译。未在用户游戏内加载、截图或观察运行时图像，因此线条观感、游戏效果排序、截图流程仍需实际使用确认。超宽分辨率通过编译不代表已经添加独立安全框、裁切或宽屏专属构图设计。

`enabled_in_screenshot = false` 是 [ReShade 5.2 官方加入的技术注解](https://www.reshade.me/releases/8046-5-2)，并非 AuroraShade 私有扩展。它控制 ReShade 自身截图流程，不能使游戏截图、系统截图或录屏自动隐藏构图线。
