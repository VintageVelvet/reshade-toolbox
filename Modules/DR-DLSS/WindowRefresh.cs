using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Threading;
using Dalamud.Game.Config;
using Dalamud.Plugin.Services;
using FFXIVClientStructs.FFXIV.Client.Graphics.Kernel;
using OmenTools;
using GameFramework = FFXIVClientStructs.FFXIV.Client.System.Framework.Framework;

namespace DailyRoutines.ModulesPublic;

/// <summary>所有窗口和游戏配置操作均由框架线程执行。</summary>
internal sealed class WindowRefresh
{
    private enum Stage { Capture, Resize, Borderless, BorderlessGeometry, OriginalMode, OriginalGeometry, Finish }

    private IFramework? framework;
    private Stage stage;
    private long nextStep;
    private int cancelRequested;
    private uint windowedMode;
    private uint borderlessMode;
    private int delayMs;
    private bool resize;
    private bool requestSwapchain;
    private float scale;
    private nint window;
    private uint originalMode;
    private Rect originalRect;
    private Rect monitorRect;
    private WindowPlacement originalPlacement;
    private bool snapshotReady;
    private bool modeChanged;
    private bool geometryChanged;

    public bool IsRunning { get; private set; }
    public string Status { get; private set; } = "刷新尚未执行";
    public event Action<bool, string>? Completed;

    public bool Start(uint windowedMode, uint borderlessMode, int delayMs, bool resize, bool requestSwapchain, float scale)
    {
        if (IsRunning) return false;
        if (windowedMode > 3 || borderlessMode > 3 || windowedMode == borderlessMode ||
            delayMs < 100 || delayMs > 5000 || !float.IsFinite(scale) || scale < 0.5f || scale > 0.99f)
        {
            Status = "刷新参数无效，请检查窗口模式、等待时间和临时比例";
            return false;
        }

        this.windowedMode = windowedMode;
        this.borderlessMode = borderlessMode;
        this.delayMs = delayMs;
        this.resize = resize;
        this.requestSwapchain = requestSwapchain;
        this.scale = scale;
        snapshotReady = modeChanged = geometryChanged = false;
        window = 0;
        Volatile.Write(ref cancelRequested, 0);
        stage = Stage.Capture;
        nextStep = 0;
        framework = DService.Instance().Framework;
        if (framework.IsInFrameworkUpdateThread)
        {
            try { CaptureOriginal(); }
            catch (Exception ex)
            {
                Status = $"无法开始刷新: {ex.Message}";
                framework = null;
                return false;
            }
        }
        IsRunning = true;
        Status = "等待框架线程开始刷新";
        framework.Update += OnUpdate;
        return true;
    }

    public void Cancel()
    {
        if (!IsRunning) return;
        Volatile.Write(ref cancelRequested, 1);
        // 模块在框架线程卸载时同步恢复；其他线程只发请求，不触碰游戏 API。
        if (framework?.IsInFrameworkUpdateThread == true)
            RestoreAndFinish("刷新已取消");
    }

    private void OnUpdate(IFramework _)
    {
        if (!IsRunning) return;
        if (Volatile.Read(ref cancelRequested) != 0)
        {
            RestoreAndFinish("刷新已取消");
            return;
        }
        if (Environment.TickCount64 < nextStep) return;

        try
        {
            switch (stage)
            {
                case Stage.Capture:
                    if (!snapshotReady) CaptureOriginal();
                    modeChanged = true; // Set 抛出异常时也尝试恢复。
                    SetMode(windowedMode);
                    Status = "已请求临时窗口模式";
                    Advance(resize ? Stage.Resize : Stage.Borderless);
                    break;
                case Stage.Resize:
                    EnsureWindow();
                    geometryChanged = true;
                    ShowWindow(window, SW_RESTORE);
                    var temporaryRect = BuildScaledRect(monitorRect, scale);
                    SetRect(temporaryRect);
                    if (requestSwapchain) RequestResolution(temporaryRect.Width, temporaryRect.Height);
                    Status = "已调整临时窗口尺寸";
                    Advance(Stage.Borderless);
                    break;
                case Stage.Borderless:
                    SetMode(borderlessMode);
                    Status = "已请求无边框模式";
                    Advance(Stage.BorderlessGeometry);
                    break;
                case Stage.BorderlessGeometry:
                    // Restore the original refresh's explicit full-monitor resolution request
                    // while still borderless, before restoring the user's original mode.
                    if (resize)
                    {
                        geometryChanged = true;
                        SetRect(monitorRect);
                    }
                    if (requestSwapchain) RequestResolution(monitorRect.Width, monitorRect.Height);
                    Status = "已请求无边框输出尺寸重建";
                    Advance(Stage.OriginalMode);
                    break;
                case Stage.OriginalMode:
                    if (originalMode == borderlessMode)
                    {
                        Advance(Stage.OriginalGeometry, 0);
                        break;
                    }
                    SetMode(originalMode);
                    Status = "正在恢复原窗口模式";
                    Advance(Stage.OriginalGeometry);
                    break;
                case Stage.OriginalGeometry:
                    var restored = RestoreGeometry();
                    Status = "正在等待原窗口状态稳定";
                    Advance(Stage.Finish, restored ? delayMs : 0);
                    break;
                case Stage.Finish:
                    if (!DService.Instance().GameConfig.System.TryGet(nameof(SystemConfigOption.ScreenMode), out uint actualMode) ||
                        actualMode != originalMode)
                        throw new InvalidOperationException("原窗口模式尚未恢复");
                    Finish(true, "窗口刷新已执行，已恢复原窗口模式和位置");
                    break;
            }
        }
        catch (Exception ex)
        {
            RestoreAndFinish($"刷新失败: {ex.Message}");
        }
    }

    private unsafe void CaptureOriginal()
    {
        if (!DService.Instance().GameConfig.System.TryGet(nameof(SystemConfigOption.ScreenMode), out originalMode))
            throw new InvalidOperationException("无法读取当前屏幕模式");
        var game = GameFramework.Instance();
        if (game == null || game->GameWindow == null)
            throw new InvalidOperationException("无法获取游戏窗口");
        window = game->GameWindow->WindowHandle;
        EnsureWindow();
        if (IsIconic(window)) throw new InvalidOperationException("请先还原最小化的游戏窗口");
        if (!GetWindowRect(window, out originalRect) || !originalRect.IsValid)
            throw new InvalidOperationException("无法读取有效的原窗口尺寸");
        originalPlacement = new WindowPlacement { Length = Marshal.SizeOf<WindowPlacement>() };
        if (!GetWindowPlacement(window, ref originalPlacement))
            throw new InvalidOperationException("无法读取原窗口状态");
        monitorRect = originalRect;
        var monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
        var info = new MonitorInfo { Size = Marshal.SizeOf<MonitorInfo>() };
        if (monitor != 0 && GetMonitorInfoW(monitor, ref info) && info.Monitor.IsValid)
            monitorRect = info.Monitor;
        snapshotReady = true;
    }

    private void Advance(Stage next, int? waitMs = null)
    {
        stage = next;
        nextStep = Environment.TickCount64 + (waitMs ?? delayMs);
    }

    private static void SetMode(uint value) =>
        DService.Instance().GameConfig.System.Set(nameof(SystemConfigOption.ScreenMode), value);

    private void EnsureWindow()
    {
        if (window == 0 || !IsWindow(window)) throw new InvalidOperationException("游戏窗口已不可用");
    }

    private void SetRect(Rect rect)
    {
        EnsureWindow();
        if (!SetWindowPos(window, 0, rect.Left, rect.Top, rect.Width, rect.Height,
                          SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "调整游戏窗口失败");
    }

    private bool RestoreGeometry()
    {
        EnsureWindow();
        var changed = false;
        // A no-op SetWindowPos/SetWindowPlacement can still provoke another game resize.
        // Skip only after observing the actual original rectangle and placement.
        if (!GetWindowRect(window, out var actualRect) || !actualRect.SameAs(originalRect))
        {
            SetRect(originalRect);
            changed = true;
        }
        // 同时恢复最大化状态及最大化前的正常窗口位置，避免改变后续“还原”尺寸。
        var actualPlacement = new WindowPlacement { Length = Marshal.SizeOf<WindowPlacement>() };
        if (!GetWindowPlacement(window, ref actualPlacement) || !actualPlacement.SameAs(originalPlacement))
        {
            if (!SetWindowPlacement(window, in originalPlacement))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "恢复原窗口状态失败");
            changed = true;
        }
        if (requestSwapchain) changed |= RequestResolution();
        return changed;
    }

    private unsafe bool RequestResolution()
    {
        EnsureWindow();
        if (!GetClientRect(window, out var rect) || !rect.IsValid)
            throw new InvalidOperationException("无法读取窗口客户区尺寸");
        var device = Device.Instance();
        if (device == null) throw new InvalidOperationException("图形设备尚不可用");
        // Keep the two deliberate resize requests above. Only the final restoration may
        // reuse a completed swap chain when both dimensions match and no change is pending.
        if (device->RequestResolutionChange == 0 && device->SwapChain != null &&
            device->SwapChain->Width == (uint)rect.Width && device->SwapChain->Height == (uint)rect.Height)
            return false;
        RequestResolution(rect.Width, rect.Height);
        return true;
    }

    private static unsafe void RequestResolution(int width, int height)
    {
        if (width <= 0 || height <= 0) throw new InvalidOperationException("输出尺寸无效");
        var device = Device.Instance();
        if (device == null) throw new InvalidOperationException("图形设备尚不可用");
        device->NewWidth = (uint)width;
        device->NewHeight = (uint)height;
        device->RequestResolutionChange = 1;
    }

    private void RestoreAndFinish(string message)
    {
        string? modeError = null;
        string? geometryError = null;
        if (snapshotReady && (modeChanged || geometryChanged))
        {
            try { SetMode(originalMode); }
            catch (Exception ex) { modeError = ex.Message; }
            try { RestoreGeometry(); }
            catch (Exception ex) { geometryError = ex.Message; }
        }
        if (modeError != null) message += $"；恢复原模式失败: {modeError}";
        if (geometryError != null) message += $"；恢复原窗口失败: {geometryError}";
        Finish(false, message);
    }

    private void Finish(bool success, string message)
    {
        if (framework != null) framework.Update -= OnUpdate;
        framework = null;
        IsRunning = false;
        snapshotReady = modeChanged = geometryChanged = false;
        Status = message;
        try { Completed?.Invoke(success, message); }
        catch (Exception ex) { Status += $"；完成通知失败: {ex.Message}"; }
    }

    private static Rect BuildScaledRect(Rect source, float scale)
    {
        var width = Math.Clamp((int)MathF.Round(source.Width * scale), Math.Min(640, source.Width), source.Width);
        var height = Math.Clamp((int)MathF.Round(source.Height * scale), Math.Min(480, source.Height), source.Height);
        var left = source.Left + (source.Width - width) / 2;
        var top = source.Top + (source.Height - height) / 2;
        return new Rect { Left = left, Top = top, Right = left + width, Bottom = top + height };
    }

    private const uint SWP_NOZORDER = 0x0004, SWP_NOACTIVATE = 0x0010, SWP_FRAMECHANGED = 0x0020;
    private const uint MONITOR_DEFAULTTONEAREST = 2;
    private const int SW_RESTORE = 9;

    [StructLayout(LayoutKind.Sequential)]
    private struct Rect
    {
        public int Left, Top, Right, Bottom;
        public readonly int Width => Right - Left;
        public readonly int Height => Bottom - Top;
        public readonly bool IsValid => Width > 0 && Height > 0;
        public readonly bool SameAs(Rect other) =>
            Left == other.Left && Top == other.Top && Right == other.Right && Bottom == other.Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MonitorInfo { public int Size; public Rect Monitor, Work; public uint Flags; }

    [StructLayout(LayoutKind.Sequential)]
    private struct Point
    {
        public int X, Y;
        public readonly bool SameAs(Point other) => X == other.X && Y == other.Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct WindowPlacement
    {
        public int Length;
        public uint Flags, ShowCommand;
        public Point MinimumPosition, MaximumPosition;
        public Rect NormalPosition;
        public readonly bool SameAs(WindowPlacement other) =>
            Flags == other.Flags && ShowCommand == other.ShowCommand &&
            MinimumPosition.SameAs(other.MinimumPosition) && MaximumPosition.SameAs(other.MaximumPosition) &&
            NormalPosition.SameAs(other.NormalPosition);
    }

    [DllImport("user32.dll", ExactSpelling = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindow(nint window);

    [DllImport("user32.dll", ExactSpelling = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsIconic(nint window);

    [DllImport("user32.dll", ExactSpelling = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetWindowPlacement(nint window, ref WindowPlacement placement);

    [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetWindowPlacement(nint window, in WindowPlacement placement);

    [DllImport("user32.dll", ExactSpelling = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetWindowRect(nint window, out Rect rect);

    [DllImport("user32.dll", ExactSpelling = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetClientRect(nint window, out Rect rect);

    [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetWindowPos(nint window, nint insertAfter, int x, int y, int width, int height, uint flags);

    [DllImport("user32.dll", ExactSpelling = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool ShowWindow(nint window, int command);

    [DllImport("user32.dll", ExactSpelling = true)]
    private static extern nint MonitorFromWindow(nint window, uint flags);

    [DllImport("user32.dll", ExactSpelling = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetMonitorInfoW(nint monitor, ref MonitorInfo info);
}
