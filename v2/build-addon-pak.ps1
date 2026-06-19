param(
    [Parameter(Mandatory = $true)]
    [string] $ProjectPath,

    [string] $OutputPath,

    [switch] $ToAddonsFolder,

    [switch] $Overwrite,

    [switch] $SkipIndexUpdateWarning
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$resolvedProject = (Resolve-Path -LiteralPath $ProjectPath).Path
$modsPath = Join-Path $resolvedProject 'Mods'
$modsAddonsPath = Join-Path $modsPath 'Addons'

if (-not (Test-Path -LiteralPath $modsPath -PathType Container)) {
    throw "Project does not contain Mods folder: $resolvedProject"
}

if (-not (Test-Path -LiteralPath $modsAddonsPath -PathType Container)) {
    throw "Project does not contain Mods/Addons folder: $resolvedProject"
}

$addonFolders = @(Get-ChildItem -LiteralPath $modsAddonsPath -Directory -ErrorAction SilentlyContinue)
if ($addonFolders.Count -eq 0) {
    throw "Project contains Mods/Addons but no internal addon folders: $modsAddonsPath"
}

$addonDesc = @(Get-ChildItem -LiteralPath $modsAddonsPath -Recurse -File -Filter 'AddonDesc.(UIAddon).xdb')
if ($addonDesc.Count -eq 0) {
    throw "No AddonDesc.(UIAddon).xdb found under: $modsAddonsPath"
}

$foldersWithoutDesc = @(
    $addonFolders |
        Where-Object {
            -not (Test-Path -LiteralPath (Join-Path $_.FullName 'AddonDesc.(UIAddon).xdb') -PathType Leaf)
        } |
        ForEach-Object Name
)
if ($foldersWithoutDesc.Count -gt 0) {
    Write-Warning "Internal addon folders without root AddonDesc.(UIAddon).xdb: $($foldersWithoutDesc -join ', ')"
}

$foldersWithoutScripts = @(
    $addonFolders |
        Where-Object {
            -not (Test-Path -LiteralPath (Join-Path $_.FullName 'Scripts') -PathType Container)
        } |
        ForEach-Object Name
)
if ($foldersWithoutScripts.Count -gt 0) {
    Write-Warning "Internal addon folders without Scripts folder: $($foldersWithoutScripts -join ', ')"
}

if (-not $SkipIndexUpdateWarning) {
    Write-Warning "build-addon-pak.ps1 only builds a PAK. If this PAK is copied to the authoritative адоны folder, run build-addon-workflow.ps1 or update-addons-knowledge.ps1 plus check-addons-freshness.ps1."
}

if (-not $OutputPath) {
    $pakName = "$(Split-Path -Leaf $resolvedProject).pak"
    if ($ToAddonsFolder) {
        $OutputPath = Join-Path (Join-Path $workspaceRoot 'адоны') $pakName
    }
    else {
        $OutputPath = Join-Path $resolvedProject $pakName
    }
}

$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
$outputParent = Split-Path -Parent $outputFullPath
if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
    New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
}

if ((Test-Path -LiteralPath $outputFullPath) -and -not $Overwrite) {
    throw "Output already exists: $outputFullPath. Pass -Overwrite to replace it."
}

$sevenZip = Get-Command 7z -ErrorAction Stop
if (Test-Path -LiteralPath $outputFullPath) {
    Remove-Item -LiteralPath $outputFullPath -Force
}

Push-Location $resolvedProject
try {
    & $sevenZip.Source a -tzip -mx=0 $outputFullPath 'Mods' | Out-Host
}
finally {
    Pop-Location
}

if ($LASTEXITCODE -ne 0) {
    throw "7z failed with exit code $LASTEXITCODE"
}

$archiveList = & $sevenZip.Source l -slt $outputFullPath
$methods = @(
    $archiveList |
        Where-Object { $_ -like 'Method = *' } |
        ForEach-Object { ($_ -replace '^Method = ', '').Trim() } |
        Where-Object { $_ }
)

$badMethods = @($methods | Where-Object { $_ -ne 'Store' })
if ($badMethods.Count -gt 0) {
    throw "PAK contains compressed entries instead of Store mode: $($badMethods -join ', ')"
}

$internalAddons = @(
    Get-ChildItem -LiteralPath $modsAddonsPath -Directory -ErrorAction SilentlyContinue |
        ForEach-Object Name |
        Sort-Object
)

[pscustomobject] [ordered]@{
    OutputPath = $outputFullPath
    SizeBytes = (Get-Item -LiteralPath $outputFullPath).Length
    InternalAddons = $internalAddons
    EntryMethod = 'Store'
}
