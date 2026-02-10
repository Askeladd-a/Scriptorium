# GenerateFolioCards_v2.ps1
# Compatibile sia con Windows PowerShell 5.1 che con PowerShell 7+
# Genera un card.txt (formato folio card: 7 righe per carta) con folii casuali 4x5.

param(
  [ValidateRange(1, 10000)]
  [int]$Count = 30,

  [string]$OutFile = ".\card.txt",

  [int]$Seed = -1,

  [ValidateRange(0, 6)]
  [int]$MinO = 0,

  [ValidateRange(0, 6)]
  [int]$MaxO = 6,

  [ValidateRange(0, 20)]
  [int]$MinWild = 4,

  [ValidateRange(0, 20)]
  [int]$MaxWild = 12,

  [ValidateRange(1, 20)]
  [int]$MinDistinctSymbols = 4,

  [ValidateRange(1, 5000)]
  [int]$MaxAttemptsPerCard = 300,

  [switch]$UniqueGrids,

  [ValidateSet("manuscript","balanced")]
  [string]$Mode = "manuscript"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Forza la working directory alla cartella dello script (utile se avviato con doppio click)
if ($PSScriptRoot -and (Test-Path $PSScriptRoot)) {
  Set-Location -Path $PSScriptRoot
}

if ($MaxO -lt $MinO) {
  throw "Range O non valido: MinO ($MinO) > MaxO ($MaxO)."
}
if ($MaxWild -lt $MinWild) {
  throw "Range wild non valido: MinWild ($MinWild) > MaxWild ($MaxWild)."
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

function Get-GridStats {
  param([string[,]]$Grid)
  $counts = @{}
  for ($i=0; $i -lt 4; $i++) {
    for ($j=0; $j -lt 5; $j++) {
      $sym = [string]$Grid[$i,$j]
      if (-not $counts.ContainsKey($sym)) { $counts[$sym] = 0 }
      $counts[$sym] = [int]$counts[$sym] + 1
    }
  }
  return $counts
}

function Grid-ToSignature {
  param([string[,]]$Grid)
  $rows = @()
  for ($i=0; $i -lt 4; $i++) {
    $s = ""
    for ($j=0; $j -lt 5; $j++) { $s += $Grid[$i,$j] }
    $rows += $s
  }
  return ($rows -join "|")
}

# Maschera sezioni 4x5
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
    [int]$MinWildLocal,
    [int]$MaxWildLocal,
    [int]$MinDistinct,
    [int]$MaxAttempts
  )

  for ($attempt = 0; $attempt -lt $MaxAttempts; $attempt++) {
    $grid = New-Object 'string[,]' 4,5

    for ($i=0; $i -lt 4; $i++) {
      for ($j=0; $j -lt 5; $j++) {
        $section = $SectionMask[$i][$j]
        $sym = Get-WeightedRandomSymbol -Weights $WeightsBySection[$section]
        $grid[$i,$j] = $sym
      }
    }

    $stats = Get-GridStats -Grid $grid
    $wildCount = 0
    if ($stats.ContainsKey('w')) { $wildCount = [int]$stats['w'] }
    $distinctCount = $stats.Keys.Count

    if ($wildCount -ge $MinWildLocal -and $wildCount -le $MaxWildLocal -and $distinctCount -ge $MinDistinct) {
      return $grid
    }
  }

  throw "Impossibile generare una griglia valida dopo $MaxAttempts tentativi. Riduci i vincoli (MinDistinct/MinWild/MaxWild) o cambia mode."
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

$sb = New-Object System.Text.StringBuilder
$seen = @{}
$duplicatesSkipped = 0

for ($idx=1; $idx -le $Count; $idx++) {
  $folioId = ("folio_{0:D4}" -f $idx)
  $title = "Folio $idx"
  $oVal = Get-RandIntInclusive -Min $MinO -Max $MaxO

  $grid = $null

  if ($UniqueGrids) {
    $maxUniqRetries = 200
    for ($r=0; $r -lt $maxUniqRetries; $r++) {
      $candidate = New-FolioGrid -MinWildLocal $MinWild -MaxWildLocal $MaxWild -MinDistinct $MinDistinctSymbols -MaxAttempts $MaxAttemptsPerCard
      $sig = Grid-ToSignature -Grid $candidate
      if (-not $seen.ContainsKey($sig)) {
        $grid = $candidate
        $seen[$sig] = $true
        break
      }
      $duplicatesSkipped++
    }

    if ($null -eq $grid) {
      throw "Non sono riuscito a generare una griglia unica per il folio $idx dopo $maxUniqRetries tentativi."
    }
  }
  else {
    $grid = New-FolioGrid -MinWildLocal $MinWild -MaxWildLocal $MaxWild -MinDistinct $MinDistinctSymbols -MaxAttempts $MaxAttemptsPerCard
  }

  $gridLines = Grid-ToLines -Grid $grid

  [void]$sb.AppendLine($title)
  [void]$sb.AppendLine([string]$oVal)
  foreach ($ln in $gridLines) { [void]$sb.AppendLine($ln) }
  [void]$sb.AppendLine($folioId)
}

$fullOut = [System.IO.Path]::GetFullPath($OutFile)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($fullOut, $sb.ToString(), $utf8NoBom)

Write-Host "OK: creato $fullOut con $Count folii. Mode=$Mode Seed=$Seed MinWild=$MinWild MaxWild=$MaxWild MinDistinct=$MinDistinctSymbols Unique=$($UniqueGrids.IsPresent) DuplicatiScartati=$duplicatesSkipped O=[$MinO..$MaxO]"
