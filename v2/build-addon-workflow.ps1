param(
    [Parameter(Mandatory = $true)]
    [string] $ProjectPath,

    [switch] $InstallToGame,

    [switch] $Overwrite
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$resolvedProject = (Resolve-Path -LiteralPath $ProjectPath).Path
$addonsPath = Join-Path $workspaceRoot 'адоны'
$pakName = "$(Split-Path -Leaf $resolvedProject).pak"
$outputPak = Join-Path $addonsPath $pakName

$build = & (Join-Path $PSScriptRoot 'build-addon-pak.ps1') `
    -ProjectPath $resolvedProject `
    -OutputPath $outputPak `
    -Overwrite:$Overwrite `
    -SkipIndexUpdateWarning

& (Join-Path $PSScriptRoot 'update-addons-knowledge.ps1') -AddonsPath $addonsPath
& (Join-Path $PSScriptRoot 'check-addons-freshness.ps1') -AddonsPath $addonsPath

$install = $null
if ($InstallToGame) {
    $install = & (Join-Path $PSScriptRoot 'install-addon-pak.ps1') `
        -PakPath $outputPak `
        -Overwrite:$Overwrite
}

[pscustomobject] [ordered]@{
    BuiltPak = $build.OutputPath
    InternalAddons = $build.InternalAddons
    Installed = [bool] $InstallToGame
    InstallTarget = if ($install) { $install.Target } else { $null }
}
