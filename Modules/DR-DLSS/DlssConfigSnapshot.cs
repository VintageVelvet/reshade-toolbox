#nullable enable
using System;
using System.Globalization;
using System.IO;
using System.Text;

namespace DailyRoutines.ModulesPublic;

/// <summary>A fresh read of configured values; override flags do not prove runtime activation.</summary>
public sealed record DlssConfigSnapshot(
    bool Success,
    string Error,
    int? Preset,
    double? Ratio,
    bool RatioOverrideEnabled,
    bool PresetOverrideEnabled,
    string Upscaler)
{
    public static DlssConfigSnapshot Read(string path)
    {
        try
        {
            var lines = File.ReadAllLines(path, new UTF8Encoding(false, true));
            string? presetText = DlssIni.GetValue(lines, "DLSS", "RenderPresetForAll");
            string? ratioText = DlssIni.GetValue(lines, "UpscaleRatio", "UpscaleRatioOverrideValue");
            int? preset = int.TryParse(presetText, NumberStyles.Integer, CultureInfo.InvariantCulture, out int presetValue)
                && presetValue >= 0 ? presetValue : null;
            double? ratio = double.TryParse(ratioText, NumberStyles.Float, CultureInfo.InvariantCulture, out double ratioValue)
                && double.IsFinite(ratioValue) && ratioValue >= 1d ? ratioValue : null;
            bool ratioEnabled = bool.TryParse(DlssIni.GetValue(lines, "UpscaleRatio", "UpscaleRatioOverrideEnabled"), out bool parsedRatioEnabled)
                && parsedRatioEnabled;
            bool presetEnabled = bool.TryParse(DlssIni.GetValue(lines, "DLSS", "RenderPresetOverride"), out bool parsedPresetEnabled)
                && parsedPresetEnabled;
            return new(true, string.Empty, preset, ratio, ratioEnabled, presetEnabled,
                DlssIni.GetValue(lines, "Upscalers", "Dx11Upscaler") ?? string.Empty);
        }
        catch (Exception error)
        {
            // A failed read must not retain a previous file's values or imply active overrides.
            return new(false, error.Message, null, null, false, false, string.Empty);
        }
    }

    /// <summary>Estimates input dimensions from configured ratio; this is not a DLSS measurement.</summary>
    public static (int Width, int Height)? EstimateInput(int width, int height, double? ratio, bool enabled)
    {
        if (!enabled || width <= 0 || height <= 0 || !ratio.HasValue ||
            !double.IsFinite(ratio.Value) || ratio.Value < 1d) return null;
        return (Math.Max(1, (int)Math.Round(width / ratio.Value, MidpointRounding.AwayFromZero)),
                Math.Max(1, (int)Math.Round(height / ratio.Value, MidpointRounding.AwayFromZero)));
    }
}
