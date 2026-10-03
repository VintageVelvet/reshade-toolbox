#nullable enable
using System;
namespace DailyRoutines.ModulesPublic;

// Scope: one default entry and the current K/L/M presets. See README.md for NVIDIA sources.
internal static class PresetHelp
{
    internal static readonly int[] Values = [0, 11, 12, 13];
    internal static bool IsSelectable(int value) => value is 0 or 11 or 12 or 13;

    internal static bool IsSupported(int value, string fileVersion)
    {
        if (value == 0) return true;
        if (!IsSelectable(value) || !Version.TryParse(fileVersion, out var version)) return false;
        return version >= (value == 11 ? new Version(310, 2, 0) : new Version(310, 5, 0));
    }

    internal static string Label(int value) => value switch
    {
        0 => "游戏默认",
        11 => "PRESET K (11) · DLAA / Quality / Balanced",
        12 => "PRESET L (12) · 4K Ultra Performance",
        13 => "PRESET M (13) · Performance",
        >= 1 and <= 15 => $"PRESET {(char)('A' + value - 1)} ({value}) · 请重新选择",
        _ => "请选择默认、K、L 或 M"
    };

    internal static string Description(int value) => value switch
    {
        0 => "关闭 OptiScaler 的模型覆盖，跟随 FF14 原本的模型请求。缩放挡位仍按你的选择写入。",
        11 => "DLSS 4 第一代 Transformer，主要用于 DLAA / Quality / Balanced；RTX 20/30 系列可优先选择。",
        12 => "DLSS 4.5 第二代 Transformer，主要用于 4K Ultra Performance。需要 DLSS 310.5.0+，计算开销较高。",
        13 => "DLSS 4.5 第二代 Transformer，主要用于 Performance。需要 DLSS 310.5.0+；RTX 20/30 系列计算开销较高。",
        _ => "此值已移出日常选择列表，请选择默认、K、L 或 M。"
    };
}
