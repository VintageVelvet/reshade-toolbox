#nullable enable
using System;
using System.Globalization;
using System.IO;
using System.IO.Pipes;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace DailyRoutines.ModulesPublic;

internal static class BridgeClient
{
    internal readonly record struct Result(bool Success, string Message);

    internal static string ApplyCommand(int preset, float ratio) =>
        string.Create(CultureInfo.InvariantCulture, $"set ratio {ratio:F6} preset {preset} save 1");

    internal static async Task<Result> Send(string pipeName, int timeoutMs, string command, CancellationToken cancellationToken)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(Math.Clamp(timeoutMs, 50, 3000));
        try
        {
            using var pipe = new NamedPipeClientStream(".", pipeName, PipeDirection.InOut, PipeOptions.Asynchronous);
            await pipe.ConnectAsync(timeout.Token).ConfigureAwait(false);
            pipe.ReadMode = PipeTransmissionMode.Message;
            var request = Encoding.UTF8.GetBytes(command);
            await pipe.WriteAsync(request.AsMemory(), timeout.Token).ConfigureAwait(false);
            await pipe.FlushAsync(timeout.Token).ConfigureAwait(false);
            using var response = new MemoryStream();
            var buffer = new byte[1024];
            do
            {
                var read = await pipe.ReadAsync(buffer.AsMemory(), timeout.Token).ConfigureAwait(false);
                if (read == 0) return new(false, "桥接未返回响应");
                response.Write(buffer, 0, read);
                if (response.Length > 4096) return new(false, "桥接响应超过长度限制");
            } while (!pipe.IsMessageComplete);
            var text = Encoding.UTF8.GetString(response.ToArray()).Trim();
            var expected = command == "ping" ? "ok bridge-ready" : "ok applied";
            return new(string.Equals(text, expected, StringComparison.OrdinalIgnoreCase), text);
        }
        catch (OperationCanceledException)
        {
            return new(false, cancellationToken.IsCancellationRequested ? "桥接请求已取消" : "桥接请求超时");
        }
        catch (Exception error)
        {
            return new(false, error.Message);
        }
    }
}
