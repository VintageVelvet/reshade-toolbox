#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $SourceShaderDirectory,

    [string] $DestinationDirectory,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]] $TextureDirectory,

    # Match ReShade's configured roots: only a trailing /** enables recursion.
    [switch] $ExactSearchPaths
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($DestinationDirectory)) {
    $DestinationDirectory = Join-Path $PSScriptRoot '..\Shaders\CopyrightAdaptive'
}

# Only private metadata and its manifest are written. Original shaders and all
# PNG assets remain untouched. TextureDirectory is required on every sync.
$headerNames = @('CopyrightTex_XIV_AUR.fxh', 'CopyrightTex_XIV.fxh', 'CopyrightTex_Custom.fxh')
$tokenReplacements = [ordered]@{
    'Copyright_Texture_Source' = 'CopyrightAdaptive_Texture_Source'
    'cLayer_Texture_Source' = 'CopyrightAdaptive_Texture_Source'
    '_Copyright_TextureNGS_Source' = 'CopyrightAdaptive_Texture_Source'
    'TEXTURE_COMBO' = 'COPYRIGHTADAPTIVE_TEXTURE_COMBO'
    '_SOURCE_COPYRIGHT_FILE' = 'COPYRIGHTADAPTIVE_SOURCE_FILE'
    '_SOURCE_COPYRIGHT_SIZE' = 'COPYRIGHTADAPTIVE_SOURCE_SIZE'
    'cLayerTex' = 'CopyrightAdaptiveTex'
    'cLayer_SIZE_X' = 'CopyrightAdaptive_SIZE_X'
    'cLayer_SIZE_Y' = 'CopyrightAdaptive_SIZE_Y'
}
$sourceDirectoryPath = (Resolve-Path -LiteralPath $SourceShaderDirectory).ProviderPath
if (-not (Test-Path -LiteralPath $sourceDirectoryPath -PathType Container)) {
    throw "An input directory does not exist: $sourceDirectoryPath"
}
$textureRoots = @(
    foreach ($textureInput in $TextureDirectory) {
        $recursive = -not $ExactSearchPaths -or $textureInput -match '[/\\]\*\*$'
        $rootInput = $textureInput -replace '[/\\]\*\*$', ''
        $rootPath = (Resolve-Path -LiteralPath $rootInput).ProviderPath
        if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
            throw "A texture directory does not exist: $rootPath"
        }
        [pscustomobject]@{
            path = $rootPath
            recursive = [bool] $recursive
            files = @(Get-ChildItem -LiteralPath $rootPath -File -Recurse:$recursive)
        }
    }
)
$textureDirectoryPath = $textureRoots[0].path
$destinationDirectoryPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationDirectory)
if ($destinationDirectoryPath.TrimEnd('\', '/') -ieq $sourceDirectoryPath.TrimEnd('\', '/')) {
    throw 'DestinationDirectory must be a private directory distinct from SourceShaderDirectory.'
}

function Find-TexturePaths {
    param([string] $Filename)
    if ([System.IO.Path]::IsPathRooted($Filename)) {
        if (Test-Path -LiteralPath $Filename -PathType Leaf) { (Resolve-Path -LiteralPath $Filename).ProviderPath }
        return
    }
    $relativePath = $Filename.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    foreach ($textureRoot in $textureRoots) {
        $rootCandidate = Join-Path $textureRoot.path $relativePath
        if (Test-Path -LiteralPath $rootCandidate -PathType Leaf) { (Resolve-Path -LiteralPath $rootCandidate).ProviderPath }
        if ($textureRoot.recursive) {
            foreach ($textureFile in $textureRoot.files) {
                $candidate = $textureFile.FullName
                if ($candidate -ine $rootCandidate -and
                    ($candidate.EndsWith('\' + $relativePath, [System.StringComparison]::OrdinalIgnoreCase) -or
                     $candidate.EndsWith('/' + $relativePath, [System.StringComparison]::OrdinalIgnoreCase))) {
                    $candidate
                }
            }
        }
    }
}

function Convert-PrivateExpression {
    param([string] $Expression)
    foreach ($entry in $tokenReplacements.GetEnumerator()) {
        $Expression = [regex]::Replace($Expression, '\b' + [regex]::Escape($entry.Key) + '\b', $entry.Value)
    }
    return $Expression
}

function Get-HeaderMetadata {
    param([string] $SourceText)
    $itemsMatch = [regex]::Match($SourceText, 'ui_items\s*=\s*(?<items>.*?)\s*;\s*\\?\s*ui_bind', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $itemsMatch.Success) { throw 'A source header has no supported texture dropdown.' }
    $menuItems = @([regex]::Matches($itemsMatch.Groups['items'].Value, '"(?<label>[^"\r\n]*)\\0"') |
        ForEach-Object { $_.Groups['label'].Value })
    $mappings = [System.Collections.Generic.List[object]]::new()
    $condition = $null
    $conditionVariable = $null
    $sourceIndex = $null
    $isFallback = $false
    $fileExpression = $null
    $fileLine = $null
    $lines = $SourceText -split '\r?\n'
    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        $line = $lines[$lineIndex]
        if ($line -match '^\s*#(?<kind>if|elif|else)\b(?<condition>[^\r\n]*)') {
            $isFallback = $Matches['kind'] -eq 'else'
            $condition = $Matches['condition'].Trim()
            $conditionVariable = $null
            $sourceIndex = $null
            if ($condition -match '^(?<variable>\w+)\s*==\s*(?<index>\d+)\b') {
                $conditionVariable = $Matches['variable']
                $sourceIndex = [int] $Matches['index']
            }
            $fileExpression = $null
            $fileLine = $null
        }
        if ($line -match '^\s*#define\s+_SOURCE_COPYRIGHT_FILE\s+(?<expression>"[^"]+"|\w+)') {
            $fileExpression = $Matches['expression']
            $fileLine = $lineIndex + 1
        }
        if ($fileExpression -and $line -match '^\s*#define\s+_SOURCE_COPYRIGHT_SIZE\s+(?<size>[^/\r\n]+)') {
            $filename = $null
            $resolvedPaths = @()
            $textureExists = $null
            if ($fileExpression.StartsWith('"')) {
                $filename = $fileExpression.Trim('"')
                $resolvedPaths = @(Find-TexturePaths -Filename $filename | Sort-Object -Unique)
                $textureExists = $resolvedPaths.Count -gt 0
            }
            $mappings.Add([ordered]@{
                source_index = $sourceIndex
                condition_variable = $conditionVariable
                normalized_condition_variable = $(if ($conditionVariable) { Convert-PrivateExpression $conditionVariable } else { $null })
                condition = $condition
                is_fallback = $isFallback
                original_file_line = $fileLine
                file_expression = $fileExpression
                filename = $filename
                display_size_expression = $Matches['size'].Trim()
                texture_exists = $textureExists
                resolved_texture_paths = $resolvedPaths
            })
            $fileExpression = $null
        }
    }
    $authorPrefixMatch = [regex]::Match($SourceText, '(?m)^\s*#(?:undef|define)\s+TEXTURE_COMBO\b')
    $authorPrefix = if ($authorPrefixMatch.Success) { $SourceText.Substring(0, $authorPrefixMatch.Index).TrimEnd() } else { '' }
    return [ordered]@{ menu_items = $menuItems; mappings = @($mappings.ToArray()); author_prefix = $authorPrefix }
}

$defaultCustomTexture = [ordered]@{
    macro = 'CopyrightAdaptiveTex'
    original_macro = 'cLayerTex'
    declaration_source = $null
    filename = $null
    default_size_x_expression = $null
    default_size_y_expression = $null
    texture_exists = $false
    resolved_texture_paths = @()
    note = 'The default asset controls menu availability. An explicit custom asset can still be selected manually through source ID 47 without a menu override.'
}
$copyrightSourcePath = Join-Path $sourceDirectoryPath 'Copyright.fx'
if (Test-Path -LiteralPath $copyrightSourcePath -PathType Leaf) {
    $copyrightSource = [System.IO.File]::ReadAllText($copyrightSourcePath)
    $defaultCustomTexture.declaration_source = $copyrightSourcePath
    if ($copyrightSource -match '(?m)^\s*#define\s+cLayerTex\s+"(?<filename>[^"]+)"') {
        $defaultCustomTexture.filename = $Matches['filename']
        $defaultCustomTexture.resolved_texture_paths = @(Find-TexturePaths -Filename $defaultCustomTexture.filename | Sort-Object -Unique)
        $defaultCustomTexture.texture_exists = $defaultCustomTexture.resolved_texture_paths.Count -gt 0
    }
    foreach ($axis in @('X', 'Y')) {
        if ($copyrightSource -match ('(?m)^\s*#define\s+cLayer_SIZE_' + $axis + '\s+(?<size>[^/\r\n]+)')) {
            $defaultCustomTexture['default_size_' + $axis.ToLowerInvariant() + '_expression'] = $Matches['size'].Trim()
        }
    }
}

function New-PrivateHeader {
    param(
        [string] $HeaderName,
        [string] $SourceHash,
        [System.Collections.IDictionary] $Metadata,
        [object[]] $KeptEntries,
        [object] $ManualCustomMapping,
        [int] $FallbackSourceIndex
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("// Private CopyrightAdaptive metadata copy of $HeaderName.")
    $lines.Add("// Source SHA-256: $SourceHash")
    $lines.Add('// Generated by tools/Sync-CopyrightAdaptiveStyles.ps1 with required asset filtering.')
    $lines.Add('// Legacy style IDs are retained; the compact menu uses its own preprocessor input.')
    $lines.Add('')
    if ($Metadata.author_prefix) { $lines.Add($Metadata.author_prefix); $lines.Add('') }
    $lines.Add('#ifndef CopyrightAdaptive_Texture_Source')
    $lines.Add('#define CopyrightAdaptive_Texture_Source 0')
    $lines.Add('#endif')
    $lines.Add('#undef COPYRIGHTADAPTIVE_EFFECTIVE_SOURCE')
    $lines.Add('#undef COPYRIGHTADAPTIVE_UI_INDEX')
    $lines.Add('')
    $lines.Add('// A menu choice takes precedence. Invalid menu positions use the first available style.')
    $lines.Add('#if defined(CopyrightAdaptive_Menu_Source)')
    foreach ($entry in $KeptEntries) {
        $directive = if ($entry.menu_index -eq 0) { '#if' } else { '#elif' }
        $lines.Add("$directive CopyrightAdaptive_Menu_Source == $($entry.menu_index)")
        $lines.Add("#define COPYRIGHTADAPTIVE_EFFECTIVE_SOURCE $($entry.source_index)")
    }
    $lines.Add('#else')
    $lines.Add("#define COPYRIGHTADAPTIVE_EFFECTIVE_SOURCE $FallbackSourceIndex")
    $lines.Add('#endif')
    $lines.Add('#else')
    $lines.Add('// Without a menu override, the original Texture_Source style ID remains valid.')
    $first = $true
    foreach ($entry in $KeptEntries) {
        $directive = if ($first) { '#if' } else { '#elif' }
        $first = $false
        $lines.Add("$directive CopyrightAdaptive_Texture_Source == $($entry.source_index)")
        $lines.Add("#define COPYRIGHTADAPTIVE_EFFECTIVE_SOURCE $($entry.source_index)")
    }
    if ($ManualCustomMapping) {
        $lines.Add('#elif CopyrightAdaptive_Texture_Source == 47 && defined(COPYRIGHTADAPTIVE_CUSTOM_TEXTURE_PROVIDED) && COPYRIGHTADAPTIVE_CUSTOM_TEXTURE_PROVIDED')
        $lines.Add('#define COPYRIGHTADAPTIVE_EFFECTIVE_SOURCE 47')
    }
    $lines.Add('#else')
    $lines.Add("#define COPYRIGHTADAPTIVE_EFFECTIVE_SOURCE $FallbackSourceIndex")
    $lines.Add('#endif')
    $lines.Add('#endif')
    $lines.Add('')
    foreach ($entry in $KeptEntries) {
        $directive = if ($entry.menu_index -eq 0) { '#if' } else { '#elif' }
        $lines.Add("$directive COPYRIGHTADAPTIVE_EFFECTIVE_SOURCE == $($entry.source_index)")
        $lines.Add("#define COPYRIGHTADAPTIVE_UI_INDEX $($entry.menu_index)")
    }
    $lines.Add('#else')
    $lines.Add('// Manual-only custom images are not dropdown entries; show the first menu item.')
    $lines.Add('#define COPYRIGHTADAPTIVE_UI_INDEX 0')
    $lines.Add('#endif')
    $lines.Add('')
    $lines.Add('#undef COPYRIGHTADAPTIVE_TEXTURE_COMBO')
    $lines.Add('#define COPYRIGHTADAPTIVE_TEXTURE_COMBO(variable, name_label, description) \')
    $lines.Add('uniform int variable \')
    $lines.Add('< \')
    $lines.Add('    ui_items = \')
    foreach ($entry in $KeptEntries) { $lines.Add('        "' + $entry.label + '\0" \') }
    $lines.Add('        ; \')
    $lines.Add('    ui_bind = "CopyrightAdaptive_Menu_Source"; \')
    $lines.Add('    ui_label = name_label; \')
    $lines.Add('    ui_tooltip = description; \')
    $lines.Add('    ui_spacing = 1; \')
    $lines.Add('    ui_type = "combo"; \')
    $lines.Add('> = COPYRIGHTADAPTIVE_UI_INDEX;')
    $lines.Add('')
    $first = $true
    foreach ($entry in $KeptEntries) {
        $directive = if ($first) { '#if' } else { '#elif' }
        $first = $false
        $lines.Add("$directive COPYRIGHTADAPTIVE_EFFECTIVE_SOURCE == $($entry.source_index)")
        $lines.Add('#define COPYRIGHTADAPTIVE_SOURCE_FILE ' + $entry.file_expression)
        $lines.Add('#define COPYRIGHTADAPTIVE_SOURCE_SIZE ' + $entry.display_size_expression)
    }
    if ($ManualCustomMapping) {
        $lines.Add('#elif COPYRIGHTADAPTIVE_EFFECTIVE_SOURCE == 47')
        $lines.Add('#define COPYRIGHTADAPTIVE_SOURCE_FILE ' + (Convert-PrivateExpression $ManualCustomMapping.file_expression))
        $lines.Add('#define COPYRIGHTADAPTIVE_SOURCE_SIZE ' + (Convert-PrivateExpression $ManualCustomMapping.display_size_expression))
    }
    $fallbackEntry = @($KeptEntries | Where-Object { $_.source_index -eq $FallbackSourceIndex })[0]
    $lines.Add('#else')
    $lines.Add('#define COPYRIGHTADAPTIVE_SOURCE_FILE ' + $fallbackEntry.file_expression)
    $lines.Add('#define COPYRIGHTADAPTIVE_SOURCE_SIZE ' + $fallbackEntry.display_size_expression)
    $lines.Add('#endif')
    return ($lines.ToArray() -join "`r`n") + "`r`n"
}

# Prepare every header before writing any of them. Missing source metadata or a
# list with no available image must not leave a partly synchronized package.
$preparedHeaders = [System.Collections.Generic.List[object]]::new()
$allRemovedMissingImages = [System.Collections.Generic.List[string]]::new()
$allRemovedBuiltinImages = [System.Collections.Generic.List[string]]::new()
for ($listIndex = 0; $listIndex -lt $headerNames.Count; $listIndex++) {
    $headerName = $headerNames[$listIndex]
    $sourcePath = Join-Path $sourceDirectoryPath $headerName
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Required source header is missing: $sourcePath" }
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $metadata = Get-HeaderMetadata ([System.IO.File]::ReadAllText($sourcePath))
    $fallbackMappings = @($metadata.mappings | Where-Object { $_.is_fallback })
    if ($fallbackMappings.Count -ne 1) { throw "Expected exactly one fallback mapping in $headerName." }
    $fallbackMapping = $fallbackMappings[0]
    $mappingsBySource = @{}
    foreach ($mapping in $metadata.mappings) {
        if (-not $mapping.is_fallback -and $null -ne $mapping.source_index) {
            $normalizedVariable = $mapping.normalized_condition_variable
            if ($normalizedVariable -cne 'CopyrightAdaptive_Texture_Source') { throw "Unsupported source selector in $headerName`: $normalizedVariable" }
            $mappingsBySource[[int] $mapping.source_index] = $mapping
        }
    }
    $kept = [System.Collections.Generic.List[object]]::new()
    $removed = [System.Collections.Generic.List[object]]::new()
    $manualCustomMapping = $null
    for ($sourceIndex = 0; $sourceIndex -lt $metadata.menu_items.Count; $sourceIndex++) {
        $mapping = if ($mappingsBySource.ContainsKey($sourceIndex)) { $mappingsBySource[$sourceIndex] } else { $fallbackMapping }
        $filename = $mapping.filename
        $paths = @($mapping.resolved_texture_paths)
        $exists = $mapping.texture_exists -eq $true
        $isSymbolic = -not $filename
        $reason = 'missing-image'
        if ($isSymbolic) {
            if ($listIndex -eq 0 -and $sourceIndex -eq 47 -and $mapping.file_expression -ceq 'cLayerTex') {
                $filename = $defaultCustomTexture.filename
                $paths = @($defaultCustomTexture.resolved_texture_paths)
                $exists = $defaultCustomTexture.texture_exists
                $reason = 'missing-default-custom-texture'
                if (-not $exists) { $manualCustomMapping = $mapping }
            }
            else {
                $exists = $false
                $reason = 'unresolved-symbolic-texture'
            }
        }
        if (-not $exists) {
            $removed.Add([ordered]@{
                source_index = $sourceIndex
                original_source_index = $sourceIndex
                original_menu_index = $sourceIndex
                label = $metadata.menu_items[$sourceIndex]
                reason = $reason
                filename = $filename
                file_expression = $mapping.file_expression
                original_file_line = $mapping.original_file_line
                manual_override_supported = ($null -ne $manualCustomMapping -and $sourceIndex -eq 47)
            })
            if ($filename) {
                $allRemovedMissingImages.Add($filename)
                if (-not $isSymbolic) { $allRemovedBuiltinImages.Add($filename) }
            }
            continue
        }
        $kept.Add([ordered]@{
            source_index = $sourceIndex
            original_source_index = $sourceIndex
            original_menu_index = $sourceIndex
            menu_index = $kept.Count
            label = $metadata.menu_items[$sourceIndex]
            source_mapping_index = $mapping.source_index
            uses_original_fallback = $mapping.is_fallback
            file_expression = (Convert-PrivateExpression $mapping.file_expression)
            filename = $filename
            display_size_expression = (Convert-PrivateExpression $mapping.display_size_expression)
            original_file_line = $mapping.original_file_line
            texture_exists = $true
            resolved_texture_paths = $paths
        })
    }
    if ($kept.Count -eq 0) { throw "No available dropdown images remain for $headerName. Nothing was written." }
    $fallbackSourceIndex = [int] $kept[0].source_index
    $privateText = New-PrivateHeader -HeaderName $headerName -SourceHash $sourceHash -Metadata $metadata -KeptEntries $kept.ToArray() -ManualCustomMapping $manualCustomMapping -FallbackSourceIndex $fallbackSourceIndex
    $sourceToMenu = [ordered]@{}
    foreach ($entry in $kept) { $sourceToMenu[[string] $entry.source_index] = $entry.menu_index }
    $removedMissingImages = @($removed | Where-Object { $_.filename } | ForEach-Object { $_.filename } | Sort-Object -Unique)
    $preparedHeaders.Add([ordered]@{
        list_index = $listIndex
        name = $headerName
        source_path = $sourcePath
        source_sha256 = $sourceHash
        private_path = Join-Path $destinationDirectoryPath $headerName
        private_text = $privateText
        metadata = $metadata
        kept_menu_entries = @($kept.ToArray())
        removed_menu_entries = @($removed.ToArray())
        menu_to_source_index = @($kept | ForEach-Object { [int] $_.source_index })
        source_to_menu_index = $sourceToMenu
        fallback_source_index = $fallbackSourceIndex
        removed_missing_images = $removedMissingImages
        manual_custom_mapping = $manualCustomMapping
    })
}

[System.IO.Directory]::CreateDirectory($destinationDirectoryPath) | Out-Null
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$manifestHeaders = [System.Collections.Generic.List[object]]::new()
foreach ($header in $preparedHeaders) {
    [System.IO.File]::WriteAllText($header.private_path, $header.private_text, $utf8NoBom)
    $privateHash = (Get-FileHash -LiteralPath $header.private_path -Algorithm SHA256).Hash.ToLowerInvariant()
    $manualOnly = @()
    if ($header.manual_custom_mapping) {
        $manualOnly = @([ordered]@{
            source_index = 47
            file_expression = 'CopyrightAdaptiveTex'
            display_size_expression = (Convert-PrivateExpression $header.manual_custom_mapping.display_size_expression)
            menu_index = $null
            ui_default_index = 0
            requires_no_menu_override = $true
            requires_explicit_custom_texture = 'COPYRIGHTADAPTIVE_CUSTOM_TEXTURE_PROVIDED=1'
            default_texture_missing = $true
        })
    }
    $manifestHeaders.Add([ordered]@{
        list_index = $header.list_index
        source_file = $header.source_path
        private_file = $header.private_path
        source_sha256 = $header.source_sha256
        private_sha256 = $privateHash
        original_menu_entry_count = $header.metadata.menu_items.Count
        menu_entry_count = $header.kept_menu_entries.Count
        removed_menu_entry_count = $header.removed_menu_entries.Count
        explicit_mapping_count = @($header.metadata.mappings | Where-Object { -not $_.is_fallback }).Count
        fallback_mapping_count = @($header.metadata.mappings | Where-Object { $_.is_fallback }).Count
        mapping_count_including_fallback = $header.metadata.mappings.Count
        effective_mapping_count = $header.kept_menu_entries.Count
        menu_items = @($header.kept_menu_entries | ForEach-Object { $_.label })
        original_menu_items = $header.metadata.menu_items
        mappings = $header.metadata.mappings
        effective_mappings = $header.kept_menu_entries
        kept_menu_entries = $header.kept_menu_entries
        removed_menu_entries = $header.removed_menu_entries
        menu_to_source_index = $header.menu_to_source_index
        source_to_menu_index = $header.source_to_menu_index
        fallback_source_index = $header.fallback_source_index
        generated_fallback_mapping = $header.kept_menu_entries[0]
        manual_only_mappings = $manualOnly
        missing_images = @()
        removed_missing_images = $header.removed_missing_images
    })
}
$manifest = [ordered]@{
    schema_version = 2
    generated_by = 'Sync-CopyrightAdaptiveStyles.ps1'
    source_shader_directory = $sourceDirectoryPath
    private_shader_directory = $destinationDirectoryPath
    texture_directory = $textureDirectoryPath
    texture_directories = @($textureRoots | ForEach-Object { [ordered]@{ path = $_.path; recursive = $_.recursive } })
    texture_check = $(if ($ExactSearchPaths) { 'configured roots and recursive suffixes' } else { 'recursive file existence check' })
    legacy_style_id_macro = 'CopyrightAdaptive_Texture_Source'
    compact_menu_macro = 'CopyrightAdaptive_Menu_Source'
    effective_style_id_macro = 'COPYRIGHTADAPTIVE_EFFECTIVE_SOURCE'
    compact_ui_index_macro = 'COPYRIGHTADAPTIVE_UI_INDEX'
    token_replacements = $tokenReplacements
    headers = @($manifestHeaders.ToArray())
    missing_builtin_images = @($allRemovedBuiltinImages.ToArray() | Sort-Object -Unique)
    removed_missing_images = @($allRemovedMissingImages.ToArray() | Sort-Object -Unique)
    generated_missing_images = @()
    default_custom_texture = $defaultCustomTexture
    note = 'Unavailable assets are omitted from compact menus and default texture branches. Original style IDs, available asset filenames and display sizes remain compatible. Menu_Source takes precedence; otherwise Texture_Source selects a legacy ID. Invalid IDs use the first available style. Manual-only custom ID 47 requires an explicit custom texture and no Menu_Source override.'
}
$manifestPath = Join-Path $destinationDirectoryPath 'styles-manifest.json'
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 16) + [Environment]::NewLine, $utf8NoBom)

foreach ($header in $preparedHeaders) {
    $currentHash = (Get-FileHash -LiteralPath $header.source_path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($currentHash -cne $header.source_sha256) { throw "A source header changed during synchronization: $($header.source_path)" }
}
$manifestHeaders | ForEach-Object {
    [pscustomobject]@{
        Header = [System.IO.Path]::GetFileName($_.private_file)
        MenuEntries = $_.menu_entry_count
        RemovedEntries = $_.removed_menu_entry_count
        MissingDefaultImages = $_.missing_images.Count
        FallbackStyleId = $_.fallback_source_index
    }
} | Format-Table -AutoSize
Write-Output "Manifest: $manifestPath"
