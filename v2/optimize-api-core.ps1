param(
    [string] $Path = (Join-Path $PSScriptRoot 'allods_api_core.json')
)

$ErrorActionPreference = 'Stop'

function Normalize-DocText {
    param([string] $Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }

    $clean = ($Text -replace '\s+', ' ').Trim()
    $cutPoints = [System.Collections.Generic.List[int]]::new()

    foreach ($pattern in @(
        '\sSearch:\s*(?:"CategoryLuaApi"|CategoryLuaApi)',
        '\sСвязанные страницы:\s*(?:"CategoryLuaApi"|CategoryLuaApi)'
    )) {
        $match = [regex]::Match(
            $clean,
            $pattern,
            [Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
        if ($match.Success) {
            $cutPoints.Add($match.Index)
        }
    }

    if ($cutPoints.Count -gt 0) {
        $clean = $clean.Substring(0, ($cutPoints | Measure-Object -Minimum).Minimum).Trim()
    }

    $clean
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "API database not found: $Path"
}

$database = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
$changed = 0
$charactersRemoved = 0L

foreach ($document in @($database.documents)) {
    foreach ($propertyName in @('text', 'summary_text')) {
        $property = $document.PSObject.Properties[$propertyName]
        if ($null -eq $property -or [string]::IsNullOrWhiteSpace("$($property.Value)")) {
            continue
        }

        $before = [string] $property.Value
        $after = Normalize-DocText $before
        if ($after -ne $before) {
            $property.Value = $after
            $changed++
            $charactersRemoved += $before.Length - $after.Length
        }
    }
}

$database.metadata | Add-Member -NotePropertyName optimized_at -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
$database.metadata | Add-Member -NotePropertyName optimization -NotePropertyValue 'Removed generated Search/related-pages navigation tails from document text.' -Force

$temporaryPath = "$Path.tmp"
$database | ConvertTo-Json -Depth 100 -Compress | Set-Content -LiteralPath $temporaryPath -Encoding utf8

# Parse the generated file before replacing the working database.
$null = Get-Content -LiteralPath $temporaryPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
Move-Item -LiteralPath $temporaryPath -Destination $Path -Force

Write-Host "Optimized: $Path"
Write-Host "Fields changed: $changed"
Write-Host "Characters removed: $charactersRemoved"
