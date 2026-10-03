$ErrorActionPreference = 'Stop'
$taskClientSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\BridgeClient.cs') -Raw
$taskHarnessSource = @'

public static class BridgeTestHarness
{
    public sealed class Outcome
    {
        public bool Success { get; set; }
        public string Message { get; set; } = "";
        public string Request { get; set; } = "";
        public long ElapsedMs { get; set; }
    }

    // Every scenario uses a private random pipe, never OptiScalerDlssBridge.
    public static async Task<Outcome> Scenario(string response, string command, int timeoutMs,
        int responseDelayMs = 0, bool disconnect = false, int cancelAfterMs = 0)
    {
        string name = "dr-dlss-test-" + Guid.NewGuid().ToString("N");
        using var server = new NamedPipeServerStream(name, PipeDirection.InOut, 1,
            PipeTransmissionMode.Message, PipeOptions.Asynchronous);
        using var serverStop = new CancellationTokenSource(5000);
        using var clientStop = new CancellationTokenSource();
        if (cancelAfterMs > 0) clientStop.CancelAfter(cancelAfterMs);
        string received = "";
        async Task Serve()
        {
            await server.WaitForConnectionAsync(serverStop.Token).ConfigureAwait(false);
            using var request = new MemoryStream();
            var buffer = new byte[256];
            do
            {
                int read = await server.ReadAsync(buffer.AsMemory(), serverStop.Token).ConfigureAwait(false);
                if (read == 0) return;
                request.Write(buffer, 0, read);
            } while (!server.IsMessageComplete);
            received = Encoding.UTF8.GetString(request.ToArray());
            if (disconnect) { server.Disconnect(); return; }
            if (responseDelayMs > 0) await Task.Delay(responseDelayMs, serverStop.Token).ConfigureAwait(false);
            byte[] reply = Encoding.UTF8.GetBytes(response);
            // One native message larger than the client's 1024-byte buffer forces repeated reads.
            await server.WriteAsync(reply.AsMemory(), serverStop.Token).ConfigureAwait(false);
            await server.FlushAsync(serverStop.Token).ConfigureAwait(false);
        }
        Task serving = Serve();
        var watch = System.Diagnostics.Stopwatch.StartNew();
        BridgeClient.Result result = await BridgeClient.Send(name, timeoutMs, command, clientStop.Token).ConfigureAwait(false);
        watch.Stop();
        serverStop.Cancel();
        try { await serving.ConfigureAwait(false); }
        catch (OperationCanceledException) { }
        catch (IOException) { }
        return new Outcome { Success = result.Success, Message = result.Message, Request = received, ElapsedMs = watch.ElapsedMilliseconds };
    }

    public static async Task<Outcome> MissingServer(int timeoutMs)
    {
        string name = "dr-dlss-test-missing-" + Guid.NewGuid().ToString("N");
        var watch = System.Diagnostics.Stopwatch.StartNew();
        BridgeClient.Result result = await BridgeClient.Send(name, timeoutMs, "ping", CancellationToken.None).ConfigureAwait(false);
        watch.Stop();
        return new Outcome { Success = result.Success, Message = result.Message, ElapsedMs = watch.ElapsedMilliseconds };
    }

    public static string CommandUnderFrenchCulture()
    {
        CultureInfo original = CultureInfo.CurrentCulture;
        try
        {
            CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("fr-FR");
            return BridgeClient.ApplyCommand(13, 1.5f);
        }
        finally { CultureInfo.CurrentCulture = original; }
    }
}
'@
Add-Type -TypeDefinition ($taskClientSource + $taskHarnessSource)
$taskChecks = 0
function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
    $script:taskChecks++
}
function Invoke-Scenario([string] $Response, [string] $Command = 'ping', [int] $TimeoutMs = 1000,
    [int] $DelayMs = 0, [bool] $Disconnect = $false, [int] $CancelAfterMs = 0) {
    [DailyRoutines.ModulesPublic.BridgeTestHarness]::Scenario($Response, $Command, $TimeoutMs, $DelayMs, $Disconnect, $CancelAfterMs).GetAwaiter().GetResult()
}

$taskCommand = [DailyRoutines.ModulesPublic.BridgeTestHarness]::CommandUnderFrenchCulture()
Assert-True ($taskCommand -ceq 'set ratio 1.500000 preset 13 save 1') 'ApplyCommand depends on current culture or differs from native protocol.'

$taskResult = Invoke-Scenario 'ok bridge-ready'
Assert-True ($taskResult.Success -and $taskResult.Request -ceq 'ping') 'Ping exchange failed.'

$taskResult = Invoke-Scenario (' ' * 1500 + 'ok bridge-ready' + ' ' * 1500)
Assert-True ($taskResult.Success -and $taskResult.Message -ceq 'ok bridge-ready') 'A message spanning multiple reads was truncated.'

$taskResult = Invoke-Scenario 'ok applied' $taskCommand
Assert-True ($taskResult.Success -and $taskResult.Request -ceq $taskCommand) 'Apply exchange did not preserve the command.'

foreach ($taskResponse in @('ok-other', 'ok', 'ok applied', 'error save-failed')) {
    $taskResult = Invoke-Scenario $taskResponse
    Assert-True (-not $taskResult.Success) ('Ping incorrectly accepted response: ' + $taskResponse)
}
$taskResult = Invoke-Scenario 'ok bridge-ready' $taskCommand
Assert-True (-not $taskResult.Success) 'Apply incorrectly accepted ping acknowledgement.'

$taskResult = Invoke-Scenario 'ok bridge-ready' 'ping' 120 1000
Assert-True (-not $taskResult.Success -and $taskResult.Message -ceq '桥接请求超时') 'Response wait did not use the deadline.'
Assert-True ($taskResult.ElapsedMs -lt 1500) 'Response timeout took too long.'

$taskResult = [DailyRoutines.ModulesPublic.BridgeTestHarness]::MissingServer(120).GetAwaiter().GetResult()
Assert-True (-not $taskResult.Success -and $taskResult.Message -ceq '桥接请求超时') 'Connection wait did not use the deadline.'
Assert-True ($taskResult.ElapsedMs -lt 1500) 'Connection timeout took too long.'

$taskResult = Invoke-Scenario 'ok bridge-ready' 'ping' 2000 1000 $false 60
Assert-True (-not $taskResult.Success -and $taskResult.Message -ceq '桥接请求已取消') 'Caller cancellation was not distinguished from timeout.'
Assert-True ($taskResult.ElapsedMs -lt 1500) 'Caller cancellation took too long.'

$taskResult = Invoke-Scenario '' 'ping' 1000 0 $true
Assert-True (-not $taskResult.Success) 'Disconnected server was accepted.'

$taskResult = Invoke-Scenario ('x' * 4097)
Assert-True (-not $taskResult.Success -and $taskResult.Message -ceq '桥接响应超过长度限制') 'Oversized response was accepted.'

Write-Output ("PASS: {0} checks; random isolated pipes only, no game pipe was contacted." -f $taskChecks)
