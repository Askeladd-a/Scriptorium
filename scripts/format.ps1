$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

if (-not (Get-Command stylua -ErrorAction SilentlyContinue)) {
    Write-Error "stylua not found. Install stylua to format Lua files."
}

stylua .
exit $LASTEXITCODE
