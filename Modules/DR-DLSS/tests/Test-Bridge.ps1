$ErrorActionPreference = 'Stop'
# Compile the pure transport helper with an isolated server harness. Never use the live pipe.
$taskBridgeSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\RuntimeBridge.cs'))
$taskBridgeHarness = @'

public static class IsolatedBridgeTests
{
    private static int checks;
    private static void Assert(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        checks++;
    }

    private sealed record Outcome(BridgeResult Result, string[] Requests, long Elapsed);

    private static async Task<Outcome> RunCase(string behavior, int preset = 11, float ratio = 1.5f,
        bool wrongPid = false, bool cancel = false, int timeout = 600)
    {
        string name = "dr-dlss-isolated-" + Guid.NewGuid().ToString("N");
        var requests = new System.Collections.Generic.List<string>();
        using var stop = new CancellationTokenSource();
        using var caller = new CancellationTokenSource();
        var ready = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        Task serverTask = Task.Run(async () =>
        {
            int connections = behavior == "retryPing" ? 4 : 2;
            try
            {
                for (int i = 0; i < connections; i++)
                {
                    using var server = new NamedPipeServerStream(name, PipeDirection.InOut, 1,
                        behavior == "byteMode" ? PipeTransmissionMode.Byte : PipeTransmissionMode.Message,
                        PipeOptions.Asynchronous);
                    ready.TrySetResult(true);
                    await server.WaitForConnectionAsync(stop.Token).ConfigureAwait(false);
                    byte[] buffer = new byte[4096];
                    int length = await server.ReadAsync(buffer, 0, buffer.Length, stop.Token).ConfigureAwait(false);
                    if (length == 0) continue;
                    string command = Encoding.UTF8.GetString(buffer, 0, length);
                    requests.Add(command);
                    bool ping = command == "ping";
                    if (behavior == "disconnectSet" && !ping) continue;
                    if (behavior == "retryPing" && i < 2) continue;
                    if (behavior == "timeoutPing" || (behavior == "timeoutSet" && !ping))
                    {
                        await Task.Delay(10000, stop.Token).ConfigureAwait(false);
                        continue;
                    }
                    byte[] response = behavior == "invalidUtf8" ? new byte[] { 0xFF } : Encoding.UTF8.GetBytes(
                        behavior == "oversized" ? new string('x', 5000) :
                        behavior == "rejectPing" && ping ? "error unknown-command" :
                        behavior == "rejectSet" && !ping ? "error bad-ratio" :
                        behavior == "malformedPing" && ping ? "ok bridge-ready extra" :
                        ping ? "ok bridge-ready" : "ok applied");
                    await server.WriteAsync(response, 0, response.Length, stop.Token).ConfigureAwait(false);
                    await server.FlushAsync(stop.Token).ConfigureAwait(false);
                    // The mock follows the Windows pipe contract, unlike the old native patch.
                    if (behavior != "oversized") server.WaitForPipeDrain();
                }
            }
            catch (OperationCanceledException) when (stop.IsCancellationRequested) { }
            catch (IOException) { }
            finally { ready.TrySetResult(true); }
        });
        await ready.Task.ConfigureAwait(false);
        if (cancel) caller.CancelAfter(100);
        var clock = System.Diagnostics.Stopwatch.StartNew();
        BridgeResult result;
        try
        {
            result = await RuntimeBridge.ApplyAsync(preset, ratio, caller.Token, name,
                wrongPid ? Environment.ProcessId + 1 : Environment.ProcessId, timeout).ConfigureAwait(false);
        }
        finally
        {
            stop.Cancel();
            await serverTask.WaitAsync(TimeSpan.FromSeconds(2)).ConfigureAwait(false);
        }
        return new(result, requests.ToArray(), clock.ElapsedMilliseconds);
    }

    public static async Task<string> RunAsync()
    {
        foreach (int preset in new[] { 11, 12, 13 })
        {
            var outcome = await RunCase("success", preset).ConfigureAwait(false);
            Assert(outcome.Result.Success, "Expected confirmed application.");
            Assert(outcome.Requests.Length == 2 && outcome.Requests[0] == "ping" &&
                outcome.Requests[1] == $"set ratio 1.500000 preset {preset} save 0", "Wrong command sequence or save flag.");
        }
        var originalCulture = CultureInfo.CurrentCulture;
        try
        {
            CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("fr-FR");
            var culture = await RunCase("success").ConfigureAwait(false);
            Assert(culture.Result.Success && culture.Requests[1].Contains("1.500000"), "Ratio formatting depends on locale.");
        }
        finally { CultureInfo.CurrentCulture = originalCulture; }

        foreach (string behavior in new[] { "rejectPing", "malformedPing", "oversized", "invalidUtf8", "byteMode" })
        {
            var rejected = await RunCase(behavior).ConfigureAwait(false);
            Assert(!rejected.Result.Success, "Accepted bad protocol: " + behavior);
            Assert(Array.TrueForAll(rejected.Requests, request => request == "ping"), "Sent set after invalid ping.");
        }
        var wrong = await RunCase("success", wrongPid: true).ConfigureAwait(false);
        Assert(!wrong.Result.Success && wrong.Result.Message.Contains("进程"), "Accepted wrong pipe owner.");
        Assert(wrong.Requests.Length == 0, "Sent command to wrong process.");

        var retry = await RunCase("retryPing").ConfigureAwait(false);
        Assert(retry.Result.Success && retry.Requests.Length == 4, "Read-only ping retry failed.");
        Assert(retry.Requests[0] == "ping" && retry.Requests[1] == "ping" && retry.Requests[2] == "ping",
            "Retry sent a mutating command.");

        foreach (string behavior in new[] { "rejectSet", "disconnectSet", "timeoutSet" })
        {
            var unconfirmed = await RunCase(behavior, timeout: 150).ConfigureAwait(false);
            Assert(!unconfirmed.Result.Success && unconfirmed.Result.Message.Contains("结果未确认"),
                "Lost unconfirmed application status: " + behavior);
            Assert(unconfirmed.Requests.Length == 2, "Retried a possibly applied set command.");
            Assert(unconfirmed.Elapsed < 1500, "Total operation exceeded timeout bound.");
        }
        var pingTimeout = await RunCase("timeoutPing", timeout: 100).ConfigureAwait(false);
        Assert(!pingTimeout.Result.Success && pingTimeout.Result.Message.Contains("超时") &&
            !pingTimeout.Result.Message.Contains("可能已应用"), "Incorrect ping timeout result.");
        Assert(pingTimeout.Requests.Length == 1, "Sent set after timed-out ping.");
        var cancellation = await RunCase("timeoutSet", cancel: true).ConfigureAwait(false);
        Assert(!cancellation.Result.Success && cancellation.Result.Message.Contains("已取消") &&
            cancellation.Result.Message.Contains("结果未确认"), "Cancellation lost pending-set status.");
        Assert(cancellation.Requests.Length == 2, "Retried set after cancellation.");

        using var alreadyCancelled = new CancellationTokenSource();
        alreadyCancelled.Cancel();
        string absentPipe = "dr-dlss-no-server-" + Guid.NewGuid().ToString("N");
        var cancelled = await RuntimeBridge.ApplyAsync(11, 1f, alreadyCancelled.Token, absentPipe,
            Environment.ProcessId, 100).ConfigureAwait(false);
        Assert(!cancelled.Success && cancelled.Message.Contains("已取消"), "Pre-cancellation ignored.");
        var missing = await RuntimeBridge.ApplyAsync(11, 1f, CancellationToken.None, absentPipe,
            Environment.ProcessId, 100).ConfigureAwait(false);
        Assert(!missing.Success && missing.Message.Contains("超时"), "Missing server did not time out.");
        var defaultPreset = await RuntimeBridge.ApplyAsync(0, 1f, CancellationToken.None, absentPipe,
            Environment.ProcessId, 100).ConfigureAwait(false);
        Assert(!defaultPreset.Success && defaultPreset.Message.Contains("无法关闭模型覆盖"), "Default preset was sent to old protocol.");
        foreach (int preset in new[] { -1, 1, 10, 14, 15 })
        {
            var invalid = await RuntimeBridge.ApplyAsync(preset, 1f, CancellationToken.None, absentPipe,
                Environment.ProcessId, 100).ConfigureAwait(false);
            Assert(!invalid.Success && invalid.Message.Contains("无效"), "Accepted invalid preset.");
        }
        foreach (float ratio in new[] { float.NaN, float.PositiveInfinity, 0.5f, 3.1f })
        {
            var invalid = await RuntimeBridge.ApplyAsync(11, ratio, CancellationToken.None, absentPipe,
                Environment.ProcessId, 100).ConfigureAwait(false);
            Assert(!invalid.Success && invalid.Message.Contains("无效"), "Accepted invalid ratio.");
        }
        return $"Bridge checks passed: {checks}. Only randomly named mock pipes were used; no live set/save was sent.";
    }
}
'@
Add-Type -TypeDefinition ($taskBridgeSource + [Environment]::NewLine + $taskBridgeHarness)
[DailyRoutines.ModulesPublic.IsolatedBridgeTests]::RunAsync().GetAwaiter().GetResult()
