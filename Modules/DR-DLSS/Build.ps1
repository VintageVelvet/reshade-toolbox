[CmdletBinding()]
param(
    [string]$LauncherRoot = (Join-Path $env:APPDATA 'XIVLauncherCN'),
    [string]$PluginDirectory,
    [string]$HookDirectory,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'out')
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Use PowerShell 7 with .NET 10 to run this build.' }
if ([Environment]::Version.Major -lt 10) { throw 'This module targets .NET 10. Run this script in PowerShell backed by .NET 10.' }

if (-not $PluginDirectory) {
    $PluginDirectory = Get-ChildItem -LiteralPath (Join-Path $LauncherRoot 'installedPlugins\DailyRoutines') -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $HookDirectory) {
    $HookDirectory = Get-ChildItem -LiteralPath (Join-Path $LauncherRoot 'addon\Hooks') -Directory |
        Where-Object { $_.Name -match '^\d{2}-\d{2}-\d{2}-\d{2}$' } |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}
$runtimeDirectory = Get-ChildItem -LiteralPath (Join-Path $LauncherRoot 'runtime\shared\Microsoft.NETCore.App') -Directory |
    Where-Object { $_.Name -match '^10\.' } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $PluginDirectory -or -not $HookDirectory -or -not $runtimeDirectory) {
    throw 'Could not locate the DR, Dalamud, or .NET 10 dependency directories. Supply explicit plugin/hook directories.'
}
foreach ($required in @((Join-Path $PluginDirectory 'DailyRoutines.Common.dll'), (Join-Path $PluginDirectory 'OmenTools.dll'), (Join-Path $HookDirectory 'Dalamud.dll'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing dependency: $required" }
}

# PowerShell ships Roslyn. Compilation reads dependency metadata and never loads the target plugin.
foreach ($compilerName in @('Microsoft.CodeAnalysis.dll', 'Microsoft.CodeAnalysis.CSharp.dll')) {
    $compilerPath = Join-Path $PSHOME $compilerName
    if (-not (Test-Path -LiteralPath $compilerPath)) { throw "PowerShell's bundled compiler was not found: $compilerName" }
    [System.Reflection.Assembly]::LoadFrom($compilerPath) | Out-Null
}
$dependencyPaths = @{}
foreach ($directory in @($runtimeDirectory, $HookDirectory, $PluginDirectory)) {
    foreach ($file in Get-ChildItem -LiteralPath $directory -Filter '*.dll') {
        if ($file.Name -match '^DailyRoutines\.Modules') { continue }
        try {
            [System.Reflection.AssemblyName]::GetAssemblyName($file.FullName) | Out-Null
            $dependencyPaths[$file.Name] = $file.FullName
        } catch [System.BadImageFormatException] { }
    }
}
$references = [System.Collections.Generic.List[Microsoft.CodeAnalysis.MetadataReference]]::new()
foreach ($dependencyPath in $dependencyPaths.Values) {
    $references.Add([Microsoft.CodeAnalysis.MetadataReference]::CreateFromFile($dependencyPath))
}
$parseOptions = [Microsoft.CodeAnalysis.CSharp.CSharpParseOptions]::Default.WithLanguageVersion([Microsoft.CodeAnalysis.CSharp.LanguageVersion]::Preview)
$trees = [System.Collections.Generic.List[Microsoft.CodeAnalysis.SyntaxTree]]::new()
foreach ($source in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.cs' | Sort-Object Name) {
    $sourceText = [System.IO.File]::ReadAllText($source.FullName)
    $trees.Add([Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText($sourceText, $parseOptions, $source.FullName))
}
$options = [Microsoft.CodeAnalysis.CSharp.CSharpCompilationOptions]::new([Microsoft.CodeAnalysis.OutputKind]::DynamicallyLinkedLibrary).
    WithOptimizationLevel([Microsoft.CodeAnalysis.OptimizationLevel]::Release).
    WithAllowUnsafe($true).
    WithNullableContextOptions([Microsoft.CodeAnalysis.NullableContextOptions]::Enable).
    WithDeterministic($true)
$assemblyName = 'DR.DlssModule'
$compilation = [Microsoft.CodeAnalysis.CSharp.CSharpCompilation]::Create($assemblyName, $trees, $references, $options)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$destination = Join-Path $OutputDirectory "$assemblyName.dll"
$temporary = "$destination.build-$([Guid]::NewGuid().ToString('N'))"
$stream = [System.IO.File]::Create($temporary)
try { $result = $compilation.Emit($stream) } finally { $stream.Dispose() }
$result.Diagnostics | Where-Object { $_.Severity -in @('Error', 'Warning') } | ForEach-Object { Write-Host $_.ToString() }
if (-not $result.Success) {
    Remove-Item -LiteralPath $temporary
    throw 'Compilation failed. The existing output, if any, was preserved.'
}
Move-Item -LiteralPath $temporary -Destination $destination -Force
$dependencySummary = foreach ($file in @((Join-Path $PluginDirectory 'DailyRoutines.dll'), (Join-Path $PluginDirectory 'DailyRoutines.Common.dll'), (Join-Path $PluginDirectory 'OmenTools.dll'), (Join-Path $HookDirectory 'Dalamud.dll'), (Join-Path $HookDirectory 'FFXIVClientStructs.dll'))) {
    [ordered]@{ File = Split-Path $file -Leaf; Assembly = [System.Reflection.AssemblyName]::GetAssemblyName($file).FullName; SHA256 = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash }
}
[ordered]@{
    Assembly = [System.Reflection.AssemblyName]::GetAssemblyName($destination).FullName
    SHA256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    Dependencies = @($dependencySummary)
    Sources = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.cs' | Sort-Object Name | ForEach-Object { [ordered]@{ File = $_.Name; SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } })
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'build-info.json') -Encoding utf8
Write-Host "Built $destination"
