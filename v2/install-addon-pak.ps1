param(
    [Parameter(Mandatory = $true)]
    [string] $PakPath,

    [string] $GameAddonsPath,

    [switch] $Overwrite
)

$ErrorActionPreference = 'Stop'

if (-not $GameAddonsPath) {
    $GameAddonsPath = $env:ALLODS_GAME_ADDONS_PATH
}

if (-not $GameAddonsPath) {
    $GameAddonsPath = 'C:\VK Play\Аллоды Онлайн\data\Mods\Addons'
}

$resolvedPak = (Resolve-Path -LiteralPath $PakPath).Path
if (-not (Test-Path -LiteralPath $GameAddonsPath -PathType Container)) {
    throw "Game addons folder not found: $GameAddonsPath"
}

$target = Join-Path $GameAddonsPath (Split-Path -Leaf $resolvedPak)
if ((Test-Path -LiteralPath $target) -and -not $Overwrite) {
    throw "Target already exists: $target. Pass -Overwrite to replace it."
}

Copy-Item -LiteralPath $resolvedPak -Destination $target -Force:$Overwrite

$targetItem = Get-Item -LiteralPath $target
[pscustomobject] [ordered]@{
    Source = $resolvedPak
    Target = $targetItem.FullName
    SizeBytes = $targetItem.Length
    TargetLastWriteTime = $targetItem.LastWriteTime
}

