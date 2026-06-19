$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = Split-Path -Parent (Split-Path -Parent $projectRoot)
$builder = Join-Path $workspaceRoot "v2\build-addon-pak.ps1"

& $builder -ProjectPath $projectRoot @args
