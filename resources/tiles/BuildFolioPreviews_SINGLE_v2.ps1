<#
BuildFolioPreviews_SINGLE_v2.ps1
- Genera card.txt usando GenerateFolioCards_v2.ps1 e poi lancia RenderFolioPreviews.ps1 per creare preview PNG.
- Compatibile con Windows PowerShell 5.1 e PowerShell 7+.
Uso:
  powershell -ExecutionPolicy Bypass -File .\BuildFolioPreviews_SINGLE_v2.ps1 -Count 30
  powershell -ExecutionPolicy Bypass -File .\BuildFolioPreviews_SINGLE_v2.ps1 -Count 30 -Seed 12345 -UniqueGrids
#>

[CmdletBinding()]
param(
  [ValidateRange(1, 10000)]
  [int]$Count = 30,

  [int]$Seed,

  [ValidateSet("manuscript","balanced")]
  [string]$Mode = "manuscript",

  [ValidateRange(0, 20)]
  [int]$MinWild = 4,

  [ValidateRange(0, 20)]
  [int]$MaxWild = 12,

  [ValidateRange(1, 20)]
  [int]$MinDistinctSymbols = 4,

  [switch]$UniqueGrids,

  [ValidateRange(0, 6)]
  [int]$MinO = 0,

  [ValidateRange(0, 6)]
  [int]$MaxO = 6,

  [string]$CardFile = "card.txt",

  [string]$Generator = "GenerateFolioCards_v2.ps1",

  [string]$Renderer = "RenderFolioPreviews.ps1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($MaxO -lt $MinO) {
  throw "Range O non valido: MinO ($MinO) > MaxO ($MaxO)."
}
if ($MaxWild -lt $MinWild) {
  throw "Range wild non valido: MinWild ($MinWild) > MaxWild ($MaxWild)."
}

# Vai nella cartella dello script (così doppio-click / BAT funziona sempre)
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $PSScriptRoot

# Check script necessari
if (!(Test-Path $Generator)) {
  throw "Manca il generatore: $((Resolve-Path -LiteralPath $PSScriptRoot).Path)\$Generator"
}
if (!(Test-Path $Renderer)) {
  throw "Manca il renderer: $((Resolve-Path -LiteralPath $PSScriptRoot).Path)\$Renderer"
}

# Check tile PNG (non blocca: avvisa soltanto)
$requiredTiles = @("w","1","2","3","4","5","6","O") | ForEach-Object { "$_.png" }
$missing = @($requiredTiles | Where-Object { -not (Test-Path $_) })
if ($missing.Count -gt 0) {
  Write-Host "ATTENZIONE: mancano queste tile PNG nella cartella:" -ForegroundColor Yellow
  Write-Host ("  " + ($missing -join ", ")) -ForegroundColor Yellow
  Write-Host "Il renderer potrebbe fallire se usa quei simboli." -ForegroundColor Yellow
}

# Costruisci argomenti per il generatore
$generatorArgs = @(
  '-Count', $Count,
  '-OutFile', $CardFile,
  '-Mode', $Mode,
  '-MinWild', $MinWild,
  '-MaxWild', $MaxWild,
  '-MinDistinctSymbols', $MinDistinctSymbols,
  '-MinO', $MinO,
  '-MaxO', $MaxO
)

if ($PSBoundParameters.ContainsKey('Seed')) {
  $generatorArgs += @('-Seed', $Seed)
}
if ($UniqueGrids.IsPresent) {
  $generatorArgs += '-UniqueGrids'
}

Write-Host ("Genero card file con {0}..." -f $Generator) -ForegroundColor Cyan
& (Join-Path $PSScriptRoot $Generator) @generatorArgs

Write-Host ("Eseguo {0}..." -f $Renderer) -ForegroundColor Cyan
& (Join-Path $PSScriptRoot $Renderer)

Write-Host "Fatto." -ForegroundColor Green
