param(
    [string] $AddonsPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'адоны')
)

$ErrorActionPreference = 'Stop'

$addonsKnowledgePath = Join-Path $PSScriptRoot 'allods_addons_knowledge.json'
$manifestPath = Join-Path $PSScriptRoot 'allods_manifest_index.json'

function Read-JsonFile {
    param([string] $Path)
    Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
}

function Get-FileSha256 {
    param([string] $Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

if (-not (Test-Path -LiteralPath $AddonsPath -PathType Container)) {
    throw "Addons folder not found: $AddonsPath"
}

if (-not (Test-Path -LiteralPath $addonsKnowledgePath -PathType Leaf)) {
    throw "Addons knowledge file not found: $addonsKnowledgePath"
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Manifest file not found: $manifestPath"
}

$database = Read-JsonFile $addonsKnowledgePath
$manifest = Read-JsonFile $manifestPath
$packages = @($database.packages)
$actualPaks = @(Get-ChildItem -LiteralPath $AddonsPath -File -Filter '*.pak' | Sort-Object Name)

$indexedByName = @{}
foreach ($package in $packages) {
    $indexedByName[$package.package_file] = $package
}

$manifestByName = @{}
foreach ($package in @($manifest.addon_packages)) {
    $manifestByName[$package.package_file] = $package
}

$issues = [System.Collections.Generic.List[string]]::new()

foreach ($pak in $actualPaks) {
    if (-not $indexedByName.ContainsKey($pak.Name)) {
        $issues.Add("Missing from allods_addons_knowledge.json: $($pak.Name)")
        continue
    }

    $record = $indexedByName[$pak.Name]
    if ([int64] $record.size_bytes -ne [int64] $pak.Length) {
        $issues.Add("Size mismatch for $($pak.Name): pak=$($pak.Length), index=$($record.size_bytes)")
    }

    $actualModified = $pak.LastWriteTimeUtc
    $recordModified = ([DateTime] $record.last_modified).ToUniversalTime()
    if ([Math]::Abs(($actualModified - $recordModified).TotalMilliseconds) -gt 1) {
        $issues.Add(
            "LastWriteTime mismatch for $($pak.Name): pak=$($actualModified.ToString('o')), index=$($recordModified.ToString('o'))"
        )
    }

    $actualHash = Get-FileSha256 $pak.FullName
    if ($record.sha256 -ne $actualHash) {
        $issues.Add("Sha256 mismatch for $($pak.Name)")
    }

    if (-not $manifestByName.ContainsKey($pak.Name)) {
        $issues.Add("Missing from allods_manifest_index.json addon_packages: $($pak.Name)")
    }
}

$actualNames = @($actualPaks | ForEach-Object Name)
foreach ($package in $packages) {
    if ($actualNames -notcontains $package.package_file) {
        $issues.Add("Indexed package missing from addons folder: $($package.package_file)")
    }
}

if ([int] $database.metadata.package_count -ne $actualPaks.Count) {
    $issues.Add("Metadata package_count mismatch: pak=$($actualPaks.Count), index=$($database.metadata.package_count)")
}

if ([int] $manifest.metadata.addon_package_count -ne $actualPaks.Count) {
    $issues.Add("Manifest addon_package_count mismatch: pak=$($actualPaks.Count), manifest=$($manifest.metadata.addon_package_count)")
}

if (@($manifest.addon_packages).Count -ne $actualPaks.Count) {
    $issues.Add("Manifest addon_packages length mismatch: pak=$($actualPaks.Count), manifest=$(@($manifest.addon_packages).Count)")
}

if ($issues.Count -eq 0) {
    Write-Host "Addon index is fresh."
    Write-Host "Packages: $($actualPaks.Count)"
    Write-Host "Addons knowledge generated_at: $($database.metadata.generated_at)"
    Write-Host "Manifest generated_at: $($manifest.metadata.generated_at)"
    exit 0
}

Write-Host "Addon index is stale or inconsistent:"
foreach ($issue in $issues) {
    Write-Host "- $issue"
}
exit 1
