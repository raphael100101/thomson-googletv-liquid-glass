# Remet la télé comme avant : apps réactivées, accueil Google TV d'origine, thème et lanceur retirés,
# animations et écran de veille d'origine.
# Usage : .\restore.ps1 -TvIp 192.168.1.50 [-Sauvegarde backup-...]
#   Par défaut, les réglages d'origine viennent de la toute première sauvegarde (.premier-backup).
param(
    [Parameter(Position = 0)][string]$TvIp,
    [string]$Sauvegarde = ''
)
. "$PSScriptRoot\lib.ps1"
Set-TvIp $TvIp; Assert-Venv
Write-Host "Connecté : $(Connect-Tv)"

if (-not $Sauvegarde) {
    $first = Join-Path $KitDir '.premier-backup'
    if (Test-Path -LiteralPath $first) { $Sauvegarde = (Get-Content -LiteralPath $first | Select-Object -First 1).Trim() }
}
if (-not $Sauvegarde -or -not (Test-Path -LiteralPath $Sauvegarde)) {
    throw "Dossier de sauvegarde introuvable. Donne-le : .\restore.ps1 -TvIp $TvIp -Sauvegarde backup-..."
}
Write-Host "Réglages d'origine lus dans : $Sauvegarde"
function Get-Saved([string]$Name) {
    $p = Join-Path $Sauvegarde $Name
    if (Test-Path -LiteralPath $p) { @(Get-Content -LiteralPath $p | Where-Object { $_ -match '\S' }) } else { @() }
}

# 1. Thème
$theme = Join-Path $Upstream 'tools\theme.ps1'
if (Test-Path -LiteralPath $theme) {
    Push-Location
    try { & $theme -Reset -TvHost $TvIp } catch { Write-Warning "Thème non retiré : $_" } finally { Pop-Location }
}

# 2. Apps désactivées par ce kit (toutes les sauvegardes de cette télé, au cas où setup a tourné plusieurs fois)
$pkgs = @(Get-ChildItem -Path $KitDir -Directory -Filter ('backup-' + ($TvIp -replace '[.:]', '-') + '-*') |
    ForEach-Object { Join-Path $_.FullName 'disabled_by_us.txt' } | Where-Object { Test-Path -LiteralPath $_ } |
    ForEach-Object { Read-PackageList $_ } | Sort-Object -Unique)
foreach ($p in $pkgs) {
    Write-Host "réactive $p"
    try { Invoke-Tv "pm enable --user 0 $p" | Out-Null } catch { Write-Warning $_ }
}

# 3. Accueil d'origine, puis retrait du lanceur
$home0 = Get-Saved 'default_home.txt' | Select-Object -Last 1
if (-not $home0 -or $home0 -notmatch '/' -or $home0 -like "$LauncherPkg/*") { $home0 = $StockHome }
$stockPkg = $home0.Split('/')[0]
Invoke-Tv "pm enable --user 0 $stockPkg" | Out-Null
Invoke-Tv "cmd package set-home-activity --user 0 $home0" | Out-Null
try { Invoke-Tv "pm uninstall --user 0 $LauncherPkg" | Out-Null; Write-Host 'lanceur retiré' } catch { Write-Warning $_ }

# 4. Animations et écran de veille d'origine
$anim = Get-Saved 'animations_before.txt'
if (-not $anim.Count) { $anim = @('window_animation_scale=null', 'transition_animation_scale=null', 'animator_duration_scale=null') }
foreach ($line in $anim) {
    $name, $value = $line.Split('=', 2)
    if ($value -and $value -ne 'null') { Invoke-Tv "settings put global $name $value" | Out-Null }
    else { Invoke-Tv "settings delete global $name" | Out-Null }
}
$ss = Get-Saved 'screensaver_before.txt' | Select-Object -Last 1
if ($ss -and $ss -ne 'null') { Invoke-Tv "settings put secure screensaver_components $ss" | Out-Null }
else { Invoke-Tv 'settings delete secure screensaver_components' | Out-Null }

Write-Host 'Terminé. Redémarre la télé (Réglages > Système > Redémarrer).'
Write-Host 'Avant une revente, fais aussi une réinitialisation d''usine (Réglages > Système > À propos > Réinitialiser).'
