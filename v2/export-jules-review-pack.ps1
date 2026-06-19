param(
    [string] $OutputPath = (Join-Path (Get-Location) 'jules-allods-review-pack'),
    [switch] $Overwrite
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)

if ((Test-Path -LiteralPath $outputFullPath) -and -not $Overwrite) {
    throw "Output path already exists: $outputFullPath. Pass -Overwrite to replace it."
}

if (Test-Path -LiteralPath $outputFullPath) {
    Remove-Item -LiteralPath $outputFullPath -Recurse -Force
}
New-Item -ItemType Directory -Path $outputFullPath -Force | Out-Null

function Copy-WorkspaceItem {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RelativePath
    )

    $source = Join-Path $workspaceRoot $RelativePath
    $destination = Join-Path $outputFullPath $RelativePath
    $destinationParent = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationParent)) {
        New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    }
    Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
}

$includeFiles = @(
    'AGENTS.md',
    '.gitignore',
    '.gitattributes',
    '.vscode/settings.json',
    'v2/README.txt',
    'v2/audit-allods-workspace.ps1',
    'v2/build-addon-pak.ps1',
    'v2/build-addon-workflow.ps1',
    'v2/check-addons-freshness.ps1',
    'v2/export-jules-review-pack.ps1',
    'v2/install-addon-pak.ps1',
    'v2/resolve-allods-workspace.ps1',
    'v2/search-v2.ps1',
    'v2/update-addons-knowledge.ps1',
    'v2/update-manifest-index.ps1',
    'v2/update-search-index.ps1',
    'v2/allods_addons_knowledge.json',
    'v2/allods_manifest_index.json'
)

foreach ($relativePath in $includeFiles) {
    if (Test-Path -LiteralPath (Join-Path $workspaceRoot $relativePath)) {
        Copy-WorkspaceItem $relativePath
    }
}

foreach ($directory in @('projects', 'notes')) {
    if (Test-Path -LiteralPath (Join-Path $workspaceRoot $directory)) {
        Copy-WorkspaceItem $directory
    }
}

$prompt = @'
# Jules Review Prompt

You are reviewing a clean export of an Allods Online addon workspace. Do not
delete files or rewrite generated JSON. Treat this repository as a review pack,
not the live Google Drive workspace.

Goals:

1. Evaluate the workspace structure for AI/Codex efficiency.
2. Review the `v2/*.ps1` scripts for portability, safety, and maintainability.
3. Review the `projects/AutoVendorHelper_v1` source-to-PAK workflow.
4. Identify token-saving improvements: smaller context packets, better search
   outputs, better audit reporting, and safer generated-data handling.
5. Identify portability issues between Google Drive mounts such as `G:` and
   `H:`.
6. Suggest only safe, reviewable changes. Do not mass-delete duplicates, mass
   convert encodings, rename internal addon names, or replace all absolute paths
   blindly.

Useful commands:

```powershell
.\v2\resolve-allods-workspace.ps1
.\v2\check-addons-freshness.ps1
.\v2\audit-allods-workspace.ps1
.\v2\search-v2.ps1 "LabMap" -Scope Addons
.\v2\build-addon-pak.ps1 -ProjectPath .\projects\AutoVendorHelper_v1
```

Expected output:

- P0/P1/P2 findings with concrete paths.
- A short "do not do" section for risky cleanup ideas.
- A proposed next-step patch plan.
- If making code changes, keep them small and focused.
'@

Set-Content -LiteralPath (Join-Path $outputFullPath 'JULES_PROMPT.md') -Value $prompt -Encoding utf8

$readme = @'
# Allods Jules Review Pack

This is a clean review export for Google Jules or another cloud coding agent.
It intentionally excludes `_archive/`, `ModdingDocuments/`, heavy generated
search indexes, and live game folders.

Read `JULES_PROMPT.md` first.

This pack is safe to publish to a private GitHub repository for review. It is
not the live workspace.
'@

Set-Content -LiteralPath (Join-Path $outputFullPath 'README.md') -Value $readme -Encoding utf8

Push-Location $outputFullPath
try {
    git init | Out-Host
    git config user.name 'Codex Export'
    git config user.email 'codex-export@example.invalid'
    git config core.autocrlf false
    git add .
    git commit -m "Prepare Allods review pack for Jules" | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "git commit failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

[pscustomobject] [ordered]@{
    OutputPath = $outputFullPath
    FileCount = @(Get-ChildItem -LiteralPath $outputFullPath -Recurse -File -Force).Count
    GitStatus = (& git -C $outputFullPath status --short)
}
