param(
    [string] $AddonsPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'адоны')
)

$ErrorActionPreference = 'Stop'
$outputPath = Join-Path $PSScriptRoot 'allods_addons_knowledge.json'
$runtimePath = Join-Path $PSScriptRoot 'allods_runtime_knowledge.json'
$manifestPath = Join-Path $PSScriptRoot 'allods_manifest_index.json'

if (-not (Test-Path -LiteralPath $AddonsPath -PathType Container)) {
    throw "Addons folder not found: $AddonsPath"
}

function Read-JsonFile {
    param([string] $Path)
    Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
}

function Get-Sha256 {
    param([byte[]] $Bytes)
    [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}

function Get-Crc32 {
    param([byte[]] $Bytes)

    [uint32] $crc = [uint32]::MaxValue
    [uint32] $polynomial = [uint32]::Parse(
        'edb88320',
        [Globalization.NumberStyles]::HexNumber
    )
    foreach ($byte in $Bytes) {
        $crc = $crc -bxor [uint32] $byte
        for ($i = 0; $i -lt 8; $i++) {
            if (($crc -band 1) -ne 0) {
                $crc = ($crc -shr 1) -bxor $polynomial
            }
            else {
                $crc = $crc -shr 1
            }
        }
    }

    $crc = $crc -bxor [uint32]::MaxValue
    $crc.ToString('x8')
}

function Convert-TextBytes {
    param([byte[]] $Bytes)

    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xff -and $Bytes[1] -eq 0xfe) {
        return [pscustomobject]@{
            Encoding = 'utf-16le'
            Text = [Text.Encoding]::Unicode.GetString($Bytes, 2, $Bytes.Length - 2)
        }
    }

    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xef -and $Bytes[1] -eq 0xbb -and $Bytes[2] -eq 0xbf) {
        return [pscustomobject]@{
            Encoding = 'utf-8-bom'
            Text = [Text.Encoding]::UTF8.GetString($Bytes, 3, $Bytes.Length - 3)
        }
    }

    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    try {
        return [pscustomobject]@{
            Encoding = 'utf-8'
            Text = $utf8.GetString($Bytes)
        }
    }
    catch {
        return [pscustomobject]@{
            Encoding = 'windows-1251'
            Text = [Text.Encoding]::GetEncoding(1251).GetString($Bytes)
        }
    }
}

$runtime = Read-JsonFile $runtimePath
$runtimeJson = $runtime | ConvertTo-Json -Depth 100 -Compress
$runtimeReports = @($runtime.runtime_widget_knowledge.reports.PSObject.Properties)
$textExtensions = @('.lua', '.xdb', '.txt', '.info', '.eng', '.rus', '.md', '.json', '.xml')
$packages = [System.Collections.Generic.List[object]]::new()

$totalFiles = 0
$totalTextFiles = 0
$totalBinaryFiles = 0
$totalSourceBytes = 0L
$totalEmbeddedTextBytes = 0L

foreach ($pak in Get-ChildItem -LiteralPath $AddonsPath -File -Filter '*.pak' | Sort-Object Name) {
    $pakBytes = [IO.File]::ReadAllBytes($pak.FullName)
    $stream = [IO.MemoryStream]::new($pakBytes, $false)
    $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read, $false)

    try {
        $files = [System.Collections.Generic.List[object]]::new()
        $internalAddons = [System.Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase
        )

        foreach ($entry in $archive.Entries) {
            if ([string]::IsNullOrEmpty($entry.Name)) {
                continue
            }

            $entryStream = $entry.Open()
            $memory = [IO.MemoryStream]::new()
            try {
                $entryStream.CopyTo($memory)
                $bytes = $memory.ToArray()
            }
            finally {
                $memory.Dispose()
                $entryStream.Dispose()
            }

            $normalizedPath = $entry.FullName.Replace('\', '/')
            $parts = $normalizedPath.Split('/')
            for ($index = 0; $index -lt $parts.Length - 1; $index++) {
                if ($parts[$index] -ieq 'Addons' -and $parts[$index + 1]) {
                    [void] $internalAddons.Add($parts[$index + 1])
                    break
                }
            }

            $extension = [IO.Path]::GetExtension($entry.Name).ToLowerInvariant()
            $isText = $textExtensions -contains $extension
            $compression = if ($entry.CompressedLength -eq $entry.Length) { 'store' } else { 'deflate' }

            $record = [ordered]@{
                path = $normalizedPath
                extension = if ($extension) { $extension } else { $null }
                size_bytes = $entry.Length
                compressed_size_bytes = $entry.CompressedLength
                compression = $compression
                crc32 = Get-Crc32 $bytes
                sha256 = Get-Sha256 $bytes
                content_type = if ($isText) { 'text' } else { 'binary' }
            }

            if ($isText) {
                $decoded = Convert-TextBytes $bytes
                $record.encoding = $decoded.Encoding
                $record.text = $decoded.Text
                $totalTextFiles++
                $totalEmbeddedTextBytes += $bytes.Length
            }
            else {
                $record.note = if ($extension -eq '.luac') {
                    'Compiled Lua bytecode; source is not recoverable from this record.'
                }
                else {
                    'Binary resource retained in the original PAK; only metadata and hash are stored here.'
                }
                $totalBinaryFiles++
            }

            $files.Add([pscustomobject] $record)
            $totalFiles++
            $totalSourceBytes += $bytes.Length
        }

        $id = [IO.Path]::GetFileNameWithoutExtension($pak.Name)
        $tokens = @($id) + @($internalAddons)
        $mentionCounts = [ordered]@{}
        foreach ($token in $tokens | Select-Object -Unique) {
            $mentionCounts[$token] = ([regex]::Matches(
                $runtimeJson,
                [regex]::Escape($token),
                [Text.RegularExpressions.RegexOptions]::IgnoreCase
            )).Count
        }

        $linkedReports = @(
            foreach ($report in $runtimeReports) {
                $reportJson = $report.Value | ConvertTo-Json -Depth 100 -Compress
                if ($tokens | Where-Object {
                    $reportJson.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0
                }) {
                    $report.Name
                }
            }
        )

        $mentioned = @($mentionCounts.Values | Where-Object { $_ -gt 0 }).Count -gt 0
        $packages.Add([pscustomobject] [ordered]@{
            id = $id
            package_file = $pak.Name
            source_path = "<AllodsWorkspace>/адоны/$($pak.Name)"
            size_bytes = $pak.Length
            last_modified = $pak.LastWriteTimeUtc.ToString('o')
            sha256 = Get-Sha256 $pakBytes
            archive_format = 'zip-compatible .pak'
            internal_addons = @($internalAddons | Sort-Object)
            file_count = $files.Count
            text_file_count = @($files | Where-Object content_type -eq 'text').Count
            binary_file_count = @($files | Where-Object content_type -eq 'binary').Count
            runtime_knowledge = [pscustomobject] [ordered]@{
                status = if ($mentioned) {
                    'mentioned_in_runtime_knowledge'
                }
                else {
                    'implementation_only_not_documented'
                }
                mention_counts = [pscustomobject] $mentionCounts
                linked_report_ids = $linkedReports
                note = if ($mentioned) {
                    'Package or internal addon names occur in runtime knowledge. This does not by itself prove the exact package version was verified.'
                }
                else {
                    'No package or internal addon name was found in runtime knowledge; behavior and lessons still need explicit documentation.'
                }
            }
            files = @($files)
        })
    }
    finally {
        $archive.Dispose()
        $stream.Dispose()
    }
}

$database = [pscustomobject] [ordered]@{
    metadata = [pscustomobject] [ordered]@{
        name = 'allods_addons_knowledge'
        generated_at = [DateTime]::UtcNow.ToString('o')
        source_folder = '<AllodsWorkspace>/адоны'
        purpose = 'Searchable inventory and source snapshot of current addon PAK files. Text sources are embedded; binary resources remain authoritative in the original PAK files.'
        package_count = $packages.Count
        file_count = $totalFiles
        text_file_count = $totalTextFiles
        binary_file_count = $totalBinaryFiles
        source_uncompressed_bytes = $totalSourceBytes
        embedded_text_bytes = $totalEmbeddedTextBytes
    }
    usage_rules = @(
        'Use this file to inspect the exact contents and source code of PAK files currently stored in the addons folder.'
        'Treat the original PAK files as authoritative for binary resources and archive layout.'
        'A runtime knowledge mention does not prove that the exact package version was tested unless an explicit report says so.'
        'Record verified behavior and failed approaches in allods_runtime_knowledge.json; keep implementation snapshots in this file.'
        'Do not infer source code from compiled .luac entries.'
    )
    packages = @($packages)
}

$database | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $outputPath -Encoding utf8

$manifest = Read-JsonFile $manifestPath
$manifest.metadata.generated_at = [DateTime]::UtcNow.ToString('o')
$manifest.metadata.addon_package_count = $packages.Count
$manifest.metadata.addons_knowledge_file = 'allods_addons_knowledge.json'
$manifest.metadata.purpose = 'Navigation manifest for current API, runtime findings, examples, history, and current addon package snapshots.'
$manifest.knowledge_files = @(
    [pscustomobject]@{ file = 'allods_search_index.jsonl'; role = 'generated_full_text_search_index_not_authoritative' }
    [pscustomobject]@{ file = 'allods_api_core.json'; role = 'authoritative_current_api' }
    [pscustomobject]@{ file = 'allods_runtime_knowledge.json'; role = 'verified_runtime_findings_and_widget_knowledge' }
    [pscustomobject]@{ file = 'allods_examples_samples.json'; role = 'official_examples_and_samples' }
    [pscustomobject]@{ file = 'allods_history_changelog.json'; role = 'historical_and_removed_api' }
    [pscustomobject]@{ file = 'allods_addons_knowledge.json'; role = 'current_local_pak_inventory_and_embedded_text_sources' }
)
$manifest.addon_packages = @(
    foreach ($package in $packages) {
        [pscustomobject] [ordered]@{
            id = $package.id
            package_file = $package.package_file
            internal_addons = $package.internal_addons
            file_count = $package.file_count
            text_file_count = $package.text_file_count
            binary_file_count = $package.binary_file_count
            runtime_status = $package.runtime_knowledge.status
        }
    }
)
$manifest | ConvertTo-Json -Depth 100 -Compress | Set-Content -LiteralPath $manifestPath -Encoding utf8

$searchIndexerPath = Join-Path $PSScriptRoot 'update-search-index.ps1'
if (Test-Path -LiteralPath $searchIndexerPath -PathType Leaf) {
    & $searchIndexerPath
}

Write-Host "Updated: $outputPath"
Write-Host "Packages: $($packages.Count)"
Write-Host "Files: $totalFiles (text: $totalTextFiles, binary: $totalBinaryFiles)"
Write-Host "Manifest updated: $manifestPath"
