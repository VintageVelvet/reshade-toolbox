$ErrorActionPreference = 'Stop'
# Compile the two pure helpers as separate syntax trees; neither loads a game/plugin dependency.
Add-Type -Path @((Join-Path $PSScriptRoot '..\DlssIni.cs'), (Join-Path $PSScriptRoot '..\DlssConfigSnapshot.cs'))
$taskSnapshotRoot = Join-Path ([IO.Path]::GetTempPath()) ('dr-dlss-snapshot-test-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($taskSnapshotRoot) | Out-Null
$taskChecks = 0
function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
    $script:taskChecks++
}
function Write-Fixture([string] $Path, [string] $Ratio = '2.000000', [string] $RatioEnabled = 'true',
    [string] $Preset = '11', [string] $PresetEnabled = 'true') {
    $taskText = "[Upscalers]`nDx11Upscaler = dlss`n[DLSS]`nRenderPresetOverride = $PresetEnabled`nRenderPresetForAll = $Preset`n[UpscaleRatio]`nUpscaleRatioOverrideEnabled = $RatioEnabled`nUpscaleRatioOverrideValue = $Ratio`n"
    [IO.File]::WriteAllText($Path, $taskText, [Text.UTF8Encoding]::new($false))
}
try {
    $taskPath = Join-Path $taskSnapshotRoot 'external-config.ini'
    Write-Fixture $taskPath
    $taskFirst = [DailyRoutines.ModulesPublic.DlssConfigSnapshot]::Read($taskPath)
    Write-Fixture $taskPath -Preset '0' -PresetEnabled 'false'
    $taskDefault = [DailyRoutines.ModulesPublic.DlssConfigSnapshot]::Read($taskPath)
    Assert-True ($taskDefault.Success -and $taskDefault.Preset -eq 0 -and -not $taskDefault.PresetOverrideEnabled) 'Default snapshot did not preserve disabled preset override.'
    Write-Fixture $taskPath
    Assert-True ($taskFirst.Success -and $taskFirst.Error -ceq '' -and $taskFirst.Preset -eq 11 -and
        $taskFirst.Ratio -eq 2 -and $taskFirst.RatioOverrideEnabled -and $taskFirst.PresetOverrideEnabled -and
        $taskFirst.Upscaler -ceq 'dlss') 'Initial snapshot is incorrect.'

    Write-Fixture $taskPath '1.500000' 'true' '13' 'true'
    $taskSecond = [DailyRoutines.ModulesPublic.DlssConfigSnapshot]::Read($taskPath)
    Assert-True ($taskSecond.Success -and $taskSecond.Preset -eq 13 -and $taskSecond.Ratio -eq 1.5) 'External file changes were not reread.'
    Assert-True ($taskFirst.Preset -eq 11 -and $taskFirst.Ratio -eq 2) 'Reading a new snapshot altered the previous snapshot.'

    foreach ($taskFlag in @('false','auto','unknown','')) {
        Write-Fixture $taskPath '2' $taskFlag '11' $taskFlag
        $taskSnapshot = [DailyRoutines.ModulesPublic.DlssConfigSnapshot]::Read($taskPath)
        Assert-True ($taskSnapshot.Success -and -not $taskSnapshot.RatioOverrideEnabled -and -not $taskSnapshot.PresetOverrideEnabled) ('Invalid flag was treated as enabled: ' + $taskFlag)
        Assert-True ($taskSnapshot.Ratio -eq 2 -and $taskSnapshot.Preset -eq 11) 'Disabled override lost the configured value.'
    }
    Write-Fixture $taskPath '2' 'TRUE' '11' 'TrUe'
    $taskSnapshot = [DailyRoutines.ModulesPublic.DlssConfigSnapshot]::Read($taskPath)
    Assert-True ($taskSnapshot.RatioOverrideEnabled -and $taskSnapshot.PresetOverrideEnabled) 'Case-insensitive true flags failed.'

    foreach ($taskRatio in @('auto','unknown','','garbage','NaN','Infinity','-Infinity','1e999','0','0.9','-2','1,5')) {
        Write-Fixture $taskPath $taskRatio
        $taskSnapshot = [DailyRoutines.ModulesPublic.DlssConfigSnapshot]::Read($taskPath)
        Assert-True ($taskSnapshot.Success -and $null -eq $taskSnapshot.Ratio) ('Invalid ratio was retained: ' + $taskRatio)
    }
    [IO.File]::WriteAllText($taskPath, "[DLSS]`nRenderPresetForAll = auto`n", [Text.UTF8Encoding]::new($false))
    $taskSnapshot = [DailyRoutines.ModulesPublic.DlssConfigSnapshot]::Read($taskPath)
    Assert-True ($taskSnapshot.Success -and $null -eq $taskSnapshot.Preset -and $null -eq $taskSnapshot.Ratio -and
        -not $taskSnapshot.RatioOverrideEnabled -and -not $taskSnapshot.PresetOverrideEnabled -and $taskSnapshot.Upscaler -ceq '') 'Missing keys or auto preset reused old values.'

    $taskOriginalCulture = [Globalization.CultureInfo]::CurrentCulture
    try {
        foreach ($taskCulture in @('fr-FR','zh-CN')) {
            [Globalization.CultureInfo]::CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($taskCulture)
            Write-Fixture $taskPath '1.700000'
            Assert-True ([DailyRoutines.ModulesPublic.DlssConfigSnapshot]::Read($taskPath).Ratio -eq 1.7) ('Invariant parsing failed under ' + $taskCulture)
        }
    } finally { [Globalization.CultureInfo]::CurrentCulture = $taskOriginalCulture }

    [IO.File]::Delete($taskPath)
    $taskSnapshot = [DailyRoutines.ModulesPublic.DlssConfigSnapshot]::Read($taskPath)
    Assert-True (-not $taskSnapshot.Success -and $taskSnapshot.Error.Length -gt 0 -and $null -eq $taskSnapshot.Ratio -and
        $null -eq $taskSnapshot.Preset -and -not $taskSnapshot.RatioOverrideEnabled -and
        -not $taskSnapshot.PresetOverrideEnabled -and $taskSnapshot.Upscaler -ceq '') 'A failed read retained old values.'

    foreach ($taskCase in @(@(3840,2160,2.0,1920,1080), @(2560,1440,1.0,2560,1440),
        @(2560,1440,1.7,1506,847), @(3,3,2.0,2,2), @(1,1,3.0,1,1))) {
        $taskEstimate = [DailyRoutines.ModulesPublic.DlssConfigSnapshot]::EstimateInput($taskCase[0],$taskCase[1],$taskCase[2],$true)
        Assert-True ($taskEstimate.Item1 -eq $taskCase[3] -and $taskEstimate.Item2 -eq $taskCase[4]) 'Estimated dimensions or rounding are incorrect.'
    }
    foreach ($taskRatio in @($null,0.9,[double]::NaN,[double]::PositiveInfinity,[double]::NegativeInfinity)) {
        Assert-True ($null -eq [DailyRoutines.ModulesPublic.DlssConfigSnapshot]::EstimateInput(2560,1440,$taskRatio,$true)) 'Estimate accepted an invalid ratio.'
    }
    Assert-True ($null -eq [DailyRoutines.ModulesPublic.DlssConfigSnapshot]::EstimateInput(2560,1440,2,$false)) 'Disabled override produced an estimate.'
    Assert-True ($null -eq [DailyRoutines.ModulesPublic.DlssConfigSnapshot]::EstimateInput(0,1440,2,$true)) 'Invalid width produced an estimate.'
    Assert-True ($null -eq [DailyRoutines.ModulesPublic.DlssConfigSnapshot]::EstimateInput(2560,-1,2,$true)) 'Invalid height produced an estimate.'
    Write-Output ("PASS: {0} checks; isolated temporary fixtures only." -f $taskChecks)
}
finally {
    $taskResolved = [IO.Path]::GetFullPath($taskSnapshotRoot)
    $taskTempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($taskResolved.StartsWith($taskTempBase, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($taskResolved).StartsWith('dr-dlss-snapshot-test-')) {
        Remove-Item -LiteralPath $taskResolved -Recurse -Force
    }
}
