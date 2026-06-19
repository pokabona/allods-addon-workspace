$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$outputPath = Join-Path $root 'allods_search_index.jsonl'

function Read-JsonFile {
    param([string] $Name)
    Get-Content -LiteralPath (Join-Path $root $Name) -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
}

function Add-IndexRecord {
    param(
        [System.Collections.Generic.List[string]] $Lines,
        [string] $Scope,
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
        [string] $Text
    )

    $record = [ordered]@{
        sc = $Scope
        src = $Source
        id = $Id
        k = $Kind
        n = $Name
    }
    if ($ApiName) { $record.a = $ApiName }
    if ($Path -and $Path -ne $Id) { $record.p = $Path }
    if ($Declaration -and $Declaration -ne $ApiName) { $record.d = $Declaration }
    if ($Categories) { $record.cat = @($Categories) }
    if ($Keywords) { $record.kw = @($Keywords) }
    if ($Title) { $record.title = $Title }
    if ($Text) { $record.t = ($Text -replace '\s+', ' ').Trim() }

    $Lines.Add(($record | ConvertTo-Json -Depth 20 -Compress))
}

$lines = [System.Collections.Generic.List[string]]::new()
$indexedKeys = [System.Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase
)
$api = Read-JsonFile 'allods_api_core.json'
$runtime = Read-JsonFile 'allods_runtime_knowledge.json'
$examples = Read-JsonFile 'allods_examples_samples.json'
$addons = Read-JsonFile 'allods_addons_knowledge.json'
$history = Read-JsonFile 'allods_history_changelog.json'

foreach ($item in @($api.documents)) {
    Add-IndexRecord $lines Api api $item.id $item.kind $item.name $item.api_name `
        $item.relative_path $item.declaration $item.categories $null $null `
        $(if ($item.text) { $item.text } else { $item.summary_text })
}

foreach ($item in @($runtime.runtime_documents)) {
    Add-IndexRecord $lines Runtime runtime-document $item.id $item.kind $item.name `
        $item.api_name $item.relative_path $item.declaration $item.categories $null $null $item.text
}
foreach ($property in $runtime.runtime_widget_knowledge.reports.PSObject.Properties) {
    Add-IndexRecord $lines Runtime runtime-report $property.Name runtime_report $property.Name `
        $null "runtime_widget_knowledge/reports/$($property.Name)" $null $null $null $null `
        ($property.Value | ConvertTo-Json -Depth 100 -Compress)
}
foreach ($item in @($examples.examples)) {
    [void] $indexedKeys.Add("Examples::$($item.id)")
    Add-IndexRecord $lines Examples example $item.id $item.kind $item.name $null `
        $item.relative_path $null $null $item.keywords $null $item.text
}
foreach ($sampleGroup in @($examples.samples)) {
    foreach ($property in $sampleGroup.PSObject.Properties) {
        if ($property.Value -isnot [Management.Automation.PSCustomObject] -or -not $property.Value.entries) {
            continue
        }
        foreach ($item in @($property.Value.entries)) {
            if (-not $indexedKeys.Add("Examples::$($item.id)")) {
                continue
            }
            Add-IndexRecord $lines Examples sample $item.id $item.kind $item.name $null `
                $item.relative_path $null $null $item.keywords $null $item.text
        }
    }
}
foreach ($package in @($addons.packages)) {
    $packageText = @(
        $package.package_file
        $package.internal_addons
        $package.runtime_knowledge.status
        $package.runtime_knowledge.linked_report_ids
    ) -join ' '
    Add-IndexRecord $lines Addons addon-package $package.id addon_package $package.package_file `
        $null $package.source_path $null $null $null $null $packageText
    foreach ($file in @($package.files)) {
        Add-IndexRecord $lines Addons addon-file "$($package.id)::$($file.path)" `
            "addon_$($file.content_type)" ([IO.Path]::GetFileName($file.path)) $null `
            $file.path $null $null $null $null $file.text
    }
}
foreach ($item in @($history.change_log.entries)) {
    Add-IndexRecord $lines History history $item.id $item.kind $item.name $null `
        $item.relative_path $null $null $item.keywords $item.title $item.text
}

$temporaryPath = "$outputPath.tmp"
[IO.File]::WriteAllLines($temporaryPath, $lines, [Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $temporaryPath -Destination $outputPath -Force

Write-Host "Updated: $outputPath"
Write-Host "Search records: $($lines.Count)"
