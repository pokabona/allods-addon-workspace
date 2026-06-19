$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$manifestPath = Join-Path $root 'allods_manifest_index.json'
$optimizerPath = Join-Path $root 'optimize-api-core.ps1'
$normalizerPath = Join-Path $root 'normalize-knowledge-structure.ps1'
$searchIndexerPath = Join-Path $root 'update-search-index.ps1'

if (Test-Path -LiteralPath $normalizerPath -PathType Leaf) {
    & $normalizerPath
}
if (Test-Path -LiteralPath $optimizerPath -PathType Leaf) {
    & $optimizerPath
}

function Read-JsonFile {
    param([string] $Name)

    $path = Join-Path $root $Name
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file not found: $path"
    }

    Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
}

function New-IndexRecord {
    param($Item)

    $record = [ordered]@{
        id = $Item.id
        k = $Item.kind
        n = $Item.name
    }

    $apiNameIsNavigation = "$($Item.api_name)" -match 'BlurpSearch|Связанные страницы|^Search:'
    if ($Item.api_name -and -not $apiNameIsNavigation -and $Item.api_name -ne $Item.name) {
        $record.a = $Item.api_name
    }
    if ($Item.relative_path -and $Item.relative_path -ne $Item.id) {
        $record.p = $Item.relative_path
    }
    if ($Item.declaration -and $Item.declaration -ne $Item.api_name) {
        $record.d = $Item.declaration
    }

    [pscustomobject] $record
}

$api = Read-JsonFile 'allods_api_core.json'
$runtime = Read-JsonFile 'allods_runtime_knowledge.json'
$addons = Read-JsonFile 'allods_addons_knowledge.json'

$documents = @(
    foreach ($item in @($api.documents)) {
        New-IndexRecord $item
    }
    foreach ($item in @($runtime.runtime_documents)) {
        New-IndexRecord $item
    }
)

$counts = [ordered]@{}
foreach ($group in $documents | Group-Object k | Sort-Object Name) {
    $counts[$group.Name] = $group.Count
}

$manifest = [pscustomobject] [ordered]@{
    metadata = [pscustomobject] [ordered]@{
        name = 'allods_manifest_index'
        generated_at = [DateTime]::UtcNow.ToString('o')
        source = 'allods_api_core.json + allods_runtime_knowledge.json + allods_addons_knowledge.json'
        document_count = $documents.Count
        addon_package_count = $addons.packages.Count
        addons_knowledge_file = 'allods_addons_knowledge.json'
        purpose = 'Compact navigation and search manifest for current API, runtime findings, examples, history, and current addon package snapshots.'
    }
    counts_by_kind = [pscustomobject] $counts
    knowledge_files = @(
        [pscustomobject]@{ file = 'allods_search_index.jsonl'; role = 'generated_full_text_search_index_not_authoritative' }
        [pscustomobject]@{ file = 'allods_api_core.json'; role = 'authoritative_current_api' }
        [pscustomobject]@{ file = 'allods_runtime_knowledge.json'; role = 'verified_runtime_findings_and_widget_knowledge' }
        [pscustomobject]@{ file = 'allods_examples_samples.json'; role = 'official_examples_and_samples' }
        [pscustomobject]@{ file = 'allods_history_changelog.json'; role = 'historical_and_removed_api' }
        [pscustomobject]@{ file = 'allods_addons_knowledge.json'; role = 'current_local_pak_inventory_and_embedded_text_sources' }
    )
    documents = $documents
    addon_packages = @(
        foreach ($package in @($addons.packages)) {
            [pscustomobject] [ordered]@{
                id = $package.id
                package_file = $package.package_file
                internal_addons = @($package.internal_addons)
                file_count = $package.file_count
                text_file_count = $package.text_file_count
                binary_file_count = $package.binary_file_count
                runtime_status = $package.runtime_knowledge.status
            }
        }
    )
}

$manifest | ConvertTo-Json -Depth 20 -Compress | Set-Content -LiteralPath $manifestPath -Encoding utf8

if (Test-Path -LiteralPath $searchIndexerPath -PathType Leaf) {
    & $searchIndexerPath
}

Write-Host "Updated: $manifestPath"
Write-Host "Documents: $($documents.Count)"
Write-Host "Addon packages: $($addons.packages.Count)"
