#nullable enable
using System;
using System.Globalization;
using System.IO;
using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32.SafeHandles;

namespace DailyRoutines.ModulesPublic;

public sealed record BridgeResult(bool Success, string Message);

/// <summary>Client for the supplied OptiScaler bridge patch; it never loads a native DLL.</summary>
public static class RuntimeBridge
{
    private const string DefaultPipeName = "OptiScalerDlssBridge";
    private const int MaximumResponseBytes = 4096;
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);

    public static Task<BridgeResult> ApplyAsync(int preset, float ratio, CancellationToken token) =>
        ApplyAsync(preset, ratio, token, DefaultPipeName, Environment.ProcessId, 3000);

    // The explicit transport parameters let isolated tests use their own pipe and server process.
    public static async Task<BridgeResult> ApplyAsync(int preset, float ratio, CancellationToken token,
        string pipeName, int expectedProcessId, int timeoutMs)
    {
        if (preset == 0)
            return new(false, "旧桥接协议无法关闭模型覆盖，游戏默认暂不支持热切换");
        if (preset is not (11 or 12 or 13) || !float.IsFinite(ratio) || ratio < 1f || ratio > 3f)
            return new(false, "桥接模型或比例无效");
        if (string.IsNullOrWhiteSpace(pipeName) || expectedProcessId <= 0 || timeoutMs < 1 || timeoutMs > 3000)
            return new(false, "桥接连接参数无效");

        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(token);
        deadline.CancelAfter(timeoutMs);
        bool setMayHaveBeenSent = false;
        try
        {
            // The old server disconnects without FlushFileBuffers. Queue the read first; only
            // the read-only ping may be retried. Never resend a possibly applied set command.
            for (int attempt = 0; ; attempt++)
            {
                try
                {
                    await ExchangeAsync(pipeName, expectedProcessId, "ping", "ok bridge-ready", deadline.Token,
                        null).ConfigureAwait(false);
                    break;
                }
                catch (IOException) when (attempt < 2 && !deadline.IsCancellationRequested) { }
            }
            deadline.Token.ThrowIfCancellationRequested();
            string command = string.Create(CultureInfo.InvariantCulture,
                $"set ratio {ratio:F6} preset {preset} save 0");
            await ExchangeAsync(pipeName, expectedProcessId, command, "ok applied", deadline.Token,
                () => setMayHaveBeenSent = true).ConfigureAwait(false);
            return new(true, "桥接更新已提交");
        }
        catch (OperationCanceledException)
        {
            string reason = token.IsCancellationRequested ? "桥接操作已取消" : "桥接操作超时";
            return new(false, WithUnconfirmed(reason, setMayHaveBeenSent));
        }
        catch (Exception error)
        {
            return new(false, WithUnconfirmed($"桥接失败：{error.Message}", setMayHaveBeenSent));
        }
    }

    private static string WithUnconfirmed(string message, bool sent) => sent
        ? message + "；结果未确认，桥接可能已应用" : message;

    private static async Task ExchangeAsync(string pipeName, int expectedProcessId, string command,
        string expectedResponse, CancellationToken token, Action? beforeSend)
    {
        using var pipe = new NamedPipeClientStream(".", pipeName, PipeDirection.InOut, PipeOptions.Asynchronous);
        await pipe.ConnectAsync(token).ConfigureAwait(false);
        if (!GetNamedPipeServerProcessId(pipe.SafePipeHandle, out uint serverProcessId))
            throw new InvalidOperationException("无法验证桥接服务所属进程");
        if (serverProcessId != (uint)expectedProcessId)
            throw new InvalidOperationException("桥接服务不属于当前游戏进程");
        pipe.ReadMode = PipeTransmissionMode.Message;

        byte[] response = new byte[MaximumResponseBytes];
        // Posting the overlapped read before WriteAsync reduces the known response/disconnect
        // race in the supplied server. Its protocol uses one connection per command.
        Task<int> pendingRead = pipe.ReadAsync(response, 0, response.Length, token);
        try
        {
            byte[] request = StrictUtf8.GetBytes(command);
            token.ThrowIfCancellationRequested();
            beforeSend?.Invoke();
            await pipe.WriteAsync(request, 0, request.Length, token).ConfigureAwait(false);
            await pipe.FlushAsync(token).ConfigureAwait(false);

            int length = await pendingRead.ConfigureAwait(false);
            if (length == 0) throw new IOException("桥接在返回确认前断开连接");
            if (!pipe.IsMessageComplete)
                throw new InvalidOperationException("桥接响应超过限制或被截断");
            string text = StrictUtf8.GetString(response, 0, length);
            if (!string.Equals(text, expectedResponse, StringComparison.Ordinal))
                throw new InvalidOperationException("桥接返回未识别或拒绝响应");
        }
        finally
        {
            // A failed write can leave the pre-posted read outstanding. End and observe it
            // without replacing the original transport error with a cleanup exception.
            if (!pendingRead.IsCompleted) pipe.Dispose();
            try { await pendingRead.ConfigureAwait(false); } catch { }
        }
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetNamedPipeServerProcessId(SafePipeHandle pipe, out uint processId);
}
