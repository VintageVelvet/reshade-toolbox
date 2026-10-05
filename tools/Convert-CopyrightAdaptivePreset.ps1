#requires -Version 5.1
<#
.SYNOPSIS
Creates a separate CopyrightAdaptive preset from an existing ReShade preset.
.DESCRIPTION
The source preset is read only. The destination must be a different, new file.
The original Copyright section and definitions are retained. Existing adaptive
definitions take precedence within each PreprocessorDefinitions field.
.EXAMPLE
.\Convert-CopyrightAdaptivePreset.ps1 -SourcePreset .\Portrait.ini -DestinationPreset .\Portrait-Adaptive.ini
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $SourcePreset,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $DestinationPreset
)

$ErrorActionPreference = 'Stop'

function Split-IniList {
    param([AllowEmptyString()][string] $Value)

    $parts = New-Object 'System.Collections.Generic.List[string]'
    $start = 0
    $inQuotes = $false
    $escaped = $false
    for ($i = 0; $i -lt $Value.Length; $i++) {
        $character = $Value[$i]
        if ($character -eq '\') {
            # Backslashes only affect C/C++ quoted-string boundaries. They do
            # not escape ReShade's list separators; doubled commas do that.
            $escaped = -not $escaped
            continue
        }
        if ($character -eq '"') {
            if (-not $escaped) { $inQuotes = -not $inQuotes }
            $escaped = $false
            continue
        }
        $escaped = $false
        if ($character -eq ',' -and $i + 1 -lt $Value.Length -and $Value[$i + 1] -eq ',') {
            # ReShade encodes a literal comma as two commas. Keep both encoded
            # characters intact while skipping them as a list delimiter.
            $i++
            continue
        }
        if ($character -eq ',' -and -not $inQuotes) {
            $parts.Add($Value.Substring($start, $i - $start))
            $start = $i + 1
        }
    }
    if ($inQuotes) {
        throw 'A comma-separated preset value has an unclosed quoted string.'
    }
    $parts.Add($Value.Substring($start))
    return $parts.ToArray()
}

function Add-AdaptiveDefinitions {
    param(
        [AllowEmptyString()][string] $Value,
        [string[]] $SkipSourceNames = @()
    )

    $mapping = [ordered]@{
        'cLayer_TEXTURE_SELECTION' = 'CopyrightAdaptive_TEXTURE_SELECTION'
        'Copyright_Texture_Source' = 'CopyrightAdaptive_Texture_Source'
        'cLayerTex' = 'CopyrightAdaptiveTex'
        'cLayer_SIZE_X' = 'CopyrightAdaptive_SIZE_X'
        'cLayer_SIZE_Y' = 'CopyrightAdaptive_SIZE_Y'
        'cLayer_SINGLECHANNEL' = 'CopyrightAdaptive_SINGLECHANNEL'
    }
    $existing = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $originals = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::Ordinal)
    foreach ($part in @(Split-IniList -Value $Value)) {
        $match = [regex]::Match($part.Trim(), '^([A-Za-z_][A-Za-z0-9_]*)(?:\s*=(.*))?$')
        if ($match.Success) {
            $name = $match.Groups[1].Value
            [void] $existing.Add($name)
            $originals[$name] = $part.Trim()
        }
    }

    $additions = New-Object 'System.Collections.Generic.List[string]'
    foreach ($oldName in $mapping.Keys) {
        $newName = $mapping[$oldName]
        if (-not $originals.ContainsKey($oldName) -or $existing.Contains($newName)) {
            continue
        }
        if ($SkipSourceNames -ccontains $oldName) { continue }
        $original = $originals[$oldName]
        $assignment = [regex]::Match($original, '^[A-Za-z_][A-Za-z0-9_]*(\s*=.*)?$')
        $suffix = $assignment.Groups[1].Value
        if ($oldName -ceq 'cLayer_SIZE_X' -or $oldName -ceq 'cLayer_SIZE_Y') {
            if ($suffix -cmatch '^\s*=\s*BUFFER_(WIDTH|HEIGHT)\s*$') {
                # Omission retains the shader's per-axis buffer-size marker.
                continue
            }
        }
        $additions.Add($newName + $suffix)
    }
    if ($additions.Count -eq 0) {
        return $Value
    }
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ($additions.ToArray() -join ',')
    }
    return $Value + ',' + ($additions.ToArray() -join ',')
}

function Convert-Techniques {
    param([AllowEmptyString()][string] $Value)

    $oldTechnique = 'Copyright@Copyright.fx'
    $newTechnique = 'CopyrightAdaptive@CopyrightAdaptive.fx'
    $result = New-Object 'System.Collections.Generic.List[string]'
    $newSeen = $false
    foreach ($part in @(Split-IniList -Value $Value)) {
        $name = $part.Trim()
        if ($name -ceq $oldTechnique -or $name -ceq $newTechnique) {
            if ($newSeen) { continue }
            $leading = [regex]::Match($part, '^\s*').Value
            $trailing = [regex]::Match($part, '\s*$').Value
            $result.Add($leading + $newTechnique + $trailing)
            $newSeen = $true
        }
        else {
            $result.Add($part)
        }
    }
    return ($result.ToArray() -join ',')
}

function Add-AdaptiveSorting {
    param([AllowEmptyString()][string] $Value)

    $parts = @(Split-IniList -Value $Value)
    foreach ($part in $parts) {
        if ($part.Trim() -ceq 'CopyrightAdaptive@CopyrightAdaptive.fx') {
            return $Value
        }
    }
    $result = New-Object 'System.Collections.Generic.List[string]'
    $inserted = $false
    foreach ($part in $parts) {
        $result.Add($part)
        if (-not $inserted -and $part.Trim() -ceq 'Copyright@Copyright.fx') {
            $result.Add('CopyrightAdaptive@CopyrightAdaptive.fx')
            $inserted = $true
        }
    }
    return ($result.ToArray() -join ',')
}

$sourcePath = [System.IO.Path]::GetFullPath($SourcePreset)
$destinationPath = [System.IO.Path]::GetFullPath($DestinationPreset)
if ([string]::Equals($sourcePath, $destinationPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourcePreset and DestinationPreset must be different paths. The source is never overwritten.'
}
if (-not [System.IO.File]::Exists($sourcePath)) {
    throw "Source preset does not exist: $sourcePath"
}
if (Test-Path -LiteralPath $destinationPath) {
    throw "Destination already exists. Choose a new path: $destinationPath"
}
if (-not [System.IO.Directory]::Exists([System.IO.Path]::GetDirectoryName($destinationPath))) {
    throw 'The destination directory must already exist.'
}

# Detect Unicode BOMs and otherwise require valid UTF-8, so names are not silently
# replaced while reading a preset. Destination files are UTF-8 without a BOM.
$sourceBytes = [System.IO.File]::ReadAllBytes($sourcePath)
$offset = 0
$sourceEncoding = New-Object System.Text.UTF8Encoding($false, $true)
if ($sourceBytes.Length -ge 3 -and $sourceBytes[0] -eq 0xEF -and $sourceBytes[1] -eq 0xBB -and $sourceBytes[2] -eq 0xBF) {
    $offset = 3
}
elseif ($sourceBytes.Length -ge 2 -and $sourceBytes[0] -eq 0xFF -and $sourceBytes[1] -eq 0xFE) {
    $sourceEncoding = New-Object System.Text.UnicodeEncoding($false, $false, $true)
    $offset = 2
}
elseif ($sourceBytes.Length -ge 2 -and $sourceBytes[0] -eq 0xFE -and $sourceBytes[1] -eq 0xFF) {
    $sourceEncoding = New-Object System.Text.UnicodeEncoding($true, $false, $true)
    $offset = 2
}
try {
    $sourceText = $sourceEncoding.GetString($sourceBytes, $offset, $sourceBytes.Length - $offset)
}
catch {
    throw 'The source preset is not valid UTF-8 or BOM-marked UTF-16. Convert its encoding before migrating.'
}
$newlineMatch = [regex]::Match($sourceText, '\r\n|\n|\r')
$newline = if ($newlineMatch.Success) { $newlineMatch.Value } else { "`r`n" }
$sourceLines = [regex]::Split($sourceText, '\r\n|\n|\r')
# If an effect-local size explicitly uses a buffer dimension, do not manufacture
# a conflicting adaptive fixed size from its root fallback. Omission must leave
# the adaptive shader's default buffer marker effective. Existing adaptive root
# definitions remain untouched.
$effectBufferSizeOverrides = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
$scanSection = ''
foreach ($line in $sourceLines) {
    $sectionMatch = [regex]::Match($line, '^\s*\[([^\]]+)\]\s*$')
    if ($sectionMatch.Success) {
        $scanSection = $sectionMatch.Groups[1].Value
        continue
    }
    if ($scanSection -ine 'Copyright.fx') { continue }
    $definitionMatch = [regex]::Match($line, '^\s*PreprocessorDefinitions\s*=(.*)$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $definitionMatch.Success) { continue }
    foreach ($part in @(Split-IniList -Value $definitionMatch.Groups[1].Value)) {
        $sizeMatch = [regex]::Match($part.Trim(), '^(cLayer_SIZE_[XY])\s*=(.*)$')
        if (-not $sizeMatch.Success) { continue }
        $name = $sizeMatch.Groups[1].Value
        if ($sizeMatch.Groups[2].Value -cmatch '^\s*BUFFER_(WIDTH|HEIGHT)\s*$') {
            [void] $effectBufferSizeOverrides.Add($name)
        }
        else {
            [void] $effectBufferSizeOverrides.Remove($name)
        }
    }
}
$outputLines = New-Object 'System.Collections.Generic.List[string]'
$copyrightLines = New-Object 'System.Collections.Generic.List[string]'
$currentSection = ''
$copyrightSectionCount = 0
$oldTechniqueEnabled = $false

foreach ($line in $sourceLines) {
    $sectionMatch = [regex]::Match($line, '^\s*\[([^\]]+)\]\s*$')
    if ($sectionMatch.Success) {
        $currentSection = $sectionMatch.Groups[1].Value
        if ($currentSection -ieq 'CopyrightAdaptive.fx') {
            throw 'The source already has a [CopyrightAdaptive.fx] section. No output was written.'
        }
        if ($currentSection -ieq 'Copyright.fx') {
            $copyrightSectionCount++
            if ($copyrightSectionCount -gt 1) {
                throw 'The source has multiple [Copyright.fx] sections. No output was written.'
            }
        }
        $outputLines.Add($line)
        continue
    }

    if ($currentSection -ieq 'Copyright.fx') {
        $copyrightLines.Add($line)
    }
    $keyMatch = [regex]::Match($line, '^(\s*([^;#=\s][^=]*?)\s*=)(.*)$')
    if ($currentSection -eq '' -and $keyMatch.Success) {
        $prefix = $keyMatch.Groups[1].Value
        $key = $keyMatch.Groups[2].Value.Trim()
        $value = $keyMatch.Groups[3].Value
        switch ($key) {
            'PreprocessorDefinitions' { $line = $prefix + (Add-AdaptiveDefinitions -Value $value -SkipSourceNames @($effectBufferSizeOverrides)) }
            'Techniques' {
                foreach ($part in @(Split-IniList -Value $value)) {
                    if ($part.Trim() -ceq 'Copyright@Copyright.fx') { $oldTechniqueEnabled = $true }
                }
                $line = $prefix + (Convert-Techniques -Value $value)
            }
            'TechniqueSorting' { $line = $prefix + (Add-AdaptiveSorting -Value $value) }
        }
    }
    $outputLines.Add($line)
}
if ($copyrightSectionCount -eq 0 -and -not $oldTechniqueEnabled) {
    throw 'No [Copyright.fx] section or enabled Copyright@Copyright.fx technique was found. No output was written.'
}

if ($outputLines.Count -gt 0 -and $outputLines[$outputLines.Count - 1] -ne '') {
    $outputLines.Add('')
}
$outputLines.Add('[CopyrightAdaptive.fx]')
foreach ($line in $copyrightLines) {
    $keyMatch = [regex]::Match($line, '^(\s*([^;#=\s][^=]*?)\s*=)(.*)$')
    if (-not $keyMatch.Success) { continue }
    $key = $keyMatch.Groups[2].Value.Trim()
    # The old selector stores a legacy ID. The new menu stores a compact index
    # and derives its initial value from the retained texture definition.
    if ($key -ieq 'cLayer_Select' -or $key -ieq 'cLayer_ResolutionAdaptive' -or $key -ieq 'cLayer_ReferenceHeight') {
        continue
    }
    if ($key -ieq 'PreprocessorDefinitions') {
        $line = $keyMatch.Groups[1].Value + (Add-AdaptiveDefinitions -Value $keyMatch.Groups[3].Value)
    }
    $outputLines.Add($line)
}
$outputLines.Add('cLayer_ResolutionAdaptive=1')
$outputLines.Add('cLayer_ReferenceHeight=1440')
$outputLines.Add('')
$outputText = $outputLines.ToArray() -join $newline
$outputEncoding = New-Object System.Text.UTF8Encoding($false)
$outputBytes = $outputEncoding.GetBytes($outputText)

# CreateNew also prevents a race from replacing a destination created after the
# checks above. All parsing and migration checks finish before any file is opened.
$stream = [System.IO.File]::Open($destinationPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
try {
    $stream.Write($outputBytes, 0, $outputBytes.Length)
}
finally {
    $stream.Dispose()
}

[pscustomobject]@{
    SourcePreset = $sourcePath
    DestinationPreset = $destinationPath
    CopyrightSectionCopied = ($copyrightSectionCount -eq 1)
    ActiveCopyrightReplaced = $oldTechniqueEnabled
    AdaptiveTechnique = 'CopyrightAdaptive@CopyrightAdaptive.fx'
    ReferenceHeight = 1440
}
