// Based on the user-provided OptiScalerDlssController.cs (original UI attribution: DeepSeek).
// Maintained by VintageVelvet. See PROVENANCE.md for source and distribution scope.
#nullable enable
using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using DailyRoutines.Common.Module.Abstractions;
using DailyRoutines.Common.Module.Enums;
using DailyRoutines.Common.Module.Models;
using Dalamud.Bindings.ImGui;
using Dalamud.Game.Command;
using Dalamud.Plugin.Services;
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
        Author = ["DeepSeek", "VintageVelvet"]
    };

    public override ModulePermission Permission { get; } = new() { AllDefaultEnabled = true };

    private Config config = null!;
    private readonly WindowRefresh refresh = new();
    private string readStatus = "尚未读取";
    private string writeStatus = "尚未写入";
    private string bridgeStatus = "桥接默认关闭";
    private string dlssFileVersion = "未知";
    private bool primaryCommandRegistered;
    private bool legacyCommandRegistered;
    private Task<BridgeClient.Result>? bridgeTask;
    private CancellationTokenSource? bridgeCancellation;
    private bool refreshAfterBridge;

    private static readonly string[] QualityNames =
        ["DLAA", "Ultra Quality", "Quality", "Balanced", "Performance", "Ultra Performance"];
    private static readonly string[] QualityCommands = ["dlaa", "uq", "quality", "balanced", "performance", "up"];
    private static readonly float[] QualityRatios = [1f, 1.3f, 1.5f, 1.7f, 2f, 3f];
    private bool Busy => refresh.IsRunning || bridgeTask != null;

    protected override void Init()
    {
        config = LoadConfig<Config>() ?? new();
        // Old configs enable the previously unreliable bridge. Start this revision opt-in.
        if (config.Revision < 1)
        {
            config.UseRuntimeBridge = false;
            config.Revision = 1;
        }
        if (string.IsNullOrWhiteSpace(config.IniPath)) config.IniPath = DetectIniPath();
        if (config.SelectedQualityProfile < -1 || config.SelectedQualityProfile >= QualityNames.Length)
            config.SelectedQualityProfile = 4;
        SaveConfig(config);
        Overlay = new(this) { Flags = ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoDocking };
        refresh.Completed += OnRefreshCompleted;
        ReadSettings();
        primaryCommandRegistered = CommandManager.Instance().AddSubCommand("dlss", new CommandInfo(OnCommand)
        { HelpMessage = "/pdr dlss [dlaa|uq|quality|balanced|performance|up|apply|refresh|preset A-O]" });
        legacyCommandRegistered = CommandManager.Instance().AddSubCommand("optidlss", new CommandInfo(OnCommand)
        { HelpMessage = "/pdr optidlss：/pdr dlss 的旧别名" });
    }

    protected override void Uninit()
    {
        if (primaryCommandRegistered) CommandManager.Instance().RemoveSubCommand("dlss");
        if (legacyCommandRegistered) CommandManager.Instance().RemoveSubCommand("optidlss");
        DService.Instance().Framework.Update -= OnBridgeUpdate;
        bridgeCancellation?.Cancel();
        bridgeCancellation?.Dispose();
        bridgeCancellation = null;
        bridgeTask = null;
        refresh.Completed -= OnRefreshCompleted;
        refresh.Cancel();
    }

    protected override void ConfigUI() => DrawUI();
    protected override void OverlayUI() => DrawUI();

    private void DrawUI()
    {
        ImGui.TextUnformatted("DLSS 模型 / Render Preset");
        ImGui.BeginDisabled(Busy);
        ImGui.SetNextItemWidth(360);
        if (ImGui.BeginCombo("模型###Preset", PresetName(config.SelectedRenderPreset)))
        {
            for (var value = 1; value <= 15; value++)
            {
                if (ImGui.Selectable(PresetName(value), config.SelectedRenderPreset == value))
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
        ImGui.TextWrapped(PresetHelp.Description(config.SelectedRenderPreset));
        ImGui.SetNextItemWidth(360);
        var currentQuality = config.SelectedQualityProfile >= 0
            ? $"{QualityNames[config.SelectedQualityProfile]} ({QualityRatios[config.SelectedQualityProfile]:F1})"
            : "当前比例未对应默认档位，请选择";
        if (ImGui.BeginCombo("档位###Quality", currentQuality))
        {
            for (var value = 0; value < QualityNames.Length; value++)
            {
                if (ImGui.Selectable($"{QualityNames[value]} ({QualityRatios[value]:F1})", config.SelectedQualityProfile == value))
                { config.SelectedQualityProfile = value; SaveConfig(config); }
            }
            ImGui.EndCombo();
        }
        var selectionHint = PresetHelp.SelectionHint(config.SelectedRenderPreset, config.SelectedQualityProfile);
        if (selectionHint.Length != 0) ImGui.TextWrapped(selectionHint);
        ImGui.TextDisabled($"DLSS 文件版本：{dlssFileVersion}（配置文件所在目录）");
        ImGui.TextDisabled("预设是否实际应用取决于 DLSS 版本和游戏集成。");
        ImGui.Spacing();
        if (ImGui.Button("写入配置")) Apply(false);
        ImGui.SameLine();
        if (ImGui.Button("刷新生效")) StartRefresh();
        ImGui.SameLine();
        if (ImGui.Button("写入并刷新生效")) Apply(true);
        ImGui.EndDisabled();

        ImGui.TextWrapped(readStatus);
        ImGui.TextWrapped(writeStatus);
        ImGui.TextWrapped(refresh.Status);
        if (config.UseRuntimeBridge) ImGui.TextWrapped(bridgeStatus);
        ImGui.TextDisabled("写入配置会保存供下次启动读取；刷新效果以游戏实测为准。");

        if (ImGui.CollapsingHeader("配置文件"))
        {
            ImGui.BeginDisabled(Busy);
            ImGui.SetNextItemWidth(520);
            ImGui.InputText("路径###IniPath", ref config.IniPath, 1024);
            if (ImGui.IsItemDeactivatedAfterEdit()) { config.IniPath = config.IniPath.Trim().Trim('"'); SaveConfig(config); }
            if (ImGui.Button("自动定位")) { config.IniPath = DetectIniPath(); SaveConfig(config); ReadSettings(); }
            ImGui.SameLine();
            if (ImGui.Button("重新读取")) ReadSettings();
            ImGui.EndDisabled();
        }
        if (ImGui.CollapsingHeader("高级刷新设置")) DrawRefreshSettings();
        if (ImGui.CollapsingHeader("运行时桥接（可选）")) DrawBridgeSettings();
        if (ImGui.CollapsingHeader("快捷命令"))
        {
            ImGui.TextUnformatted("/pdr dlss：打开界面\n/pdr dlss dlaa | uq | quality | balanced | performance | up：写入并刷新\n/pdr dlss apply：只写入\n/pdr dlss refresh：只刷新\n/pdr dlss preset K：选择模型并写入刷新\n/pdr dlss select quality：只选择挡位\n旧命令 /pdr optidlss 仍可用。");
            if (!primaryCommandRegistered) ImGui.TextWrapped("/pdr dlss 已被其他模块占用，请关闭旧模块后重新启用本模块。");
        }
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

    private void DrawBridgeSettings()
    {
        ImGui.TextWrapped("桥接向定制 OptiScaler 请求在当前游戏中应用设置。配置保存不依赖它。");
        ImGui.BeginDisabled(Busy);
        if (ImGui.Checkbox("启用运行时桥接", ref config.UseRuntimeBridge)) SaveConfig(config);
        ImGui.SetNextItemWidth(360);
        ImGui.InputText("管道名", ref config.BridgePipeName, 128);
        if (ImGui.IsItemDeactivatedAfterEdit()) SaveConfig(config);
        if (ImGui.InputInt("请求超时毫秒", ref config.BridgeTimeoutMs))
        { config.BridgeTimeoutMs = Math.Clamp(config.BridgeTimeoutMs, 50, 3000); SaveConfig(config); }
        if (ImGui.Button("检测桥接")) BeginBridge("ping", false);
        ImGui.EndDisabled();
        ImGui.TextWrapped(bridgeStatus);
    }

    private void OnCommand(string command, string args)
    {
        var parts = args.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length == 0) { Overlay!.IsOpen = !Overlay.IsOpen; return; }
        if (Busy) { NotifyHelper.Instance().NotificationWarning("请等待当前刷新或桥接请求结束"); return; }
        var action = parts[0].ToLowerInvariant();
        if (action == "apply" && parts.Length == 1) { Apply(false); return; }
        if (action == "refresh" && parts.Length == 1) { StartRefresh(); return; }
        if (action == "preset" && parts.Length == 2)
        {
            var value = parts[1].ToUpperInvariant();
            var parsed = value.Length == 1 && value[0] >= 'A' && value[0] <= 'O'
                ? value[0] - 'A' + 1 : int.TryParse(value, out var numeric) ? numeric : -1;
            if (parsed is < 1 or > 15) { Error("模型可用 A-O 或 1-15"); return; }
            config.SelectedRenderPreset = parsed;
            SaveConfig(config);
            Apply(true);
            return;
        }
        var selectionOnly = action == "select" && parts.Length == 2;
        var profileCommand = selectionOnly || (action == "set" && parts.Length == 2) ? parts[1].ToLowerInvariant() : action;
        var index = Array.IndexOf(QualityCommands, profileCommand);
        if (index < 0 || (!(selectionOnly || action == "set") && parts.Length != 1))
        { Error("用法：/pdr dlss [dlaa|uq|quality|balanced|performance|up|apply|refresh|preset A-O]"); return; }
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
        try
        {
            var path = Path.GetFullPath(config.IniPath.Trim().Trim('"'));
            var backup = DlssIni.Write(path, config.SelectedRenderPreset, QualityRatios[config.SelectedQualityProfile]);
            writeStatus = $"配置已保存；备份：{Path.GetFileName(backup)}";
            ReadSettings();
            NotifyHelper.Instance().NotificationSuccess("DLSS配置已保存，供下次启动读取");
            if (config.UseRuntimeBridge)
                BeginBridge(BridgeClient.ApplyCommand(config.SelectedRenderPreset, QualityRatios[config.SelectedQualityProfile]), thenRefresh);
            else if (thenRefresh) StartRefresh();
        }
        catch (Exception error) { Error($"写入失败：{error.Message}"); }
    }

    private void BeginBridge(string command, bool thenRefresh)
    {
        if (bridgeTask != null) return;
        bridgeCancellation = new();
        refreshAfterBridge = thenRefresh;
        bridgeStatus = "正在请求桥接……";
        var pipeName = string.IsNullOrWhiteSpace(config.BridgePipeName) ? "OptiScalerDlssBridge" : config.BridgePipeName.Trim();
        // The native bridge's save command operates on the active game's INI, not an arbitrary path.
        if (command != "ping" && !string.Equals(Path.GetFullPath(config.IniPath), Path.GetFullPath(DetectIniPath()), StringComparison.OrdinalIgnoreCase))
        {
            bridgeStatus = "配置已保存；路径与当前游戏目录不同，跳过运行时桥接";
            bridgeCancellation.Dispose();
            bridgeCancellation = null;
            if (thenRefresh) StartRefresh();
            return;
        }
        bridgeTask = BridgeClient.Send(pipeName, config.BridgeTimeoutMs, command, bridgeCancellation.Token);
        DService.Instance().Framework.Update += OnBridgeUpdate;
    }

    private void OnBridgeUpdate(IFramework framework)
    {
        if (bridgeTask == null || !bridgeTask.IsCompleted) return;
        var result = bridgeTask.GetAwaiter().GetResult();
        bridgeTask = null;
        bridgeCancellation?.Dispose();
        bridgeCancellation = null;
        framework.Update -= OnBridgeUpdate;
        bridgeStatus = result.Success ? $"桥接已响应：{result.Message}；画面生效需实测" : $"桥接不可用：{result.Message}；配置写入结果见上方";
        if (refreshAfterBridge) StartRefresh();
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
        dlssFileVersion = ReadDlssFileVersion();
        try
        {
            var lines = File.ReadAllLines(config.IniPath.Trim().Trim('"'));
            var preset = DlssIni.GetValue(lines, "DLSS", "RenderPresetForAll");
            var ratio = DlssIni.GetValue(lines, "UpscaleRatio", "UpscaleRatioOverrideValue");
            config.SelectedRenderPreset = -1;
            config.SelectedQualityProfile = -1;
            if (int.TryParse(preset, NumberStyles.Integer, CultureInfo.InvariantCulture, out var value)) config.SelectedRenderPreset = value;
            if (float.TryParse(ratio, NumberStyles.Float, CultureInfo.InvariantCulture, out var scale))
                config.SelectedQualityProfile = Array.FindIndex(QualityRatios, known => MathF.Abs(known - scale) < 0.0001f);
            readStatus = $"配置文件：Preset={preset ?? "未设置"}，比例={ratio ?? "未设置"}";
            SaveConfig(config);
        }
        catch (Exception error) { readStatus = $"读取失败：{error.Message}"; }
    }

    private void Error(string message)
    { writeStatus = message; NotifyHelper.Instance().NotificationError(message); }

    private static string DetectIniPath() => string.IsNullOrWhiteSpace(Environment.ProcessPath)
        ? string.Empty : Path.Combine(Path.GetDirectoryName(Environment.ProcessPath)!, "OptiScaler.ini");
    private static string PresetName(int value) => PresetHelp.Label(value);

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
        public bool UseRuntimeBridge;
        public string BridgePipeName = "OptiScalerDlssBridge";
        public int BridgeTimeoutMs = 150;
    }
}
