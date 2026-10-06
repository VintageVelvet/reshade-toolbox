#requires -Version 5.1
<#
.SYNOPSIS
安装或更新 CopyrightAdaptive，并按当前 ReShade 搜索路径生成可用款式。
.EXAMPLE
& .\tools\Install-CopyrightAdaptive.ps1 -GameDirectory 'C:\Games\FFXIV\game' -WhatIf
.EXAMPLE
& .\tools\Install-CopyrightAdaptive.ps1 -GameDirectory 'C:\Games\FFXIV\game' -Preset '.\Portrait.ini'
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string] $GameDirectory = '.',
    [string] $RepositoryDirectory,
    [string] $Preset,
    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryDirectory)) {
    $RepositoryDirectory = Join-Path $PSScriptRoot '..'
}

function Get-FileSystemPath {
    param([string] $Value)
    $provider = $null
    $drive = $null
    $result = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Value, [ref] $provider, [ref] $drive)
    if ($provider.Name -ne 'FileSystem') { throw "需要文件系统路径，收到：$Value" }
    return $result
}

function Get-PathFromBase {
    param([string] $Value, [string] $BaseDirectory)
    if ($Value -match '^[\\/]' -and $Value -notmatch '^[\\/]{2}') {
        return [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetPathRoot($BaseDirectory)) $Value.TrimStart('\', '/')))
    }
    if ([IO.Path]::IsPathRooted($Value)) { return Get-FileSystemPath $Value }
    return [IO.Path]::GetFullPath((Join-Path $BaseDirectory $Value))
}

function Split-ReShadeValues {
    param([AllowEmptyString()][string] $Value)
    if ($Value.Length -eq 0) { return }
    $part = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $Value.Length; $i++) {
        if ($Value[$i] -eq ',') {
            if ($i + 1 -lt $Value.Length -and $Value[$i + 1] -eq ',') {
                [void] $part.Append(',')
                $i++
            }
            else {
                $part.ToString()
                [void] $part.Clear()
            }
        }
        else { [void] $part.Append($Value[$i]) }
    }
    $part.ToString()
}

function Read-ReShadeIni {
    param([string] $Path)
    $sections = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $section = ''
    foreach ($rawLine in [IO.File]::ReadAllLines($Path)) {
        $line = $rawLine.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith(';') -or $line.StartsWith('#')) { continue }
        if ($line -match '^\[(.*)\]$') { $section = $Matches[1].Trim(); continue }
        $equals = $line.IndexOf('=')
        if ($equals -lt 0) { continue }
        $key = $line.Substring(0, $equals).Trim()
        $value = $line.Substring($equals + 1).Trim()
        if (-not $sections.ContainsKey($section)) {
            $sections[$section] = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
        }
        $items = $sections[$section]
        if (-not $items.ContainsKey($key)) { $items[$key] = [Collections.Generic.List[string]]::new() }
        if ($value.Length -eq 0) { continue }
        foreach ($item in @(Split-ReShadeValues $value)) { $items[$key].Add($item) }
    }
    return ,$sections
}

function Test-IniKey {
    param($Ini, [string] $Section, [string] $Key)
    return $Ini.ContainsKey($Section) -and $Ini[$Section].ContainsKey($Key)
}

function Get-SearchValues {
    param($LocalIni, $GlobalIni, [string] $Key)
    if (Test-IniKey $LocalIni 'GENERAL' $Key) { return $LocalIni['GENERAL'][$Key].ToArray() }
    if ($null -ne $GlobalIni -and (Test-IniKey $GlobalIni 'GENERAL' $Key)) { return $GlobalIni['GENERAL'][$Key].ToArray() }
    return '.\'
}

function Resolve-SearchPaths {
    param([string[]] $Values, [string] $BaseDirectory, [string] $Label)
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($value in $Values) {
        $recursive = [IO.Path]::GetFileName($value) -eq '**'
        $rootValue = if ($recursive) { [IO.Path]::GetDirectoryName($value) } else { $value }
        if ([string]::IsNullOrEmpty($rootValue)) { $rootValue = '.' }
        $root = Get-PathFromBase $rootValue $BaseDirectory
        if (-not [IO.Directory]::Exists($root)) {
            Write-Warning "$Label 中的目录不存在，已跳过：$root"
            continue
        }
        $path = if ($recursive) { Join-Path $root '**' } else { $root }
        if ($seen.Add($path)) { [pscustomobject]@{ Root = $root; Recursive = $recursive; Path = $path } }
    }
}

function Get-SearchDirectories {
    param([object[]] $SearchPaths, [switch] $AllDescendants)
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $SearchPaths) {
        if ($seen.Add($entry.Root)) { $entry.Root }
        if ($entry.Recursive -or $AllDescendants) {
            foreach ($directory in @(Get-ChildItem -LiteralPath $entry.Root -Directory -Recurse -ErrorAction Stop | Sort-Object FullName)) {
                if ($seen.Add($directory.FullName)) { $directory.FullName }
            }
        }
    }
}

function Find-SearchFiles {
    param([string[]] $Directories, [string] $Name)
    foreach ($directory in $Directories) {
        $candidate = Join-Path $directory $Name
        if ([IO.File]::Exists($candidate)) { $candidate }
    }
}

function Get-ExistingOverride {
    param([AllowEmptyString()][string] $Value, [string] $DllDirectory)
    $expanded = [Environment]::ExpandEnvironmentVariables($Value)
    try {
        $candidate = if ($expanded.Length -eq 0) { $DllDirectory } else { Get-PathFromBase $expanded $DllDirectory }
        if ([IO.Directory]::Exists($candidate)) { return (Resolve-Path -LiteralPath $candidate).ProviderPath }
    }
    catch { Write-Warning "ReShade 搜索基准覆盖值无法解析，继续使用下一项：$expanded"; return }
    Write-Warning "ReShade 搜索基准覆盖目录不存在，继续使用下一项：$candidate"
}

$gamePath = Get-FileSystemPath $GameDirectory
$repositoryPath = Get-FileSystemPath $RepositoryDirectory
if (-not [IO.Directory]::Exists($gamePath)) { throw "游戏目录不存在：$gamePath" }
$iniPath = Join-Path $gamePath 'ReShade.ini'
if (-not [IO.File]::Exists($iniPath)) { throw "游戏目录中找不到 ReShade.ini：$iniPath。请填写 ReShade DLL 所在的游戏目录。" }
$localIni = Read-ReShadeIni $iniPath
$searchBase = $null
$baseSource = '游戏目录（ReShade DLL 目录）'
if (Test-IniKey $localIni 'INSTALL' 'BasePath') {
    $values = @($localIni['INSTALL']['BasePath'].ToArray())
    $baseValue = if ($values.Count -gt 0) { $values[0] } else { '' }
    $searchBase = Get-ExistingOverride $baseValue $gamePath
    if ($searchBase) { $baseSource = 'ReShade.ini 的 [INSTALL] BasePath' }
}
if (-not $searchBase -and -not [string]::IsNullOrEmpty($env:RESHADE_BASE_PATH_OVERRIDE)) {
    $searchBase = Get-ExistingOverride $env:RESHADE_BASE_PATH_OVERRIDE $gamePath
    if ($searchBase) { $baseSource = 'RESHADE_BASE_PATH_OVERRIDE' }
}
if (-not $searchBase) { $searchBase = $gamePath }
$globalIni = $null
$globalIniPath = Join-Path $searchBase 'ReShade.ini'
if ($globalIniPath -ine $iniPath -and [IO.File]::Exists($globalIniPath)) { $globalIni = Read-ReShadeIni $globalIniPath }

$effectPaths = @(Resolve-SearchPaths @(Get-SearchValues $localIni $globalIni 'EffectSearchPaths') $searchBase 'EffectSearchPaths')
$texturePaths = @(Resolve-SearchPaths @(Get-SearchValues $localIni $globalIni 'TextureSearchPaths') $searchBase 'TextureSearchPaths')
if ($effectPaths.Count -eq 0) { throw '没有可用的着色器搜索目录。请在 ReShade 设置中确认 EffectSearchPaths。' }
if ($texturePaths.Count -eq 0) { throw '没有可用的纹理搜索目录。请在 ReShade 设置中确认 TextureSearchPaths。' }
$effectDirectories = @(Get-SearchDirectories $effectPaths)

$existingModules = @(Find-SearchFiles $effectDirectories 'CopyrightAdaptive.fx')
if ($existingModules.Count -gt 1) {
    throw ("有效着色器目录中有多份 CopyrightAdaptive.fx，请先保留一份再安装：" + [Environment]::NewLine + ($existingModules -join [Environment]::NewLine))
}
$targetShaderDirectory = if ($existingModules.Count -eq 1) { Split-Path $existingModules[0] -Parent } else { $effectPaths[0].Root }
foreach ($dependency in @('ReShade.fxh', 'Blending.fxh')) {
    if (@(Find-SearchFiles $effectDirectories $dependency).Count -eq 0) {
        throw "找不到 $dependency。请确认它位于有效的 EffectSearchPaths 中，再运行安装。"
    }
}

$headerNames = @('CopyrightTex_XIV_AUR.fxh', 'CopyrightTex_XIV.fxh', 'CopyrightTex_Custom.fxh')
$sourceBundles = [Collections.Generic.List[string]]::new()
foreach ($directory in @(Get-SearchDirectories $effectPaths -AllDescendants)) {
    $complete = $true
    foreach ($name in $headerNames) { if (-not [IO.File]::Exists((Join-Path $directory $name))) { $complete = $false; break } }
    if (-not $complete) { continue }
    $aurText = [IO.File]::ReadAllText((Join-Path $directory $headerNames[0]))
    if ($aurText -match '(?m)^\s*#define\s+COPYRIGHTADAPTIVE_TEXTURE_COMBO\b') { continue }
    $sourceBundles.Add($directory)
}
if ($sourceBundles.Count -eq 0) {
    throw '找不到同一目录中的三个原始 CopyrightTex 头文件。请先安装 AuroraShade / ReShade-CN2 的原版权标志文件。'
}
if ($sourceBundles.Count -gt 1) {
    throw ("找到多组原始 CopyrightTex 文件，请保留当前使用的一组再安装：" + [Environment]::NewLine + ($sourceBundles.ToArray() -join [Environment]::NewLine))
}
$sourceDirectory = $sourceBundles[0]
$originalMain = $null
$ancestor = $sourceDirectory
while ($ancestor) {
    $insideSearchRoot = $false
    foreach ($entry in $effectPaths) {
        if ($ancestor -ieq $entry.Root -or $ancestor.StartsWith($entry.Root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { $insideSearchRoot = $true; break }
    }
    if (-not $insideSearchRoot) { break }
    $candidate = Join-Path $ancestor 'Copyright.fx'
    if ([IO.File]::Exists($candidate)) { $originalMain = $candidate; break }
    $ancestor = Split-Path $ancestor -Parent
}

$mainSource = Join-Path $repositoryPath 'Shaders\CopyrightAdaptive.fx'
$licenseSource = Join-Path $repositoryPath 'Shaders\CopyrightAdaptive\LICENSE.txt'
$syncTool = Join-Path $repositoryPath 'tools\Sync-CopyrightAdaptiveStyles.ps1'
$convertTool = Join-Path $repositoryPath 'tools\Convert-CopyrightAdaptivePreset.ps1'
foreach ($file in @($mainSource, $licenseSource, $syncTool)) { if (-not [IO.File]::Exists($file)) { throw "仓库中缺少安装文件：$file。请用 -RepositoryDirectory 指向完整仓库。" } }

$presetSource = $null
$presetDestination = $null
if (-not [string]::IsNullOrWhiteSpace($Preset)) {
    $presetSource = Get-PathFromBase $Preset $gamePath
    if (-not [IO.File]::Exists($presetSource)) { throw "预设文件不存在：$presetSource" }
    $presetDestination = Join-Path (Split-Path $presetSource -Parent) ([IO.Path]::GetFileNameWithoutExtension($presetSource) + '-Adaptive.ini')
    if ([IO.File]::Exists($presetDestination)) { throw "新预设已经存在，未覆盖：$presetDestination。请先改名或移走该文件。" }
    if (-not [IO.File]::Exists($convertTool)) { throw "仓库中缺少迁移工具：$convertTool" }
}

$stagingRoot = Join-Path ([IO.Path]::GetTempPath()) ('CopyrightAdaptive-Install-' + [Guid]::NewGuid().ToString('N'))
$backupDirectory = $null
try {
    $stagingSource = Join-Path $stagingRoot 'original'
    $stagingPrivate = Join-Path $stagingRoot 'private'
    [void] [IO.Directory]::CreateDirectory($stagingSource)
    foreach ($name in $headerNames) { [IO.File]::Copy((Join-Path $sourceDirectory $name), (Join-Path $stagingSource $name), $false) }
    if ($originalMain) { [IO.File]::Copy($originalMain, (Join-Path $stagingSource 'Copyright.fx'), $false) }
    $syncArguments = @{
        SourceShaderDirectory = $stagingSource
        DestinationDirectory = $stagingPrivate
        TextureDirectory = [string[]] @($texturePaths | ForEach-Object { $_.Path })
        ExactSearchPaths = $true
    }
    Write-Verbose "ReShade 搜索基准：$searchBase（$baseSource）"
    Write-Verbose "原版权标志文件：$sourceDirectory"
    & $syncTool @syncArguments | Out-Null
    foreach ($name in $headerNames) { if (-not [IO.File]::Exists((Join-Path $stagingPrivate $name))) { throw "样式同步没有生成 $name，游戏文件尚未改动。" } }
    $manifest = [IO.File]::ReadAllText((Join-Path $stagingPrivate 'styles-manifest.json')) | ConvertFrom-Json
    $menuCounts = @($manifest.headers | ForEach-Object { $_.menu_entry_count })
    Write-Host "安装目录：$targetShaderDirectory"
    Write-Host "可用款式：AuroraShade $($menuCounts[0]) 项，最终幻想 XIV $($menuCounts[1]) 项，Custom $($menuCounts[2]) 项。"
    $stagedPreset = $null
    if ($presetSource) {
        $stagedPreset = Join-Path $stagingRoot 'Preset-Adaptive.ini'
        & $convertTool -SourcePreset $presetSource -DestinationPreset $stagedPreset | Out-Null
        if (-not [IO.File]::Exists($stagedPreset)) { throw '预设迁移没有生成新文件，游戏文件尚未改动。' }
        Write-Host "新预设：$presetDestination"
    }
    $copies = [Collections.Generic.List[object]]::new()
    $copies.Add([pscustomobject]@{ Source = $mainSource; Target = (Join-Path $targetShaderDirectory 'CopyrightAdaptive.fx'); Relative = 'CopyrightAdaptive.fx'; Backup = $null })
    foreach ($name in $headerNames) { $copies.Add([pscustomobject]@{ Source = (Join-Path $stagingPrivate $name); Target = (Join-Path $targetShaderDirectory ('CopyrightAdaptive\' + $name)); Relative = ('CopyrightAdaptive\' + $name); Backup = $null }) }
    $copies.Add([pscustomobject]@{ Source = $licenseSource; Target = (Join-Path $targetShaderDirectory 'CopyrightAdaptive\LICENSE.txt'); Relative = 'CopyrightAdaptive\LICENSE.txt'; Backup = $null })
    if ($stagedPreset) { $copies.Add([pscustomobject]@{ Source = $stagedPreset; Target = $presetDestination; Relative = $null; Backup = $null }) }
    if (-not $PSCmdlet.ShouldProcess($targetShaderDirectory, '安装 CopyrightAdaptive；更新时备份原模块，并创建所选的新预设')) {
        Write-Host '检查完成；游戏文件未写入。'
        if ($PassThru) { [pscustomobject]@{ GameDirectory = $gamePath; SearchBase = $searchBase; ShaderDirectory = $targetShaderDirectory; Preset = $presetDestination; Applied = $false; BackupDirectory = $null } }
        return
    }
    # 再检查一次输出，避免预检查之后覆盖别的程序刚保存的新预设。
    if ($presetDestination -and [IO.File]::Exists($presetDestination)) { throw "新预设已经存在，未覆盖：$presetDestination" }
    $existingCopies = @($copies | Where-Object { $_.Relative -and [IO.File]::Exists($_.Target) })
    if ($existingCopies.Count -gt 0) {
        $backupDirectory = Join-Path $gamePath ('CopyrightAdaptive-backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        foreach ($copy in $existingCopies) {
            # 备份扩展名为 .bak，EffectSearchPaths=\** 时也不会加载备份 FX。
            $copy.Backup = Join-Path $backupDirectory ($copy.Relative + '.bak')
            [void] [IO.Directory]::CreateDirectory((Split-Path $copy.Backup -Parent))
            [IO.File]::Copy($copy.Target, $copy.Backup, $false)
        }
    }
    $attempted = [Collections.Generic.List[object]]::new()
    try {
        foreach ($copy in $copies) {
            [void] [IO.Directory]::CreateDirectory((Split-Path $copy.Target -Parent))
            if ($copy.Relative) {
                $attempted.Add($copy)
                [IO.File]::Copy($copy.Source, $copy.Target, $true)
            }
            else {
                $destinationStream = $null
                $sourceStream = $null
                try {
                    # CreateNew 失败时不要将该路径列入回滚，保留并发创建的预设。
                    $destinationStream = [IO.File]::Open($copy.Target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                    $attempted.Add($copy)
                    $sourceStream = [IO.File]::OpenRead($copy.Source)
                    $sourceStream.CopyTo($destinationStream)
                }
                finally {
                    if ($sourceStream) { $sourceStream.Dispose() }
                    if ($destinationStream) { $destinationStream.Dispose() }
                }
            }
        }
    }
    catch {
        $copyError = $_.Exception.Message
        $rollbackErrors = [Collections.Generic.List[string]]::new()
        foreach ($copy in $attempted) {
            try {
                if ($copy.Backup) { [IO.File]::Copy($copy.Backup, $copy.Target, $true) }
                elseif ([IO.File]::Exists($copy.Target)) { [IO.File]::Delete($copy.Target) }
            }
            catch { $rollbackErrors.Add($copy.Target + ': ' + $_.Exception.Message) }
        }
        if ($rollbackErrors.Count -gt 0) { throw ("安装写入失败：$copyError。以下文件恢复失败，可从备份恢复：" + [Environment]::NewLine + ($rollbackErrors.ToArray() -join [Environment]::NewLine) + [Environment]::NewLine + "备份：$backupDirectory") }
        throw "安装写入失败，已恢复本次尝试的文件：$copyError"
    }
    Write-Host 'CopyrightAdaptive 已安装。请在游戏内重新加载，启用新版并保存预设。'
    if ($backupDirectory) { Write-Host "原模块备份：$backupDirectory" }
    if ($PassThru) { [pscustomobject]@{ GameDirectory = $gamePath; SearchBase = $searchBase; ShaderDirectory = $targetShaderDirectory; Preset = $presetDestination; Applied = $true; BackupDirectory = $backupDirectory } }
}
finally {
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $resolvedStage = [IO.Path]::GetFullPath($stagingRoot)
    if ($resolvedStage.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolvedStage).StartsWith('CopyrightAdaptive-Install-')) {
        if ([IO.Directory]::Exists($resolvedStage)) { Remove-Item -LiteralPath $resolvedStage -Recurse -Force -ErrorAction SilentlyContinue -WhatIf:$false }
    }
}
