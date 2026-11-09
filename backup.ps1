# Sauvegarde l'état de la télé AVANT toute modification (lecture seule, rien n'est changé).
# Usage : .\backup.ps1 -TvIp 192.168.1.50
param([Parameter(Position = 0)][string]$TvIp)
. "$PSScriptRoot\lib.ps1"
Set-TvIp $TvIp; Assert-Venv
Write-Host "Connecté : $(Connect-Tv)"

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BK = Join-Path $KitDir ("backup-" + ($TvIp -replace '[.:]', '-') + "-$stamp")
New-Item -ItemType Directory -Force -Path $BK | Out-Null
function Save([string]$Name, $Lines) { Write-Lines (Join-Path $BK $Name) $Lines }

Save 'packages_all.txt'             (Invoke-Tv 'pm list packages -f' | Sort-Object)
Save 'packages_enabled_before.txt'  (Get-EnabledPackages)
Save 'packages_disabled_before.txt' (Invoke-Tv 'pm list packages -d' | ForEach-Object { $_ -replace '^package:', '' } | Sort-Object)
foreach ($ns in 'system', 'secure', 'global') { Save "settings_$ns.txt" (Invoke-Tv "settings list $ns") }
Save 'screensaver_before.txt' (Invoke-Tv 'settings get secure screensaver_components')
Save 'default_home.txt' (Invoke-Tv 'cmd package resolve-activity --brief -c android.intent.category.HOME -a android.intent.action.MAIN | tail -n 1')
$anim = foreach ($s in 'window_animation_scale', 'transition_animation_scale', 'animator_duration_scale') {
    "$s=" + (Invoke-Tv "settings get global $s" | Select-Object -Last 1)
}
Save 'animations_before.txt' $anim
Save 'getprop.txt' (Invoke-Tv 'getprop')

Write-Lines (Join-Path $KitDir '.dernier-backup') $BK
# La toute première sauvegarde est celle de la télé d'origine : restore.ps1 s'en sert par défaut.
$first = Join-Path $KitDir '.premier-backup'
if (-not (Test-Path -LiteralPath $first)) { Write-Lines $first $BK }
Write-Host "Sauvegarde dans : $BK"
Write-Host "Garde ce dossier : restore.ps1 en a besoin. Il contient des infos propres à ta télé, ne le publie pas."
