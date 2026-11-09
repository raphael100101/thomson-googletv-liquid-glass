# Liste les applis de la télé (lecture seule, rien n'est changé), pour compléter debloat-thomson.txt.
# Usage : .\inventaire.ps1 -TvIp 192.168.1.50
param([Parameter(Position = 0)][string]$TvIp)
. "$PSScriptRoot\lib.ps1"
Set-TvIp $TvIp; Assert-Venv
$info = Connect-Tv
Write-Host "Connecté : $info"

$enabled  = Get-EnabledPackages
$thirdParty = @(Invoke-Tv 'pm list packages -3' | ForEach-Object { $_ -replace '^package:', '' })
$wanted   = Read-PackageList (Join-Path $KitDir 'debloat-thomson.txt')
# Mots qui signalent souvent une appli du fabricant (pubs, démo, statistiques...)
$hint = 'tcl|thomson|streamview|stv|partner|demo|exhibit|store\.mode|retail|ads|advert|analytics|feedback|log|tracking|promo|recommend'

$out = New-Object System.Collections.Generic.List[string]
$out.Add("# Inventaire de $info - $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
$out.Add('# Colonne 1 : DANS-LISTE = déjà dans debloat-thomson.txt ; A-VERIFIER = nom qui ressemble à une appli du fabricant')
$out.Add('# Colonne 2 : SYSTEME (préinstallée) ou AJOUTEE (installée depuis le Play Store)')
$out.Add('')
foreach ($p in $enabled) {
    $tag = if ($wanted -contains $p) { 'DANS-LISTE' } elseif ($p -match $hint) { 'A-VERIFIER' } else { '-' }
    $kind = if ($thirdParty -contains $p) { 'AJOUTEE' } else { 'SYSTEME' }
    $out.Add(('{0,-11} {1,-8} {2}' -f $tag, $kind, $p))
}
$file = Join-Path $KitDir ('inventaire-' + ($TvIp -replace '[.:]', '-') + '.txt')
Write-Lines $file $out
Write-Host "$($enabled.Count) applis actives. Liste enregistrée dans : $file"
Write-Host 'Ne désactive jamais une appli dont tu ne connais pas le rôle : en cas de doute, laisse-la.'
