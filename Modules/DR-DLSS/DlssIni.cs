#nullable enable

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace DailyRoutines.ModulesPublic;

/// <summary>Updates only the DLSS controls, with a byte-for-byte backup of the original INI.</summary>
public static class DlssIni
{
    private sealed class Line
    {
        internal string Text;
        internal string Ending;
        internal Line(string text, string ending) { Text = text; Ending = ending; }
    }

    public static string? GetValue(IReadOnlyList<string> lines, string section, string key)
    {
        bool inSection = false;
        foreach (string text in lines)
        {
            string trimmed = text.Trim().TrimStart('\uFEFF');
            if (TrySection(trimmed, out string? name))
            {
                inSection = string.Equals(name, section, StringComparison.OrdinalIgnoreCase);
                continue;
            }
            if (!inSection || !TryKey(text, out string? found, out int equal)) continue;
            if (string.Equals(found, key, StringComparison.OrdinalIgnoreCase))
                return RemoveComment(text.Substring(equal + 1)).Trim();
        }
        return null;
    }

    public static string Write(string path, int preset, float ratio)
    {
        if (preset < 1 || preset > 15) throw new ArgumentOutOfRangeException(nameof(preset));
        if (float.IsNaN(ratio) || float.IsInfinity(ratio) || ratio < 1f || ratio > 3f)
            throw new ArgumentOutOfRangeException(nameof(ratio));

        string target = Path.GetFullPath(path);
        byte[] original = File.ReadAllBytes(target);
        bool bom = original.Length >= 3 && original[0] == 0xEF && original[1] == 0xBB && original[2] == 0xBF;
        var utf8 = new UTF8Encoding(false, true);
        string text = utf8.GetString(original, bom ? 3 : 0, original.Length - (bom ? 3 : 0));
        var lines = new List<Line>();
        string newline = Environment.NewLine;
        bool foundNewline = false;
        foreach (Match match in Regex.Matches(text, @"([^\r\n]*)(\r\n|\r|\n|$)"))
        {
            if (match.Length == 0) continue;
            string ending = match.Groups[2].Value;
            lines.Add(new Line(match.Groups[1].Value, ending));
            if (!foundNewline && ending.Length != 0) { newline = ending; foundNewline = true; }
        }

        SetValue(lines, "Upscalers", "Dx11Upscaler", "dlss", newline);
        SetValue(lines, "DLSS", "RenderPresetOverride", "true", newline);
        SetValue(lines, "DLSS", "RenderPresetForAll", preset.ToString(CultureInfo.InvariantCulture), newline);
        SetValue(lines, "UpscaleRatio", "UpscaleRatioOverrideEnabled", "true", newline);
        SetValue(lines, "UpscaleRatio", "UpscaleRatioOverrideValue", ratio.ToString("F6", CultureInfo.InvariantCulture), newline);

        var output = new StringBuilder();
        foreach (Line line in lines) output.Append(line.Text).Append(line.Ending);
        byte[] body = utf8.GetBytes(output.ToString());
        byte[] updated = new byte[body.Length + (bom ? 3 : 0)];
        if (bom) { updated[0] = 0xEF; updated[1] = 0xBB; updated[2] = 0xBF; }
        Buffer.BlockCopy(body, 0, updated, bom ? 3 : 0, body.Length);

        string suffix = DateTime.UtcNow.ToString("yyyyMMdd-HHmmss-fffffff", CultureInfo.InvariantCulture) + "-" + Guid.NewGuid().ToString("N");
        string backup = target + ".drbackup-" + suffix;
        string temporary = target + ".drtmp-" + suffix;
        try
        {
            using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                stream.Write(updated, 0, updated.Length);
                stream.Flush(true);
            }
            if (!BytesEqual(original, File.ReadAllBytes(target)))
                throw new IOException("OptiScaler.ini changed while preparing the update. Read it again before applying.");
            if (File.Exists(backup)) throw new IOException("The backup path already exists.");
            File.Replace(temporary, target, backup);
            return backup;
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }

    private static bool BytesEqual(byte[] left, byte[] right)
    {
        if (left.Length != right.Length) return false;
        for (int i = 0; i < left.Length; i++) if (left[i] != right[i]) return false;
        return true;
    }

    private static bool TrySection(string text, out string? name)
    {
        name = null;
        text = RemoveComment(text).Trim();
        if (text.Length < 2 || text[0] != '[' || text[text.Length - 1] != ']') return false;
        name = text.Substring(1, text.Length - 2).Trim();
        return true;
    }

    private static bool TryKey(string text, out string? key, out int equal)
    {
        key = null;
        equal = -1;
        string trimmed = text.TrimStart();
        if (trimmed.Length == 0 || trimmed[0] == ';' || trimmed[0] == '#' || trimmed[0] == '[') return false;
        equal = text.IndexOf('=');
        if (equal < 0) return false;
        key = text.Substring(0, equal).Trim();
        return key.Length != 0;
    }

    private static string RemoveComment(string value) => Regex.Replace(value, @"\s+[;#].*$", "");

    private static void SetValue(List<Line> lines, string section, string key, string value, string newline)
    {
        bool inSection = false;
        int firstSection = -1;
        int insertAt = -1;
        bool found = false;
        for (int i = 0; i < lines.Count; i++)
        {
            if (TrySection(lines[i].Text.Trim(), out string? name))
            {
                if (inSection && insertAt < 0) insertAt = i;
                inSection = string.Equals(name, section, StringComparison.OrdinalIgnoreCase);
                if (inSection && firstSection < 0) firstSection = i;
                continue;
            }
            if (!inSection || !TryKey(lines[i].Text, out string? foundKey, out int equal)
                || !string.Equals(foundKey, key, StringComparison.OrdinalIgnoreCase)) continue;
            string oldValue = lines[i].Text.Substring(equal + 1);
            Match comment = Regex.Match(oldValue, @"\s+[;#].*$");
            Match whitespace = Regex.Match(oldValue, @"^\s*");
            lines[i].Text = lines[i].Text.Substring(0, equal + 1) + whitespace.Value + value + (comment.Success ? comment.Value : "");
            found = true;
        }
        // Update every duplicate to avoid depending on the reader's first/last-key behavior.
        if (found) return;
        if (firstSection < 0)
        {
            EnsureEnding(lines, lines.Count, newline);
            lines.Add(new Line("[" + section + "]", newline));
            lines.Add(new Line(key + " = " + value, newline));
            return;
        }
        if (insertAt < 0) insertAt = lines.Count;
        EnsureEnding(lines, insertAt, newline);
        lines.Insert(insertAt, new Line(key + " = " + value, newline));
    }

    private static void EnsureEnding(List<Line> lines, int position, string newline)
    {
        if (position > 0 && lines[position - 1].Ending.Length == 0) lines[position - 1].Ending = newline;
    }
}
