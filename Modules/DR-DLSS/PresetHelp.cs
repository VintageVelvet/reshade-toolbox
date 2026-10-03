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

}
