$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$required = @(
    'AGENTS.md',
    'v2',
    'адоны',
    'ModdingDocuments'
)

$missing = @(
    foreach ($item in $required) {
        $path = Join-Path $workspaceRoot $item
        if (-not (Test-Path -LiteralPath $path)) {
            $item
        }
    }
)

if ($missing.Count -gt 0) {
    throw "Resolved workspace root looks incomplete: $workspaceRoot; missing: $($missing -join ', ')"
}

[pscustomobject] [ordered]@{
    WorkspaceRoot = $workspaceRoot
    V2 = $PSScriptRoot
    Addons = Join-Path $workspaceRoot 'адоны'
    ModdingDocuments = Join-Path $workspaceRoot 'ModdingDocuments'
}
