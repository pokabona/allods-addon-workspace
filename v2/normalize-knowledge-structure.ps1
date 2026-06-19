$ErrorActionPreference = 'Stop'
$apiPath = Join-Path $PSScriptRoot 'allods_api_core.json'
$runtimePath = Join-Path $PSScriptRoot 'allods_runtime_knowledge.json'

function Read-JsonFile {
    param([string] $Path)
    Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
}

$api = Read-JsonFile $apiPath
$runtime = Read-JsonFile $runtimePath

$apiRules = [System.Collections.Generic.List[string]]::new()
$runtimeRules = [System.Collections.Generic.List[string]]::new()

foreach ($rule in @($api.ai_usage_rules)) {
    if ($rule -match '^(Runtime |Runtime widget knowledge|Bag/bank mover rule:|Before building a window mover|Do not infer the movable root|After every new verified runtime finding|Mark unverified addon strategies|Do not treat generated helper scripts|Do not repeat the WidgetTreeLogger|For ContextDepositeBox|For RemortList)') {
        $runtimeRules.Add([string] $rule)
    }
    else {
        $apiRules.Add([string] $rule)
    }
}

foreach ($rule in @($runtime.usage_rules)) {
    if (-not $runtimeRules.Contains([string] $rule)) {
        $runtimeRules.Add([string] $rule)
    }
}

$api.ai_usage_rules = @($apiRules)
$runtime | Add-Member -NotePropertyName usage_rules -NotePropertyValue @($runtimeRules) -Force
$runtime.metadata | Add-Member -NotePropertyName usage_rules_migrated_from_api -NotePropertyValue $true -Force

$apiTemp = "$apiPath.tmp"
$runtimeTemp = "$runtimePath.tmp"
$api | ConvertTo-Json -Depth 100 -Compress | Set-Content -LiteralPath $apiTemp -Encoding utf8
$runtime | ConvertTo-Json -Depth 100 -Compress | Set-Content -LiteralPath $runtimeTemp -Encoding utf8
$null = Read-JsonFile $apiTemp
$null = Read-JsonFile $runtimeTemp
Move-Item -LiteralPath $apiTemp -Destination $apiPath -Force
Move-Item -LiteralPath $runtimeTemp -Destination $runtimePath -Force

Write-Host "API usage rules: $($apiRules.Count)"
Write-Host "Runtime usage rules: $($runtimeRules.Count)"
