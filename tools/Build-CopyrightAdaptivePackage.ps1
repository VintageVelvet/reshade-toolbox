#requires -Version 5.1
<#
.SYNOPSIS
Build the copy-install package from a committed Git revision.
.DESCRIPTION
Run this maintainer tool from any directory. The package contains the main FX,
three relative includes, and their license. Uncommitted files are not packaged.
#>
[CmdletBinding()]
param(
    [string] $Ref = 'HEAD',
    [string] $DestinationPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
    $DestinationPath = Join-Path $repositoryRoot 'dist/CopyrightAdaptive.zip'
}
$destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
if (Test-Path -LiteralPath $destination) {
    throw "Output already exists: $destination"
}

$gitOptions = @('-c', "safe.directory=$repositoryRoot", '-C', $repositoryRoot)
$revision = & git @gitOptions rev-parse --verify --end-of-options "$Ref^{commit}"
if ($LASTEXITCODE -ne 0) { throw "Cannot resolve committed revision: $Ref" }
$revision = ([string] $revision).Trim()
$files = @(
    'Shaders/CopyrightAdaptive.fx',
    'Shaders/CopyrightAdaptive/CopyrightTex_XIV_AUR.fxh',
    'Shaders/CopyrightAdaptive/CopyrightTex_XIV.fxh',
    'Shaders/CopyrightAdaptive/CopyrightTex_Custom.fxh',
    'Shaders/CopyrightAdaptive/LICENSE.txt'
)
$temporaryArchive = Join-Path ([IO.Path]::GetTempPath()) ("copyrightadaptive-$([Guid]::NewGuid().ToString('N')).zip")
$outputCreated = $false
$complete = $false
$inputArchive = $null
$outputArchive = $null
$outputStream = $null
try {
    & git @gitOptions archive --format=zip "--output=$temporaryArchive" $revision -- @files
    if ($LASTEXITCODE -ne 0) { throw 'Failed to archive committed source.' }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $inputArchive = [IO.Compression.ZipFile]::OpenRead($temporaryArchive)
    foreach ($file in $files) {
        if ($null -eq $inputArchive.GetEntry($file)) { throw "Revision does not contain: $file" }
    }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
    $outputStream = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $outputCreated = $true
    $outputArchive = [IO.Compression.ZipArchive]::new($outputStream, [IO.Compression.ZipArchiveMode]::Create, $true)
    foreach ($file in $files) {
        $sourceEntry = $inputArchive.GetEntry($file)
        $entry = $outputArchive.CreateEntry($file.Substring('Shaders/'.Length), [IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = $sourceEntry.LastWriteTime
        $sourceStream = $sourceEntry.Open()
        $entryStream = $entry.Open()
        try { $sourceStream.CopyTo($entryStream) }
        finally { $entryStream.Dispose(); $sourceStream.Dispose() }
    }
    $outputArchive.Dispose()
    $outputArchive = $null
    $outputStream.Dispose()
    $outputStream = $null
    $complete = $true
}
finally {
    if ($null -ne $outputArchive) { $outputArchive.Dispose() }
    if ($null -ne $outputStream) { $outputStream.Dispose() }
    if ($null -ne $inputArchive) { $inputArchive.Dispose() }
    if (Test-Path -LiteralPath $temporaryArchive) { Remove-Item -LiteralPath $temporaryArchive }
    if ($outputCreated -and -not $complete) { Remove-Item -LiteralPath $destination }
}

[pscustomobject]@{
    PackagePath = $destination
    SourceCommit = $revision
    FileCount = $files.Count
    SHA256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
}
