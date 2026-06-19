param(
    [int] $TopDuplicates = 20,
    [switch] $IncludeArchive,
    [switch] $IncludeModdingDocuments,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$logicalRoot = '<AllodsWorkspace>'

$skipDirectories = @('.git')
if (-not $IncludeArchive) {
    $skipDirectories += '_archive'
}
if (-not $IncludeModdingDocuments) {
    $skipDirectories += 'ModdingDocuments'
}

$binaryExtensions = @(
    '.pak', '.bin', '.tga', '.png', '.jpg', '.jpeg', '.gif', '.dds', '.exe',
    '.dll', '.sqlite', '.wal', '.shm'
)

$textExtensions = @(
    '.lua', '.xdb', '.txt', '.md', '.json', '.jsonl', '.ps1', '.xml', '.info',
    '.eng', '.rus', '.yml', '.yaml', '.toml', '.csv'
)

function Get-RelativePath {
    param([string] $Path)
    [IO.Path]::GetRelativePath($workspaceRoot, $Path).Replace('\', '/')
}

function Should-SkipPath {
    param([IO.FileSystemInfo] $Item)
    $relative = Get-RelativePath $Item.FullName
    foreach ($dir in $skipDirectories) {
        if ($relative -eq $dir -or $relative.StartsWith("$dir/")) {
            return $true
        }
    }
    return $false
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

function Get-Zone {
    param([string] $RelativePath)
    if ($RelativePath.StartsWith('адоны/')) { return 'addons-pak-store' }
    if ($RelativePath.StartsWith('v2/')) { return 'v2-knowledge' }
    if ($RelativePath.StartsWith('projects/')) { return 'projects-source' }
    if ($RelativePath.StartsWith('notes/')) { return 'notes' }
    if ($RelativePath.StartsWith('ModdingDocuments/')) { return 'modding-documents' }
    if ($RelativePath.StartsWith('_archive/')) { return 'archive' }
    return 'workspace-root'
}

$files = @(
    Get-ChildItem -LiteralPath $workspaceRoot -Recurse -File -Force |
        Where-Object { -not (Should-SkipPath $_) }
)

$fileRecords = foreach ($file in $files) {
    $relative = Get-RelativePath $file.FullName
    [pscustomobject]@{
        path = $relative
        zone = Get-Zone $relative
        extension = $file.Extension.ToLowerInvariant()
        size_bytes = $file.Length
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        full_name = $file.FullName
    }
}

$duplicateGroups = @(
    $fileRecords |
        Where-Object { $_.size_bytes -gt 0 } |
        Group-Object sha256 |
        Where-Object { $_.Count -gt 1 } |
        Sort-Object Count -Descending |
        Select-Object -First $TopDuplicates |
        ForEach-Object {
            [pscustomobject]@{
                sha256 = $_.Name
                count = $_.Count
                size_bytes = $_.Group[0].size_bytes
                zones = @($_.Group.zone | Sort-Object -Unique)
                paths = @($_.Group.path | Sort-Object)
            }
        }
)

$emptyFiles = @(
    $fileRecords |
        Where-Object { $_.size_bytes -eq 0 } |
        Select-Object path, zone
)

$absolutePathPattern = '(?<![A-Za-z0-9\\])(?:[A-Za-z]:(?:\\\\|\\|/)[^"''<>|\r\n,;)]*)'
$absolutePaths = [System.Collections.Generic.List[object]]::new()
$cp1251Files = [System.Collections.Generic.List[object]]::new()
$todoHits = [System.Collections.Generic.List[object]]::new()

foreach ($record in $fileRecords) {
    if ($binaryExtensions -contains $record.extension) {
        continue
    }

    if ($textExtensions -notcontains $record.extension) {
        continue
    }

    $bytes = [IO.File]::ReadAllBytes($record.full_name)
    $decoded = Convert-TextBytes $bytes

    if ($decoded.Encoding -eq 'windows-1251') {
        $cp1251Files.Add([pscustomobject]@{
            path = $record.path
            zone = $record.zone
            recommendation = if ($record.zone -in @('projects-source', 'notes', 'workspace-root')) {
                'safe_candidate_for_utf8_after_manual_review'
            }
            else {
                'preserve_unless_intentionally_normalizing_reference_data'
            }
        })
    }

    $lines = $decoded.Text -split "`r?`n"
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]

        if ($line -match $absolutePathPattern) {
            foreach ($match in [regex]::Matches($line, $absolutePathPattern)) {
                $absolutePaths.Add([pscustomobject]@{
                    path = $record.path
                    zone = $record.zone
                    line = $index + 1
                    value = $match.Value
                    recommendation = if ($match.Value -match '^[GH]:\\Мой диск\\Аллоды проги') {
                        "replace_with_$logicalRoot"
                    }
                    elseif ($record.zone -eq 'v2-knowledge') {
                        'historical_or_runtime_path_review_before_rewrite'
                    }
                    else {
                        'review'
                    }
                })
            }
        }

        if ($record.path -notmatch '^ModdingDocuments/LuaCompiler/' -and
            $record.path -notmatch '^_archive/' -and
            $line -match '^\s*(--|#|//|/\*)\s*(TODO|FIXME|BUG)\b') {
            $todoHits.Add([pscustomobject]@{
                path = $record.path
                zone = $record.zone
                line = $index + 1
                text = $line.Trim()
            })
        }
    }
}

$summary = [pscustomobject] [ordered]@{
    workspace_root = $workspaceRoot
    logical_root = $logicalRoot
    included_archive = [bool] $IncludeArchive
    included_modding_documents = [bool] $IncludeModdingDocuments
    file_count = $fileRecords.Count
    total_bytes = ($fileRecords | Measure-Object size_bytes -Sum).Sum
    duplicate_group_count = @(
        $fileRecords |
            Where-Object { $_.size_bytes -gt 0 } |
            Group-Object sha256 |
            Where-Object { $_.Count -gt 1 }
    ).Count
    empty_file_count = $emptyFiles.Count
    absolute_path_hit_count = $absolutePaths.Count
    cp1251_file_count = $cp1251Files.Count
    todo_hit_count = $todoHits.Count
}

$result = [pscustomobject] [ordered]@{
    summary = $summary
    duplicate_groups_top = $duplicateGroups
    empty_files = $emptyFiles
    absolute_paths = @($absolutePaths)
    cp1251_files = @($cp1251Files)
    todo_hits = @($todoHits)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 20
    return
}

Write-Host "Allods workspace audit"
Write-Host "Root: $workspaceRoot"
Write-Host "Files scanned: $($summary.file_count)"
Write-Host "Duplicate groups: $($summary.duplicate_group_count) (showing top $TopDuplicates)"
Write-Host "Empty files: $($summary.empty_file_count)"
Write-Host "Absolute path hits: $($summary.absolute_path_hit_count)"
Write-Host "Windows-1251 candidates: $($summary.cp1251_file_count)"
Write-Host "Filtered TODO/FIXME/BUG hits: $($summary.todo_hit_count)"
Write-Host ""

if ($duplicateGroups.Count -gt 0) {
    Write-Host "Top duplicate groups:"
    foreach ($group in $duplicateGroups) {
        Write-Host "- count=$($group.count), size=$($group.size_bytes), zones=$($group.zones -join ', ')"
        foreach ($path in @($group.paths | Select-Object -First 6)) {
            Write-Host "  $path"
        }
        if ($group.paths.Count -gt 6) {
            Write-Host "  ... +$($group.paths.Count - 6) more"
        }
    }
    Write-Host ""
}

if ($emptyFiles.Count -gt 0) {
    Write-Host "Empty files:"
    foreach ($file in $emptyFiles) {
        Write-Host "- [$($file.zone)] $($file.path)"
    }
    Write-Host ""
}

if ($absolutePaths.Count -gt 0) {
    Write-Host "Absolute path hits:"
    foreach ($hit in @($absolutePaths | Select-Object -First 30)) {
        Write-Host "- $($hit.path):$($hit.line) [$($hit.recommendation)] $($hit.value)"
    }
    if ($absolutePaths.Count -gt 30) {
        Write-Host "... +$($absolutePaths.Count - 30) more; rerun with -Json for full detail."
    }
    Write-Host ""
}

if ($cp1251Files.Count -gt 0) {
    Write-Host "Windows-1251 candidates:"
    foreach ($file in @($cp1251Files | Select-Object -First 30)) {
        Write-Host "- [$($file.zone)] $($file.path) ($($file.recommendation))"
    }
    if ($cp1251Files.Count -gt 30) {
        Write-Host "... +$($cp1251Files.Count - 30) more; rerun with -Json for full detail."
    }
    Write-Host ""
}

if ($todoHits.Count -gt 0) {
    Write-Host "Filtered TODO/FIXME/BUG hits:"
    foreach ($hit in @($todoHits | Select-Object -First 30)) {
        Write-Host "- $($hit.path):$($hit.line) $($hit.text)"
    }
    if ($todoHits.Count -gt 30) {
        Write-Host "... +$($todoHits.Count - 30) more; rerun with -Json for full detail."
    }
}
