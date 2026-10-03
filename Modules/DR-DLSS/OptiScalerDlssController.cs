// Based on the user-provided OptiScalerDlssController.cs (original UI attribution: DeepSeek).
// Maintained by VintageVelvet. See PROVENANCE.md for source and distribution scope.
#nullable enable
using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Numerics;
using System.Threading.Tasks;
using DailyRoutines.Common.Module.Abstractions;
using DailyRoutines.Common.Module.Enums;
using DailyRoutines.Common.Module.Models;
using Dalamud.Bindings.ImGui;
using Dalamud.Game.Command;
using Dalamud.Plugin.Services;
using FFXIVClientStructs.FFXIV.Client.Graphics.Kernel;
using OmenTools;
using OmenTools.OmenService;

namespace DailyRoutines.ModulesPublic;

public sealed class OptiScalerDlssController : ModuleBase
{
    public override ModuleInfo Info { get; } = new()
    {
        Title = "DLSS档位调节",
        Description = "手动选择 DLSS Render Preset 和默认档位，保存配置并可刷新游戏画面。",
        Category = ModuleCategory.System,
        Author = ["VintageVelvet"]
    };

    public override ModulePermission Permission { get; } = new() { AllDefaultEnabled = true };

    private Config config = null!;
    private readonly WindowRefresh refresh = new();
    private string writeStatus = string.Empty;
    private string dlssFileVersion = "未知";
    private bool primaryCommandRegistered;
    private bool legacyCommandRegistered;
    private DlssConfigSnapshot? currentConfig;
    private Task<DlssConfigSnapshot>? configReadTask;
    private string configReadPath = string.Empty;
    private int configReadGeneration;
    private int snapshotGeneration;
    private long nextConfigRead;
    private int outputWidth;
    private int outputHeight;

    private static readonly string[] QualityNames =
        ["DLAA", "Ultra Quality", "Quality", "Balanced", "Performance", "Ultra Performance"];
    private static readonly string[] QualityCommands = ["dlaa", "uq", "quality", "balanced", "performance", "up"];
    private static readonly float[] QualityRatios = [1f, 1.3f, 1.5f, 1.7f, 2f, 3f];
    private bool Busy => refresh.IsRunning;

    protected override void Init()
    {
        config = LoadConfig<Config>() ?? new();
        config.Revision = 2;
        if (string.IsNullOrWhiteSpace(config.IniPath)) config.IniPath = DetectIniPath();
        if (config.SelectedQualityProfile < -1 || config.SelectedQualityProfile >= QualityNames.Length)
            config.SelectedQualityProfile = 4;
        SaveConfig(config);
        Overlay = new(this) { Flags = ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoDocking };
        refresh.Completed += OnRefreshCompleted;
        ReadSettings();
        DService.Instance().Framework.Update += OnConfigUpdate;
        primaryCommandRegistered = CommandManager.Instance().AddSubCommand("dlss", new CommandInfo(OnCommand)
        { HelpMessage = "/pdr dlss [dlaa|uq|quality|balanced|performance|up|apply|refresh|preset default|K|L|M]" });
        legacyCommandRegistered = CommandManager.Instance().AddSubCommand("optidlss", new CommandInfo(OnCommand)
        { HelpMessage = "/pdr optidlss：/pdr dlss 的旧别名" });
    }

    protected override void Uninit()
    {
        if (primaryCommandRegistered) CommandManager.Instance().RemoveSubCommand("dlss");
        if (legacyCommandRegistered) CommandManager.Instance().RemoveSubCommand("optidlss");
        DService.Instance().Framework.Update -= OnConfigUpdate;
        configReadTask = null;
        refresh.Completed -= OnRefreshCompleted;
        refresh.Cancel();
    }

    protected override void ConfigUI() => DrawUI();
    protected override void OverlayUI() => DrawUI();

    private void DrawUI()
    {
        // Fit the complete longest label, including frame padding and the dropdown arrow.
        var minimumWidth = ImGui.CalcTextSize(PresetHelp.Label(11)).X + ImGui.GetStyle().FramePadding.X * 2 + ImGui.GetFrameHeight();
        var width = Math.Max(minimumWidth, Math.Min(ImGui.GetContentRegionAvail().X, ImGui.GetFontSize() * 44));
        ImGui.PushTextWrapPos(ImGui.GetCursorPosX() + width);
        ImGui.TextUnformatted("DLSS 模型");
        ImGui.BeginDisabled(Busy);
        ImGui.SetNextItemWidth(width);
        ImGui.SetNextWindowSizeConstraints(new Vector2(width, 0), new Vector2(float.MaxValue, ImGui.GetFontSize() * 22));
        if (ImGui.BeginCombo("###Preset", PresetHelp.Label(config.SelectedRenderPreset)))
        {
            foreach (var value in PresetHelp.Values)
            {
                if (!PresetHelp.IsSupported(value, dlssFileVersion)) continue;
                if (ImGui.Selectable(PresetHelp.Label(value), config.SelectedRenderPreset == value))
                { config.SelectedRenderPreset = value; SaveConfig(config); }
                if (ImGui.IsItemHovered())
                {
                    ImGui.BeginTooltip();
                    ImGui.PushTextWrapPos(ImGui.GetFontSize() * 32);
                    ImGui.TextUnformatted(PresetHelp.Description(value));
                    ImGui.PopTextWrapPos();
                    ImGui.EndTooltip();
                }
            }
            ImGui.EndCombo();
        }
        if (ImGui.IsItemHovered()) DrawPresetTooltip(config.SelectedRenderPreset);
        ImGui.Dummy(new Vector2(0, ImGui.GetFontSize() * 0.65f));
        ImGui.TextUnformatted("DLSS 档位");
        ImGui.SetNextItemWidth(width);
        var currentQuality = config.SelectedQualityProfile >= 0
            ? $"{QualityNames[config.SelectedQualityProfile]} ({QualityRatios[config.SelectedQualityProfile]:F1})"
            : "当前比例未对应默认档位，请选择";
        if (ImGui.BeginCombo("###Quality", currentQuality))
        {
            for (var value = 0; value < QualityNames.Length; value++)
            {
                if (ImGui.Selectable($"{QualityNames[value]} ({QualityRatios[value]:F1})", config.SelectedQualityProfile == value))
                { config.SelectedQualityProfile = value; SaveConfig(config); }
            }
            ImGui.EndCombo();
        }
        ImGui.Dummy(new Vector2(0, ImGui.GetFontSize() * 0.65f));
        if (ImGui.Button("写入配置")) Apply(false);
        ImGui.SameLine();
        if (ImGui.Button("刷新生效")) StartRefresh();
        ImGui.SameLine();
        if (ImGui.Button("写入并刷新生效")) Apply(true);
        ImGui.EndDisabled();

        ImGui.Spacing();
        ImGui.Separator();
        DrawCurrentConfig();
        if (writeStatus.Length != 0) ImGui.TextWrapped(writeStatus);
        if (refresh.Status != "刷新尚未执行") ImGui.TextWrapped(refresh.Status);
        ImGui.Spacing();

        if (ImGui.CollapsingHeader("配置文件"))
        {
            ImGui.BeginDisabled(Busy);
            var pathWidth = Math.Max(ImGui.GetContentRegionAvail().X, ImGui.CalcTextSize(CurrentIniPath).X + ImGui.GetStyle().FramePadding.X * 2);
            ImGui.SetNextItemWidth(pathWidth);
            ImGui.InputText("###IniPath", ref config.IniPath, 1024);
            if (ImGui.IsItemDeactivatedAfterEdit()) { config.IniPath = config.IniPath.Trim().Trim('"'); SaveConfig(config); ReadSettings(); }
            if (ImGui.Button("自动定位")) { config.IniPath = DetectIniPath(); SaveConfig(config); ReadSettings(); }
            ImGui.SameLine();
            if (ImGui.Button("重新读取")) ReadSettings();
            ImGui.EndDisabled();
        }
        if (ImGui.CollapsingHeader("高级刷新设置")) DrawRefreshSettings();
        if (ImGui.CollapsingHeader("快捷命令"))
        {
            ImGui.TextUnformatted("/pdr dlss：打开界面\n/pdr dlss dlaa | uq | quality | balanced | performance | up：写入并刷新\n/pdr dlss apply：只写入\n/pdr dlss refresh：只刷新\n/pdr dlss preset K：选择模型并写入刷新\n/pdr dlss select quality：只选择挡位\n旧命令 /pdr optidlss 仍可用。");
            if (!primaryCommandRegistered) ImGui.TextWrapped("/pdr dlss 已被其他模块占用，请关闭旧模块后重新启用本模块。");
        }
        ImGui.PopTextWrapPos();
    }

    private static void DrawPresetTooltip(int preset)
    {
        ImGui.BeginTooltip();
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 32);
        ImGui.TextUnformatted(PresetHelp.Description(preset));
        ImGui.PopTextWrapPos();
        ImGui.EndTooltip();
    }

    private void DrawCurrentConfig()
    {
        ImGui.TextUnformatted("当前配置（每秒读取）");
        if (currentConfig is not { Success: true } state)
        {
            ImGui.TextWrapped(currentConfig == null ? "正在读取……" : $"读取失败：{currentConfig.Error}");
        }
        else
        {
            var preset = !state.PresetOverrideEnabled ? "游戏默认"
                : state.Preset.HasValue ? PresetName(state.Preset.Value) : "未设置";
            ImGui.TextWrapped($"配置模型：{preset}");
            var ratio = state.Ratio.HasValue ? state.Ratio.Value.ToString("0.###", CultureInfo.InvariantCulture) + "×" : "未设置或无效";
            ImGui.TextWrapped($"配置倍率：{ratio}{(state.RatioOverrideEnabled ? string.Empty : "（覆盖关闭）")}");
            if (state.Upscaler.Length != 0 && !state.Upscaler.Equals("dlss", StringComparison.OrdinalIgnoreCase))
                ImGui.TextWrapped($"配置升频器：{state.Upscaler}");
        }
        var input = currentConfig is { Success: true } value && value.Upscaler.Equals("dlss", StringComparison.OrdinalIgnoreCase)
            ? DlssConfigSnapshot.EstimateInput(outputWidth, outputHeight, value.Ratio, value.RatioOverrideEnabled) : null;
        if (input.HasValue) ImGui.TextUnformatted($"渲染分辨率：{input.Value.Width} × {input.Value.Height}");
        ImGui.TextUnformatted(outputWidth > 0 && outputHeight > 0
            ? $"输出分辨率：{outputWidth} × {outputHeight}" : "输出分辨率：暂不可用");
        ImGui.TextDisabled($"DLSS：{dlssFileVersion}");
    }

    private void OnConfigUpdate(IFramework framework)
    {
        if (configReadTask is { IsCompleted: true })
        {
            if (configReadGeneration == snapshotGeneration && string.Equals(configReadPath, CurrentIniPath, StringComparison.OrdinalIgnoreCase))
                currentConfig = configReadTask.GetAwaiter().GetResult();
            configReadTask = null;
        }
        if (Environment.TickCount64 < nextConfigRead) return;
        nextConfigRead = Environment.TickCount64 + 1000;
        SampleOutputSize();
        if (configReadTask != null) return;
        configReadPath = CurrentIniPath;
        configReadGeneration = snapshotGeneration;
        var path = configReadPath;
        configReadTask = Task.Run(() => DlssConfigSnapshot.Read(path));
    }

    private unsafe void SampleOutputSize()
    {
        outputWidth = outputHeight = 0;
        var device = Device.Instance();
        if (device == null || device->SwapChain == null) return;
        var width = device->SwapChain->Width;
        var height = device->SwapChain->Height;
        if (width is > 0 and <= 65536 && height is > 0 and <= 65536)
        { outputWidth = (int)width; outputHeight = (int)height; }
    }

    private void DrawRefreshSettings()
    {
        ImGui.TextWrapped("临时切到窗口模式并调整尺寸，再切回无边框以请求画面重建，最后恢复原窗口模式和位置。默认参数沿用旧模块。");
        ImGui.BeginDisabled(Busy);
        var changed = ImGui.InputInt("窗口模式值", ref config.WindowedModeValue);
        changed |= ImGui.InputInt("无边框模式值", ref config.BorderlessModeValue);
        changed |= ImGui.InputInt("切换等待毫秒", ref config.RefreshDelayMs);
        changed |= ImGui.Checkbox("刷新时临时调整窗口尺寸", ref config.ResizeWindowDuringRefresh);
        changed |= ImGui.SliderFloat("临时窗口缩放", ref config.WindowedRefreshScale, 0.5f, 0.99f, "%.2f");
        changed |= ImGui.Checkbox("请求 SwapChain 分辨率刷新", ref config.RequestSwapchainRefresh);
        if (changed)
        {
            config.WindowedModeValue = Math.Clamp(config.WindowedModeValue, 0, 3);
            config.BorderlessModeValue = Math.Clamp(config.BorderlessModeValue, 0, 3);
            config.RefreshDelayMs = Math.Clamp(config.RefreshDelayMs, 100, 5000);
            SaveConfig(config);
        }
        ImGui.EndDisabled();
    }

    private void OnCommand(string command, string args)
    {
        var parts = args.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length == 0) { Overlay!.IsOpen = !Overlay.IsOpen; return; }
        if (Busy) { NotifyHelper.Instance().NotificationWarning("请等待当前刷新结束"); return; }
        var action = parts[0].ToLowerInvariant();
        if (action == "apply" && parts.Length == 1) { Apply(false); return; }
        if (action == "refresh" && parts.Length == 1) { StartRefresh(); return; }
        if (action == "preset" && parts.Length == 2)
        {
            var value = parts[1].ToUpperInvariant();
            var parsed = value is "DEFAULT" or "默认" ? 0 : value.Length == 1 && value[0] >= 'A' && value[0] <= 'O'
                ? value[0] - 'A' + 1 : int.TryParse(value, out var numeric) ? numeric : -1;
            if (!PresetHelp.IsSelectable(parsed)) { Error("模型只提供 default、K、L、M（0、11、12、13）"); return; }
            if (!PresetHelp.IsSupported(parsed, dlssFileVersion)) { Error("当前 DLSS 文件版本不支持此选项，请选择游戏默认"); return; }
            config.SelectedRenderPreset = parsed;
            SaveConfig(config);
            Apply(true);
            return;
        }
        var selectionOnly = action == "select" && parts.Length == 2;
        var profileCommand = selectionOnly || (action == "set" && parts.Length == 2) ? parts[1].ToLowerInvariant() : action;
        var index = Array.IndexOf(QualityCommands, profileCommand);
        if (index < 0 || (!(selectionOnly || action == "set") && parts.Length != 1))
        { Error("用法：/pdr dlss [dlaa|uq|quality|balanced|performance|up|apply|refresh|preset default|K|L|M]"); return; }
        config.SelectedQualityProfile = index;
        SaveConfig(config);
        if (selectionOnly) NotifyHelper.Instance().NotificationInfo($"已选择 {QualityNames[index]}，尚未写入");
        else Apply(true);
    }

    private void Apply(bool thenRefresh)
    {
        if (Busy) return;
        if (config.SelectedQualityProfile < 0 || config.SelectedQualityProfile >= QualityRatios.Length)
        { Error("请先选择一个默认挡位"); return; }
        if (!PresetHelp.IsSelectable(config.SelectedRenderPreset))
        { Error("旧模型已从选择列表移除，请选择默认、K、L 或 M"); return; }
        if (!PresetHelp.IsSupported(config.SelectedRenderPreset, dlssFileVersion))
        { Error("当前 DLSS 文件版本不支持此选项，请选择游戏默认"); return; }
        try
        {
            var path = Path.GetFullPath(config.IniPath.Trim().Trim('"'));
            var backup = DlssIni.Write(path, config.SelectedRenderPreset, QualityRatios[config.SelectedQualityProfile]);
            writeStatus = $"配置已保存；备份：{Path.GetFileName(backup)}";
            ReadSettings();
            NotifyHelper.Instance().NotificationSuccess("DLSS配置已保存，供下次启动读取");
            if (thenRefresh) StartRefresh();
        }
        catch (Exception error) { Error($"写入失败：{error.Message}"); }
    }

    private void StartRefresh()
    {
        if (!refresh.Start((uint)config.WindowedModeValue, (uint)config.BorderlessModeValue,
            config.RefreshDelayMs, config.ResizeWindowDuringRefresh, config.RequestSwapchainRefresh, config.WindowedRefreshScale))
            Error(refresh.Status);
    }

    private void OnRefreshCompleted(bool success, string message)
    {
        if (success) NotifyHelper.Instance().NotificationSuccess(message);
        else NotifyHelper.Instance().NotificationError(message);
    }

    private void ReadSettings()
    {
        snapshotGeneration++;
        nextConfigRead = 0;
        dlssFileVersion = ReadDlssFileVersion();
        currentConfig = DlssConfigSnapshot.Read(CurrentIniPath);
        if (currentConfig.Success)
        {
            config.SelectedRenderPreset = currentConfig.PresetOverrideEnabled ? currentConfig.Preset ?? -1 : 0;
            config.SelectedQualityProfile = currentConfig.Ratio.HasValue
                ? Array.FindIndex(QualityRatios, known => Math.Abs(known - currentConfig.Ratio.Value) < 0.0001) : -1;
            SaveConfig(config);
        }
    }

    private void Error(string message)
    { writeStatus = message; NotifyHelper.Instance().NotificationError(message); }

    private static string DetectIniPath() => string.IsNullOrWhiteSpace(Environment.ProcessPath)
        ? string.Empty : Path.Combine(Path.GetDirectoryName(Environment.ProcessPath)!, "OptiScaler.ini");
    private string CurrentIniPath => config.IniPath.Trim().Trim('"');
    private static string PresetName(int value) => value == 0 ? "默认" : value is >= 1 and <= 15
        ? $"PRESET {(char)('A' + value - 1)} ({value}){(PresetHelp.IsSelectable(value) ? string.Empty : "（已移出选择列表）")}" : $"PRESET {value}（请重新选择）";

    private string ReadDlssFileVersion()
    {
        try
        {
            var directory = Path.GetDirectoryName(Path.GetFullPath(config.IniPath.Trim().Trim('"')));
            var path = Path.Combine(directory!, "nvngx_dlss.dll");
            if (!File.Exists(path)) return "未找到 nvngx_dlss.dll";
            return FileVersionInfo.GetVersionInfo(path).FileVersion?.Replace(", ", ".").Replace(',', '.') ?? "未知";
        }
        catch { return "未知"; }
    }

    private sealed class Config : ModuleConfig
    {
        public int Revision;
        public string IniPath = string.Empty;
        public int SelectedRenderPreset = 11;
        public int SelectedQualityProfile = 4;
        public int WindowedModeValue = 1;
        public int BorderlessModeValue = 2;
        public int RefreshDelayMs = 800;
        public bool ResizeWindowDuringRefresh = true;
        public bool RequestSwapchainRefresh = true;
        public float WindowedRefreshScale = 0.95f;
    }
}
