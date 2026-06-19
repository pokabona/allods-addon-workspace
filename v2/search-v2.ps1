param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Query,

    [ValidateSet('Api', 'Runtime', 'Examples', 'Addons', 'History', 'All')]
    [string] $Scope = 'Api',

    [ValidateRange(1, 100)]
    [int] $MaxMatches = 5,

    [switch] $Full,

    [switch] $Raw,

    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Read-JsonFile {
    param([string] $Name)

    $path = Join-Path $root $Name
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file not found: $path"
    }

    Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
}

function Get-SearchText {
    param($Item)

    $parts = @(
        $Item.Id,
        $Item.Kind,
        $Item.Name,
        $Item.ApiName,
        $Item.Path,
        $Item.Declaration,
        $Item.Title,
        $Item.Categories,
        $Item.Keywords,
        $Item.Text
    )

    ($parts | Where-Object { $null -ne $_ -and "$_".Length -gt 0 }) -join ' '
}

function Get-Score {
    param($Item, [string] $Needle)

    $score = 0
    $escaped = [regex]::Escape($Needle)

    foreach ($field in @($Item.Name, $Item.ApiName, $Item.Id, $Item.Declaration, $Item.Path)) {
        if ([string]::IsNullOrWhiteSpace("$field")) {
            continue
        }
        if ("$field" -ieq $Needle) {
            $score += 200
        }
        if ("$field" -imatch "\b$escaped\b") {
            $score += 80
        }
        if ("$field".StartsWith($Needle, [System.StringComparison]::OrdinalIgnoreCase)) {
            $score += 40
        }
        if ("$field".IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $score += 20
        }
    }

    if ($Item.Text -and "$($Item.Text)".IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $score += 2
    }

    $score
}

function Get-Snippet {
    param([string] $Text, [string] $Needle, [int] $Length = 320)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $clean = ($Text -replace '\s+', ' ').Trim()
    $index = $clean.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase)
    if ($index -lt 0) {
        return $clean.Substring(0, [Math]::Min($Length, $clean.Length))
    }

    $start = [Math]::Max(0, $index - 120)
    $count = [Math]::Min($Length, $clean.Length - $start)
    $clean.Substring($start, $count)
}

function Get-CompactRecord {
    param($Item)

    [pscustomobject] [ordered]@{
        id = $Item.Id
        kind = $Item.Kind
        name = $Item.Name
        api_name = $Item.ApiName
        relative_path = $Item.Path
        declaration = $Item.Declaration
        categories = $Item.Categories
        keywords = $Item.Keywords
        title = $Item.Title
        text = $Item.Text
    }
}

function New-SearchItem {
    param(
        [string] $Source,
        [string] $Id,
        [string] $Kind,
        [string] $Name,
        [string] $ApiName,
        [string] $Path,
        [string] $Declaration,
        $Categories,
        $Keywords,
        [string] $Title,
        [string] $Text,
        $Raw
    )

    [pscustomobject]@{
        Source = $Source
        Id = $Id
        Kind = $Kind
        Name = $Name
        ApiName = $ApiName
        Path = $Path
        Declaration = $Declaration
        Categories = $Categories
        Keywords = $Keywords
        Title = $Title
        Text = $Text
        Raw = $Raw
    }
}

function Get-IndexedItems {
    param([string] $Needle, [string] $RequestedScope)

    $indexPath = Join-Path $root 'allods_search_index.jsonl'
    if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
        throw "Search index not found: $indexPath. Run update-manifest-index.ps1."
    }

    foreach ($line in [IO.File]::ReadLines($indexPath)) {
        if ($line.IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            continue
        }

        $record = $line | ConvertFrom-Json
        if ($RequestedScope -ne 'All' -and $record.sc -ne $RequestedScope) {
            continue
        }

        New-SearchItem -Source $record.src -Id $record.id -Kind $record.k `
            -Name $record.n -ApiName $record.a `
            -Path $(if ($record.p) { $record.p } else { $record.id }) `
            -Declaration $(if ($record.d) { $record.d } elseif ($record.k -eq 'function') { $record.a }) `
            -Categories $record.cat -Keywords $record.kw -Title $record.title `
            -Text $record.t -Raw $null
    }
}

$databaseCache = @{}

function Get-Database {
    param([string] $Name)
    if (-not $databaseCache.ContainsKey($Name)) {
        $databaseCache[$Name] = Read-JsonFile $Name
    }
    $databaseCache[$Name]
}

function Resolve-RawRecord {
    param($Item)

    switch ($Item.Source) {
        'api' {
            $db = Get-Database 'allods_api_core.json'
            return @($db.documents) | Where-Object id -eq $Item.Id | Select-Object -First 1
        }
        'runtime-document' {
            $db = Get-Database 'allods_runtime_knowledge.json'
            return @($db.runtime_documents) | Where-Object id -eq $Item.Id | Select-Object -First 1
        }
        'runtime-report' {
            $db = Get-Database 'allods_runtime_knowledge.json'
            return $db.runtime_widget_knowledge.reports.PSObject.Properties[$Item.Id].Value
        }
        'example' {
            $db = Get-Database 'allods_examples_samples.json'
            return @($db.examples) | Where-Object id -eq $Item.Id | Select-Object -First 1
        }
        'sample' {
            $db = Get-Database 'allods_examples_samples.json'
            foreach ($group in @($db.samples)) {
                foreach ($property in $group.PSObject.Properties) {
                    foreach ($entry in @($property.Value.entries)) {
                        if ($entry.id -eq $Item.Id) { return $entry }
                    }
                }
            }
        }
        'addon-package' {
            $db = Get-Database 'allods_addons_knowledge.json'
            return @($db.packages) | Where-Object id -eq $Item.Id | Select-Object -First 1
        }
        'addon-file' {
            $db = Get-Database 'allods_addons_knowledge.json'
            $separator = $Item.Id.IndexOf('::', [StringComparison]::Ordinal)
            $packageId = $Item.Id.Substring(0, $separator)
            $filePath = $Item.Id.Substring($separator + 2)
            $package = @($db.packages) | Where-Object id -eq $packageId | Select-Object -First 1
            return @($package.files) | Where-Object path -eq $filePath | Select-Object -First 1
        }
        'history' {
            $db = Get-Database 'allods_history_changelog.json'
            return @($db.change_log.entries) | Where-Object id -eq $Item.Id | Select-Object -First 1
        }
    }
}

$items = @(Get-IndexedItems -Needle $Query -RequestedScope $Scope)

$matches = @(
    $items |
        Where-Object {
            (Get-SearchText $_).IndexOf($Query, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        } |
        ForEach-Object {
            [pscustomobject]@{
                Score = Get-Score $_ $Query
                Item = $_
            }
        } |
        Sort-Object @{ Expression = 'Score'; Descending = $true },
                    @{ Expression = { $_.Item.Kind }; Descending = $false },
                    @{ Expression = { $_.Item.Name }; Descending = $false } |
        Select-Object -First $MaxMatches
)

if ($Raw) {
    $Full = $true
}

if ($Full) {
    foreach ($match in $matches) {
        $fullRecord = Resolve-RawRecord $match.Item
        if ($null -ne $fullRecord) {
            $match.Item.Raw = $fullRecord
        }
    }
}

$output = foreach ($match in $matches) {
    $item = $match.Item
    [pscustomobject]@{
        score = $match.Score
        source = $item.Source
        kind = $item.Kind
        name = if ($item.ApiName) { $item.ApiName } else { $item.Name }
        id = $item.Id
        path = $item.Path
        declaration = $item.Declaration
        snippet = if ($Full -or $Scope -ne 'Api') { Get-Snippet $item.Text $Query } else { $null }
        record = if ($Raw) {
            $item.Raw
        }
        elseif ($Full) {
            Get-CompactRecord -Item $item
        }
        else {
            $null
        }
    }
}

if ($Json) {
    $output | ConvertTo-Json -Depth 40
    exit 0
}

Write-Host "V2 search | scope: $Scope | query: $Query | matches: $($output.Count)"
Write-Host ''

foreach ($result in $output) {
    Write-Host "[$($result.kind)] $($result.name)"
    Write-Host "  source: $($result.source)"
    Write-Host "  id: $($result.id)"
    if ($result.path) {
        Write-Host "  path: $($result.path)"
    }
    if ($result.declaration) {
        Write-Host "  declaration: $($result.declaration)"
    }
    if ($result.snippet) {
        Write-Host "  snippet: $($result.snippet)"
    }
    Write-Host ''
}
