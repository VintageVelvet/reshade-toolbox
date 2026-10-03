#nullable enable
namespace DailyRoutines.ModulesPublic;

// Guidance checked against NVIDIA DLSS SDK v310.5.3 and current Streamline documentation.
// These are selection hints, not a guarantee that a game applies a requested preset.
internal static class PresetHelp
{
    internal static string Label(int value)
    {
        var note = value switch
        {
            >= 1 and <= 4 => "旧版预设",
            5 => "旧版兼容，不推荐",
            6 => "已弃用",
            7 or 8 or 9 or 14 or 15 => "回退默认，不推荐",
            10 => "K 的对照选项",
            11 => "DLAA / Quality / Balanced",
            12 => "4K Ultra Performance",
            13 => "Performance",
            _ => "尚未选择支持的预设"
        };
        return value is >= 1 and <= 15
            ? $"PRESET {(char)('A' + value - 1)} ({value}) · {note}"
            : $"当前 PRESET ({value}) · {note}";
    }

    internal static string Description(int value) => value switch
    {
        >= 1 and <= 4 => "旧版兼容选项。NVIDIA 新版 SDK 已移除 A-D，建议从 K 开始选择；旧 DLL 的行为取决于版本。",
        5 => "旧版兼容选项。310.5.3 SDK 头文件已移除 E；当前新版 SDK 重新列为弃用。日常使用优先考虑 K / M / L。",
        6 => "NVIDIA 已弃用的旧预设。保留供旧版兼容和对照，日常使用优先考虑 K / M / L。",
        7 or 8 or 9 or 14 or 15 => "NVIDIA 将此值标记为回退到默认行为，不推荐手动选择。它不代表一种明确的独立模型。",
        10 => "与 K 相近，可作为对照。官方说明 J 可能略少拖影，但更容易闪烁；通常优先 K。",
        11 => "DLSS 4 第一代 Transformer。DLAA / Quality / Balanced 的官方默认选择；RTX 20/30 系列也可优先从 K 开始。",
        12 => "DLSS 4.5 第二代 Transformer，面向 4K Ultra Performance（比例 3.0）。需要 DLSS 310.5.0 或更高版本，计算开销较高。",
        13 => "DLSS 4.5 第二代 Transformer，面向 Performance（比例 2.0）。需要 DLSS 310.5.0 或更高版本；RTX 20/30 系列建议比较帧率。",
        _ => "请从列表选择预设。模型选择还需与 DLSS 文件版本和质量挡位相匹配。"
    };

    internal static string SelectionHint(int preset, int quality) => (preset, quality) switch
    {
        (12, 5) => "L + Ultra Performance：面向 4K 输出；其他输出分辨率请对照画面和帧率。",
        (12, >= 0) => "L 的主要用途是 4K Ultra Performance；当前挡位也可对照测试，但开销可能更高。",
        (13, 4) => "M + Performance：符合官方推荐用途；仍需比较当前游戏的画面和帧率。",
        (13, >= 0) => "M 主要面向 Performance；当前挡位可对照测试，DLAA / Quality / Balanced 通常从 K 开始。",
        (11, 4 or 5) => "K 仍可用于当前挡位；若使用支持 DLSS 4.5 的 DLL，可对照 Performance + M 或 4K Ultra Performance + L。",
        (11, 1) => "Ultra Quality 是本模块的 1.3 比例挡位，可从 K 开始对照；官方默认建议未单独覆盖此比例。",
        _ => string.Empty
    };
}
