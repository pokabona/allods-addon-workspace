param(
    [Parameter(Mandatory = $true)]
    [string] $ProjectPath,

    [string] $OutputPath,

    [switch] $ToAddonsFolder,

    [switch] $Overwrite
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$resolvedProject = (Resolve-Path -LiteralPath $ProjectPath).Path
$modsPath = Join-Path $resolvedProject 'Mods'

if (-not (Test-Path -LiteralPath $modsPath -PathType Container)) {
    throw "Project does not contain Mods folder: $resolvedProject"
}

$addonDesc = @(Get-ChildItem -LiteralPath $modsPath -Recurse -File -Filter 'AddonDesc.(UIAddon).xdb')
if ($addonDesc.Count -eq 0) {
    throw "No AddonDesc.(UIAddon).xdb found under: $modsPath"
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
    Get-ChildItem -LiteralPath (Join-Path $modsPath 'Addons') -Directory -ErrorAction SilentlyContinue |
        ForEach-Object Name |
        Sort-Object
)

[pscustomobject] [ordered]@{
    OutputPath = $outputFullPath
    SizeBytes = (Get-Item -LiteralPath $outputFullPath).Length
    InternalAddons = $internalAddons
    EntryMethod = 'Store'
}

