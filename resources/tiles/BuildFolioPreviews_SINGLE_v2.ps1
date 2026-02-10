<# 
BuildFolioPreviews_SINGLE_v2.ps1
- Genera un card.txt casuale (pattern 4x5) e poi lancia Sagrada_generator.ps1 per creare le preview PNG.
- Compatibile con Windows PowerShell 5.1 e PowerShell 7+.
Uso:
  powershell -ExecutionPolicy Bypass -File .\BuildFolioPreviews_SINGLE_v2.ps1 -Count 30
  powershell -ExecutionPolicy Bypass -File .\BuildFolioPreviews_SINGLE_v2.ps1 -Count 30 -Seed 12345
#>

[CmdletBinding()]
param(
  [int]$Count = 30,
  [int]$Seed,
  [int]$MinWild = 4,
  [string]$CardFile = "card.txt",
  [string]$Renderer = "Sagrada_generator.ps1"
)

# Vai nella cartella dello script (così doppio-click / BAT funziona sempre)
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $PSScriptRoot

# Check renderer
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

# RNG (PowerShell 5.1 friendly: niente -SetSeed e niente ternary operator)
$useSeed = $PSBoundParameters.ContainsKey('Seed')
if ($useSeed) { $rng = New-Object System.Random($Seed) }
else { $rng = New-Object System.Random([Environment]::TickCount) }

function Pick-Weighted([hashtable]$weights) {
  $total = 0.0
  foreach ($v in $weights.Values) { $total += [double]$v }
  $r = $rng.NextDouble() * $total
  $acc = 0.0
  foreach ($k in $weights.Keys) {
    $acc += [double]$weights[$k]
    if ($r -le $acc) { return [string]$k }
  }
  return [string]($weights.Keys | Select-Object -First 1)
}

function Get-Section([int]$r, [int]$c) {
  # Priorità: angoli -> capolettera -> miniatura -> bordi -> testo
  if (($r -eq 0 -or $r -eq 3) -and ($c -eq 0 -or $c -eq 4)) { return "Angoli" }
  if ($r -le 1 -and $c -le 1) { return "Capolettera" }
  if ($r -le 1 -and $c -ge 3) { return "Miniatura" }
  if ($r -eq 0 -or $r -eq 3 -or $c -eq 0 -or $c -eq 4) { return "Bordi" }
  return "Testo"
}

# Pesi "da manoscritto" (modifica qui se vuoi più/meno vincoli)
$W_Test  = @{ w=0.25; '1'=0.25; '3'=0.25; '2'=0.08; '4'=0.07; '5'=0.07; '6'=0.03 }
$W_Bordi = @{ w=0.30; '1'=0.15; '3'=0.15; '2'=0.10; '4'=0.10; '5'=0.10; '6'=0.10 }
$W_Ang   = @{ w=0.25; '6'=0.25; '5'=0.15; '4'=0.15; '3'=0.10; '2'=0.05; '1'=0.05 }
$W_Capo  = @{ w=0.20; '6'=0.20; '5'=0.20; '4'=0.20; '3'=0.10; '1'=0.10 }
$W_Mini  = @{ w=0.20; '6'=0.25; '5'=0.25; '4'=0.15; '2'=0.05; '3'=0.05; '1'=0.05 }

function SectionWeights([string]$section) {
  switch ($section) {
    "Angoli"      { return $W_Ang }
    "Capolettera" { return $W_Capo }
    "Miniatura"   { return $W_Mini }
    "Bordi"       { return $W_Bordi }
    default       { return $W_Test }
  }
}

# Genera carte
$linesOut = New-Object System.Collections.Generic.List[string]

for ($i = 1; $i -le $Count; $i++) {

  $title = ("Folio {0:000}" -f $i)

  # Numero "O" (puoi interpretarlo come rischio/macchie iniziali): 1..6
  $risk = $rng.Next(1, 7)

  # Genera griglia 4x5 garantendo un minimo di 'w'
  $grid = @()
  $wildCount = 0

  do {
    $grid = @()
    $wildCount = 0
    for ($r = 0; $r -lt 4; $r++) {
      $rowChars = New-Object System.Collections.Generic.List[string]
      for ($c = 0; $c -lt 5; $c++) {
        $sec = Get-Section $r $c
        $sym = Pick-Weighted (SectionWeights $sec)
        if ($sym -eq "w") { $wildCount++ }
        $rowChars.Add($sym) | Out-Null
      }
      $grid += ($rowChars -join "")
    }
  } while ($wildCount -lt $MinWild)

  # ID immagine (senza estensione)
  $id = ("folio_{0:000}" -f $i)

  # Scrive blocco da 7 righe nel formato del tuo card.txt
  $linesOut.Add($title) | Out-Null
  $linesOut.Add([string]$risk) | Out-Null
  $linesOut.Add($grid[0]) | Out-Null
  $linesOut.Add($grid[1]) | Out-Null
  $linesOut.Add($grid[2]) | Out-Null
  $linesOut.Add($grid[3]) | Out-Null
  $linesOut.Add($id) | Out-Null
}

# Salva card.txt (CRLF)
$linesOut | Out-File -FilePath $CardFile -Encoding ASCII

$seedMsg = ""
if ($useSeed) { $seedMsg = ", Seed=$Seed" }

Write-Host ("Creato {0} con {1} folii (MinWild={2}{3})." -f $CardFile, $Count, $MinWild, $seedMsg) -ForegroundColor Green

# Lancia renderer
Write-Host ("Eseguo {0}..." -f $Renderer) -ForegroundColor Cyan
& (Join-Path $PSScriptRoot $Renderer)

Write-Host "Fatto." -ForegroundColor Green
