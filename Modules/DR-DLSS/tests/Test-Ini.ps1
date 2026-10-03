param(
    [string] $SourceIni = (Join-Path $env:USERPROFILE 'Downloads\最终幻想XIV\game\OptiScaler.ini')
)

$ErrorActionPreference = 'Stop'
Add-Type -Path (Join-Path $PSScriptRoot '..\DlssIni.cs')
$taskTestRoot = Join-Path ([IO.Path]::GetTempPath()) ('dr-dlss-ini-test-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($taskTestRoot) | Out-Null
$taskChecks = 0

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
    $script:taskChecks++
}

function Assert-Bytes([byte[]] $Expected, [byte[]] $Actual, [string] $Message) {
    Assert-True ([Convert]::ToBase64String($Expected) -ceq [Convert]::ToBase64String($Actual)) $Message
}

function Get-UnrelatedText([string] $Text) {
    $taskSection = ''
    $taskResult = [Text.StringBuilder]::new()
    $taskControlled = @{
        Upscalers = @('Dx11Upscaler')
        DLSS = @('RenderPresetOverride', 'RenderPresetForAll')
        UpscaleRatio = @('UpscaleRatioOverrideEnabled', 'UpscaleRatioOverrideValue')
    }
    foreach ($taskMatch in [regex]::Matches($Text, '[^\r\n]*(?:\r\n|\r|\n|$)')) {
        if ($taskMatch.Length -eq 0) { continue }
        $taskLine = $taskMatch.Value.TrimEnd("`r", "`n")
        if ($taskLine -match '^\s*\[([^\]]+)\]') { $taskSection = $Matches[1].Trim() }
        if ($taskLine -match '^\s*([^;#=]+?)\s*=') {
            if ($taskControlled.ContainsKey($taskSection) -and $Matches[1].Trim() -in $taskControlled[$taskSection]) { continue }
        }
        [void] $taskResult.Append($taskMatch.Value)
    }
    $taskResult.ToString()
}

try {
    $taskActual = Join-Path $taskTestRoot 'actual-copy.ini'
    Copy-Item -LiteralPath $SourceIni -Destination $taskActual
    $taskOriginal = [IO.File]::ReadAllBytes($taskActual)
    $taskOriginalText = [IO.File]::ReadAllText($taskActual)
    $taskBackup = [DailyRoutines.ModulesPublic.DlssIni]::Write($taskActual, 13, 1.5)
    Assert-Bytes $taskOriginal ([IO.File]::ReadAllBytes($taskBackup)) 'Backup differs from original bytes.'
    $taskWritten = [IO.File]::ReadAllLines($taskActual)
    foreach ($taskExpected in @(
        @('Upscalers','Dx11Upscaler','dlss'),
        @('DLSS','RenderPresetOverride','true'), @('DLSS','RenderPresetForAll','13'),
        @('UpscaleRatio','UpscaleRatioOverrideEnabled','true'), @('UpscaleRatio','UpscaleRatioOverrideValue','1.500000')
    )) {
        Assert-True ([DailyRoutines.ModulesPublic.DlssIni]::GetValue($taskWritten,$taskExpected[0],$taskExpected[1]) -ceq $taskExpected[2]) ('Unexpected value: ' + $taskExpected[1])
    }
    Assert-True ((Get-UnrelatedText $taskOriginalText) -ceq (Get-UnrelatedText ([IO.File]::ReadAllText($taskActual)))) 'An unrelated line or newline changed.'
    [IO.File]::Copy($taskBackup, $taskActual, $true)
    Assert-Bytes $taskOriginal ([IO.File]::ReadAllBytes($taskActual)) 'Restoring the backup did not restore original bytes.'

    $taskFixture = Join-Path $taskTestRoot 'duplicates-bom.ini'
    $taskFixtureText = "; keep this comment`r`n[DLSS]`r`nEnabled = false ; keep inline`r`nRenderPresetForAll=1`r`nrenderpresetforall = 2`r`n[Other]`r`nKeep = 中文`r`n[DLSS]`r`nRenderPresetForAll = 3`r`n"
    [IO.File]::WriteAllText($taskFixture, $taskFixtureText, [Text.UTF8Encoding]::new($true))
    $taskFixtureOriginal = [IO.File]::ReadAllBytes($taskFixture)
    $taskFixtureBackup = [DailyRoutines.ModulesPublic.DlssIni]::Write($taskFixture, 11, 2)
    Assert-Bytes $taskFixtureOriginal ([IO.File]::ReadAllBytes($taskFixtureBackup)) 'Fixture backup differs.'
    $taskFixtureBytes = [IO.File]::ReadAllBytes($taskFixture)
    Assert-True ($taskFixtureBytes[0] -eq 0xEF -and $taskFixtureBytes[1] -eq 0xBB -and $taskFixtureBytes[2] -eq 0xBF) 'UTF-8 BOM was removed.'
    $taskFixtureOutput = [IO.File]::ReadAllText($taskFixture)
    Assert-True (-not [regex]::IsMatch($taskFixtureOutput, '(?<!\r)\n')) 'CRLF changed to LF.'
    Assert-True ([regex]::Matches($taskFixtureOutput, '(?im)^\s*RenderPresetForAll\s*=\s*11\s*$').Count -eq 3) 'Duplicate keys were not all updated.'
    Assert-True ($taskFixtureOutput.Contains('Enabled = false ; keep inline')) 'Unrelated DLSS.Enabled or inline comment changed.'
    Assert-True ($taskFixtureOutput.Contains("[Other]`r`nKeep = 中文`r`n")) 'Unrelated section changed.'
    Assert-True ([DailyRoutines.ModulesPublic.DlssIni]::GetValue([IO.File]::ReadAllLines($taskFixture), 'Upscalers', 'Dx11Upscaler') -ceq 'dlss') 'Missing section was not created.'

    [DailyRoutines.ModulesPublic.DlssIni]::Write($taskFixture, 0, 1.5) | Out-Null
    $taskDefaultLines = [IO.File]::ReadAllLines($taskFixture)
    Assert-True ([DailyRoutines.ModulesPublic.DlssIni]::GetValue($taskDefaultLines, 'DLSS', 'RenderPresetOverride') -ceq 'false') 'Default did not disable preset override.'
    Assert-True ([DailyRoutines.ModulesPublic.DlssIni]::GetValue($taskDefaultLines, 'DLSS', 'RenderPresetForAll') -ceq '0') 'Default retained a forced preset.'
    Assert-True ([DailyRoutines.ModulesPublic.DlssIni]::GetValue($taskDefaultLines, 'UpscaleRatio', 'UpscaleRatioOverrideValue') -ceq '1.500000') 'Default lost the chosen ratio.'
    Assert-True ([IO.File]::ReadAllText($taskFixture).Contains("[Other]`r`nKeep = 中文`r`n")) 'Default changed unrelated content.'

    foreach ($taskArguments in @(@(-1,2), @(1,2), @(6,2), @(7,2), @(10,2), @(14,2), @(15,2), @(16,2), @(11,0.9), @(11,3.1), @(11,[float]::NaN), @(11,[float]::PositiveInfinity))) {
        $taskBefore = [IO.File]::ReadAllBytes($taskFixture)
        $taskCountBefore = @(Get-ChildItem -LiteralPath $taskTestRoot -File).Count
        $taskRejected = $false
        try { [DailyRoutines.ModulesPublic.DlssIni]::Write($taskFixture, $taskArguments[0], $taskArguments[1]) | Out-Null }
        catch { $taskRejected = $true }
        Assert-True $taskRejected 'Invalid preset or ratio was accepted.'
        Assert-Bytes $taskBefore ([IO.File]::ReadAllBytes($taskFixture)) 'Invalid input modified the file.'
        Assert-True (@(Get-ChildItem -LiteralPath $taskTestRoot -File).Count -eq $taskCountBefore) 'Invalid input created a temporary file or backup.'
    }

    $taskInvalid = Join-Path $taskTestRoot 'invalid-utf8.ini'
    [byte[]] $taskBadBytes = @(0x5B,0x58,0x5D,0x0A,0xFF)
    [IO.File]::WriteAllBytes($taskInvalid, $taskBadBytes)
    $taskRejected = $false
    try { [DailyRoutines.ModulesPublic.DlssIni]::Write($taskInvalid,11,2) | Out-Null } catch { $taskRejected = $true }
    Assert-True $taskRejected 'Invalid UTF-8 was accepted.'
    Assert-Bytes $taskBadBytes ([IO.File]::ReadAllBytes($taskInvalid)) 'Invalid UTF-8 file was modified.'

    $taskLf = Join-Path $taskTestRoot 'lf.ini'
    [IO.File]::WriteAllText($taskLf, "[DLSS]`nRenderPresetForAll = 1`n; untouched`n", [Text.UTF8Encoding]::new($false))
    [DailyRoutines.ModulesPublic.DlssIni]::Write($taskLf, 12, 1.7) | Out-Null
    $taskLfBytes = [IO.File]::ReadAllBytes($taskLf)
    Assert-True (-not ([IO.File]::ReadAllText($taskLf).Contains("`r"))) 'LF fixture gained CRLF.'
    Assert-True (-not ($taskLfBytes[0] -eq 0xEF -and $taskLfBytes[1] -eq 0xBB -and $taskLfBytes[2] -eq 0xBF)) 'BOM was added to a BOM-free file.'
    Assert-True (@(Get-ChildItem -LiteralPath $taskTestRoot -Filter '*.drtmp-*').Count -eq 0) 'Temporary files remain.'
    Write-Output ("PASS: {0} checks; all writes were in {1}" -f $taskChecks, $taskTestRoot)
}
finally {
    $taskResolved = [IO.Path]::GetFullPath($taskTestRoot)
    $taskTempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($taskResolved.StartsWith($taskTempBase, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($taskResolved).StartsWith('dr-dlss-ini-test-')) {
        Remove-Item -LiteralPath $taskResolved -Recurse -Force
    }
}
