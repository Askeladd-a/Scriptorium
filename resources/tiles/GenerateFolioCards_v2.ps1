# GenerateFolioCards_v2.ps1
# Compatibile sia con Windows PowerShell 5.1 che con PowerShell 7+
# Genera un card.txt (formato Sagrada: 7 righe per carta) con folii casuali 4x5.

param(
  [int]$Count = 30,
  [string]$OutFile = ".\card.txt",
  [int]$Seed = -1,
  [int]$MinO = 0,
  [int]$MaxO = 6,
  [int]$MinWild = 4,
  [ValidateSet("manuscript","balanced")]
  [string]$Mode = "manuscript"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Forza la working directory alla cartella dello script (utile se avviato con doppio click)
if ($PSScriptRoot -and (Test-Path $PSScriptRoot)) {
  Set-Location -Path $PSScriptRoot
}

# RNG compatibile (PS 5.1 non ha Get-Random -SetSeed)
if ($Seed -ge 0) { $rng = New-Object System.Random($Seed) }
else { $rng = New-Object System.Random }

function Get-RandIntInclusive {
  param([int]$Min,[int]$Max)
  if ($Max -lt $Min) { throw "Range random non valido: [$Min..$Max]" }
  # Next è esclusivo sul Max, quindi +1
  return $rng.Next($Min, $Max + 1)
}

function Get-WeightedRandomSymbol {
  param([hashtable]$Weights)

  $total = 0
  foreach ($k in $Weights.Keys) { $total += [int]$Weights[$k] }
  if ($total -le 0) { throw "Pesi non validi: somma = $total" }

  $roll = Get-RandIntInclusive -Min 1 -Max $total
  $acc = 0
  foreach ($k in $Weights.Keys) {
    $acc += [int]$Weights[$k]
    if ($roll -le $acc) { return [string]$k }
  }
  return [string]($Weights.Keys | Select-Object -First 1)
}

# Maschera sezioni 4x5 (solo per pesi “da manoscritto”)
$SectionMask = @(
  @("C","C","T","M","M"),
  @("C","C","T","M","M"),
  @("B","T","T","T","B"),
  @("A","B","T","B","A")
)

# Pesi simboli: 1..6 e w
$WeightsBySection = @{}

if ($Mode -eq "manuscript") {
  $WeightsBySection["T"] = @{ "1"=10; "3"=10; "w"=6; "2"=2; "4"=2; "5"=2; "6"=1 }
  $WeightsBySection["C"] = @{ "4"=6;  "5"=6;  "6"=6; "3"=3; "1"=2; "w"=4; "2"=1 }
  $WeightsBySection["M"] = @{ "4"=6;  "5"=6;  "6"=5; "2"=3; "3"=2; "1"=2; "w"=4 }
  $WeightsBySection["B"] = @{ "2"=5;  "4"=5;  "5"=5; "1"=3; "3"=3; "6"=2; "w"=5 }
  $WeightsBySection["A"] = @{ "6"=6;  "4"=4;  "5"=4; "2"=2; "3"=2; "1"=2; "w"=6 }
} else {
  $WeightsBySection["T"] = @{ "1"=6; "2"=4; "3"=6; "4"=4; "5"=4; "6"=3; "w"=8 }
  $WeightsBySection["C"] = @{ "1"=4; "2"=4; "3"=4; "4"=5; "5"=5; "6"=4; "w"=8 }
  $WeightsBySection["M"] = @{ "1"=4; "2"=5; "3"=4; "4"=5; "5"=5; "6"=4; "w"=8 }
  $WeightsBySection["B"] = @{ "1"=4; "2"=5; "3"=4; "4"=5; "5"=5; "6"=4; "w"=8 }
  $WeightsBySection["A"] = @{ "1"=4; "2"=5; "3"=4; "4"=5; "5"=5; "6"=4; "w"=8 }
}

function New-FolioGrid {
  param(
    [int]$MinWildLocal = 4,
    [int]$MaxAttempts = 300
  )

  for ($attempt = 0; $attempt -lt $MaxAttempts; $attempt++) {
    $grid = New-Object 'string[,]' 4,5
    $wildCount = 0

    for ($i=0; $i -lt 4; $i++) {
      for ($j=0; $j -lt 5; $j++) {
        $section = $SectionMask[$i][$j]
        $sym = Get-WeightedRandomSymbol -Weights $WeightsBySection[$section]
        $grid[$i,$j] = $sym
        if ($sym -eq "w") { $wildCount++ }
      }
    }

    if ($wildCount -ge $MinWildLocal) { return $grid }
  }

  throw "Impossibile generare una griglia valida dopo $MaxAttempts tentativi. Abbassa -MinWild o usa -Mode balanced."
}

function Grid-ToLines {
  param([string[,]]$Grid)
  $lines = @()
  for ($i=0; $i -lt 4; $i++) {
    $s = ""
    for ($j=0; $j -lt 5; $j++) { $s += $Grid[$i,$j] }
    $lines += $s
  }
  return $lines
}

# Scrittura file
$sb = New-Object System.Text.StringBuilder

for ($idx=1; $idx -le $Count; $idx++) {
  $folioId = ("folio_{0:D4}" -f $idx)
  $title = "Folio $idx"
  $oVal = Get-RandIntInclusive -Min $MinO -Max $MaxO

  $grid = New-FolioGrid -MinWildLocal $MinWild
  $gridLines = Grid-ToLines -Grid $grid

  [void]$sb.AppendLine($title)
  [void]$sb.AppendLine([string]$oVal)
  foreach ($ln in $gridLines) { [void]$sb.AppendLine($ln) }
  [void]$sb.AppendLine($folioId)
}

$fullOut = [System.IO.Path]::GetFullPath($OutFile)
[System.IO.File]::WriteAllText($fullOut, $sb.ToString(), [System.Text.Encoding]::UTF8)

Write-Host "OK: creato $fullOut con $Count folii. Mode=$Mode Seed=$Seed MinWild=$MinWild O=[$MinO..$MaxO]"
