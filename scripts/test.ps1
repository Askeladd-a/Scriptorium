$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

if (-not (Get-Command lua -ErrorAction SilentlyContinue)) {
    Write-Error "lua not found. Install Lua 5.4+ to run tests."
}

lua tests/folio_flow_test.lua
exit $LASTEXITCODE
