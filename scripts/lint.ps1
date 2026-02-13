param(
    [switch]$NoFormatCheck
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

if (-not (Get-Command luacheck -ErrorAction SilentlyContinue)) {
    Write-Error "luacheck not found. Install luacheck to run lint."
}

Write-Host "[lint] luacheck"
luacheck .
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($NoFormatCheck) {
    Write-Host "[lint] skip stylua --check"
    exit 0
}

if (Get-Command stylua -ErrorAction SilentlyContinue) {
    Write-Host "[lint] stylua --check"
    stylua --check .
    exit $LASTEXITCODE
}

Write-Host "[lint] stylua not found, skipping format check"
exit 0
