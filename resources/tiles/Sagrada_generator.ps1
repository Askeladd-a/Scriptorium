Add-Type -AssemblyName System.Drawing
$debug=$false
$path = Get-Location
$path=$path.Path
$path_save="$path\Folio"
$ErrorActionPreference = 'silentlycontinue'

Function Get-Picture {
Param ([String]$numer)
Process
    {
        return "$path\$numer.png"
    }
}
if(([System.IO.File]::Exists($("$path\card.txt"))))
{
    $karta= Get-Content -Path "$path\card.txt"



if (($karta.Length % 7) -eq 0)
{
$files= $karta.Length / 7
Write-Host "Cards found - $files"
$brushFg = [System.Drawing.Brushes]::White 
$font = new-object System.Drawing.Font 'Uncial Antiqua',31
$format = [System.Drawing.StringFormat]::GenericDefault
$format.Alignment = [System.Drawing.StringAlignment]::Center
$format.LineAlignment = [System.Drawing.StringAlignment]::Center
$Picture = new-object System.Drawing.Bitmap 1055,934 
$graphics = [System.Drawing.Graphics]::FromImage($Picture) 

if(!([System.IO.Directory]::Exists($path_save)))
{
try {New-item -Name "Sagrada" -ItemType directory }
catch {Write-Host "Something went wrong creating directory"}
}

for (($x = 0); $x -lt $files ; $x++)
{
    if ($debug) {Write-Host "Karta $x"}
  
    $filename = "$path\Sagrada\$($karta[6+$(7*$x)]).png" 
    if ($debug) {Write-Host $karta[6+7*$x]}

    $graphics.Clear([System.Drawing.Color]::Black)
    $graphics.DrawString($karta[7*$x], $font, $brushFg, 527,905,$format );
    if ($debug) {Write-Host $karta[7*$x]}

    for ($i = 0; $i -lt 4; $i++)
    {
        for ($j = 0; $j -lt 5; $j++)
        {
            $graphics.DrawImage([System.Drawing.Bitmap]::FromFile("$(Get-Picture($karta[$i+2+(7*$x)][$j]))"), 25+($j)*206,21+($i)*207)
            if ($debug) {Write-Host $karta[$i+2+(7*$x)][$j] -NoNewline}
        }
        if ($debug) {Write-Host}
    }

    if ($debug) {Write-Host "Elements $($karta[1+(7*$x)])" }
    for ($y = 0; $y -lt $karta[1+(7*$x)]; $y++)
    {
        $graphics.DrawImage([System.Drawing.Bitmap]::FromFile("$(Get-Picture("O"))"), 981-($y*39), 885 )
    }

    $Picture.Save($filename) 

}
    $Picture.Dispose();
    $graphics.Dispose();
}
else
{
Write-Host "File has extra rows. Must be multiplication of 7."
}
}
else
{
Write-Host "No card.txt file."
}