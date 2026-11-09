# Installe sur une Google TV (Thomson 55QG7C14) depuis un PC Windows :
# ménage des apps inutiles + accueil « liquid glass » + thème + écran de veille horloge.
#
# Usage : .\setup.ps1 -TvIp 192.168.1.50 [-Lat 48.85 -Lon 2.35] [-LiveTv <paquet>] [-Oui]
#   -Lat/-Lon : ta ville, pour que le fond change avec le lever/coucher du soleil (sinon 7 h et 18 h 30)
#   -LiveTv   : paquet de l'appli TV en direct, si la détection automatique se trompe
#   -Oui      : répond oui à toutes les questions
#   -OutilsSeulement : installe seulement les outils sur le PC (pour lancer inventaire.ps1), sans toucher à la télé
param(
    [Parameter(Position = 0)][string]$TvIp,
    [string]$Lat = '',
    [string]$Lon = '',
    [string]$LiveTv = '',
    [switch]$Oui,
    [switch]$OutilsSeulement
)
. "$PSScriptRoot\lib.ps1"
$global:KitAssumeYes = [bool]$Oui
Set-TvIp $TvIp
if (($Lat -and $Lat -notmatch '^-?\d+(\.\d+)?$') -or ($Lon -and $Lon -notmatch '^-?\d+(\.\d+)?$')) {
    throw 'Lat et Lon s''écrivent avec un point : -Lat 48.85 -Lon 2.35'
}

function Test-Cmd([string]$Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }
function Install-WithWinget([string]$Id, [string]$What) {
    if (-not (Test-Cmd 'winget')) { throw "$What est introuvable. Installe-le à la main, puis relance." }
    if (-not (Confirm-Step "Installer $What avec winget ?")) { throw "$What est nécessaire." }
    & winget install --id $Id -e --accept-package-agreements --accept-source-agreements
    throw "$What vient d'être installé. Ferme cette fenêtre PowerShell, ouvre-en une nouvelle et relance la même commande."
}
# Lance un script PowerShell du projet d'origine sans changer le dossier courant d'ici.
function Invoke-Upstream([string]$Script, [object[]]$Positional = @(), [hashtable]$Named = @{}) {
    Push-Location
    try {
        $global:LASTEXITCODE = 0
        & (Join-Path $Upstream $Script) @Positional @Named
        if ($LASTEXITCODE -ne 0) { throw "$Script a échoué (code $LASTEXITCODE)" }
    } finally { Pop-Location }
}

Write-Host '== 1/7 Outils sur le PC'
if (-not (Test-Cmd 'git')) { Install-WithWinget 'Git.Git' 'Git' }
$python = $null
if (Test-Cmd 'py') { $python = @('py', '-3') }
elseif (Test-Cmd 'python') {
    $ErrorActionPreference = 'Continue'; & python --version *> $null; $ok = ($LASTEXITCODE -eq 0); $ErrorActionPreference = 'Stop'
    if ($ok) { $python = @('python') }   # sinon c'est le raccourci vers le Microsoft Store
}
if (-not $python) { Install-WithWinget 'Python.Python.3.12' 'Python 3' }
Write-Host '== 2/7 Code du lanceur (projet open source Gathin23/cleanyourtv)'
if (-not (Test-Path -LiteralPath (Join-Path $Upstream '.git'))) {
    & git -c core.autocrlf=false clone -q $UpstreamUrl $Upstream
    if ($LASTEXITCODE -ne 0) { throw 'Téléchargement du lanceur impossible (git clone).' }
}
& git -C $Upstream config core.autocrlf false
& git -C $Upstream checkout -q -- .
& git -C $Upstream fetch -q origin
& git -C $Upstream checkout -q $UpstreamCommit
if ($LASTEXITCODE -ne 0) { throw "Version $UpstreamCommit du lanceur introuvable." }
if (-not (Test-Path -LiteralPath $Py)) {
    $pyExe = $python[0]; $pyArgs = @($python | Select-Object -Skip 1)
    & $pyExe @pyArgs -m venv (Join-Path $Upstream 'tools\venv')
    if ($LASTEXITCODE -ne 0) { throw 'Création de l''environnement Python impossible.' }
}
& $Py -m pip install -q -r (Join-Path $Upstream 'tools\requirements.txt') pillow numpy
if ($LASTEXITCODE -ne 0) { throw 'Installation des modules Python impossible.' }

if ($OutilsSeulement) {
    Write-Host "Outils installés. Tu peux lancer : .\inventaire.ps1 -TvIp $TvIp"
    return
}

# Le lanceur se compile avec le SDK Android (fourni par Android Studio) et Gradle 8.9,
# qui ne tourne qu'avec Java 17 à 22. Les Android Studio récents embarquent Java 25 (refusé par Gradle 8.9) :
# on cherche donc un Java compatible, et on installe Microsoft OpenJDK 21 s'il n'y en a aucun.
function Get-JdkMajor([string]$Dir) {
    if (-not $Dir -or -not (Test-Path -LiteralPath "$Dir\bin\java.exe") -or -not (Test-Path -LiteralPath "$Dir\release")) { return 0 }
    $m = Select-String -LiteralPath "$Dir\release" -Pattern '^JAVA_VERSION="(\d+)' | Select-Object -First 1
    if ($m) { [int]$m.Matches[0].Groups[1].Value } else { 0 }
}
function Find-Jdk {
    $cands = @($env:JAVA_HOME)
    $cands += Get-ChildItem 'C:\Program Files\Android' -Directory -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName 'jbr' }
    foreach ($root in 'C:\Program Files\Microsoft', 'C:\Program Files\Eclipse Adoptium', 'C:\Program Files\Java') {
        $cands += Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
    }
    $cands | Where-Object { $v = Get-JdkMajor $_; $v -ge 17 -and $v -le 22 } | Select-Object -First 1
}
$studio = Get-ChildItem 'C:\Program Files\Android' -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName 'bin') } | Select-Object -First 1
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
if (-not $studio -and -not (Test-Path (Join-Path $sdk 'platforms'))) { Install-WithWinget 'Google.AndroidStudio' 'Android Studio' }
$jdk = Find-Jdk
if (-not $jdk) { Install-WithWinget 'Microsoft.OpenJDK.21' 'Java 21 (le Java d''Android Studio est trop récent pour compiler le lanceur)' }
if (-not (Test-Path (Join-Path $sdk 'platforms'))) {
    throw "Le SDK Android est introuvable ($sdk). Ouvre Android Studio une fois et laisse l'assistant installer le SDK (choix « Standard », accepte les licences), puis relance."
}

Write-Host '== 3/7 Connexion et sauvegarde'
Write-Host "Connecté : $(Connect-Tv)"
& (Join-Path $KitDir 'backup.ps1') -TvIp $TvIp
$BK = (Get-Content -LiteralPath (Join-Path $KitDir '.dernier-backup') | Select-Object -First 1).Trim()
$enabled = Get-Content -LiteralPath (Join-Path $BK 'packages_enabled_before.txt')

Write-Host '== 4/7 Désactivation des apps inutiles (réversible)'
$wanted = Read-PackageList (Join-Path $KitDir 'debloat-thomson.txt')
$todo = @($wanted | Where-Object { $enabled -contains $_ })
$skip = @($wanted | Where-Object { $enabled -notcontains $_ })
if ($skip.Count) { Write-Host "Absentes de cette télé ou déjà désactivées (ignorées) : $($skip.Count)" }
if ($todo.Count -eq 0) { Write-Host 'Rien à désactiver.' }
else {
    Write-Host 'Apps qui seront désactivées :'; $todo | ForEach-Object { Write-Host "  - $_" }
    if (Confirm-Step 'Continuer ?') {
        $list = Join-Path $BK 'a-desactiver.txt'
        Write-Lines $list $todo
        try { Invoke-Upstream 'tools\disable.ps1' @($list) @{ TvHost = $TvIp } }
        finally {
            # Noté même en cas d'erreur, pour que restore.ps1 sache quoi réactiver.
            $now = Get-EnabledPackages
            Write-Lines (Join-Path $BK 'disabled_by_us.txt') @($todo | Where-Object { $now -notcontains $_ })
        }
    }
}

Write-Host '== 5/7 Lanceur'
$cfgPath = Join-Path $Upstream 'launcher\app\src\main\res\values\config.xml'
$xml = [System.IO.File]::ReadAllText($cfgPath)
$theme = Get-Content -Raw -LiteralPath (Join-Path $KitDir 'theme\config.json') | ConvertFrom-Json
$items = ($theme.dock_apps | ForEach-Object { "`n        <item>$_</item>" }) -join ''
$xml = [regex]::Replace($xml, '(?s)(<string-array name="dock_apps">).*?(</string-array>)', { param($m) $m.Groups[1].Value + $items + "`n    " + $m.Groups[2].Value })
if (-not $LiveTv) {
    # Appli « TV en direct » : la première de cette liste présente sur la télé.
    # com.realtek.tv : Thomson 55QG7C14 (puce Realtek).
    $LiveTv = @('com.mediatek.wwtv.tvcenter', 'com.tcl.tv', 'com.realtek.tv', 'com.google.android.tv', 'com.droidlogic.tvsource') |
        Where-Object { $enabled -contains $_ } | Select-Object -First 1
}
if ($LiveTv) {
    Write-Host "Appli TV en direct : $LiveTv"
    $xml = $xml -replace '(<string name="live_tv_package" translatable="false">).*?(</string>)', "`${1}$LiveTv`${2}"
} else { Write-Warning 'Appli TV en direct non trouvée : le bouton TV du lanceur garde son réglage par défaut (option -LiveTv).' }
if ($Lat -and $Lon) {
    $xml = $xml -replace '(<string name="latitude" translatable="false">).*?(</string>)', "`${1}$Lat`${2}"
    $xml = $xml -replace '(<string name="longitude" translatable="false">).*?(</string>)', "`${1}$Lon`${2}"
}
[System.IO.File]::WriteAllText($cfgPath, $xml, (New-Object System.Text.UTF8Encoding $false))
$gw = Join-Path $Upstream 'launcher\gradle\wrapper\gradle-wrapper.properties'
$props = (Get-Content -LiteralPath $gw) -replace 'networkTimeout=\d+', 'networkTimeout=180000'
Write-Lines $gw $props
& git -C $Upstream apply (Join-Path $KitDir 'patches\horloge-centree.patch')
if ($LASTEXITCODE -ne 0) { throw 'Le correctif « horloge centrée » ne s''applique pas.' }
$env:JAVA_HOME = $jdk
$env:ANDROID_HOME = $sdk
if (Confirm-Step 'Compiler et installer le lanceur (quelques minutes la première fois) ?') {
    Invoke-Upstream 'launcher\build-and-install.ps1' @() @{ TvHost = $TvIp }
    Write-Lines (Join-Path $BK 'launcher_installed.txt') $LauncherPkg
}

if ((Invoke-Tv "pm list packages $LauncherPkg") -notcontains "package:$LauncherPkg") {
    Write-Host 'Le lanceur n''est pas installé : thème et écran de veille ignorés. Relance setup.ps1 pour l''installer.'
    return
}

Write-Host '== 6/7 Thème et fonds d''écran'
$ready = Join-Path $KitDir 'theme-pret'
if (Test-Path -LiteralPath $ready) { Remove-Item -Recurse -Force -LiteralPath $ready }
New-Item -ItemType Directory -Force -Path (Join-Path $ready 'wallpapers') | Out-Null
Copy-Item -LiteralPath (Join-Path $KitDir 'theme\config.json') -Destination $ready
$own = @(Get-ChildItem -Path (Join-Path $KitDir 'theme\wallpapers') -Filter '*.jpg' -ErrorAction SilentlyContinue)
if ($own.Count) { $own | Copy-Item -Destination (Join-Path $ready 'wallpapers') }
else {
    & $Py -I (Join-Path $KitDir 'make_wallpapers.py') (Join-Path $ready 'wallpapers')
    if ($LASTEXITCODE -ne 0) { throw 'Création des fonds d''écran impossible.' }
}
Invoke-Upstream 'tools\theme.ps1' @($ready) @{ TvHost = $TvIp }

Write-Host '== 7/7 Écran de veille (horloge sur le fond) et animations'
Invoke-Tv "settings put secure screensaver_components $LauncherPkg/$LauncherPkg.ClockDream" | Out-Null
foreach ($s in 'window_animation_scale', 'transition_animation_scale', 'animator_duration_scale') {
    Invoke-Tv "settings put global $s 0.5" | Out-Null
}
Invoke-Tv 'input keyevent KEYCODE_HOME' | Out-Null
Write-Host ''
Write-Host "Terminé. Pour tout remettre comme avant : .\restore.ps1 -TvIp $TvIp"
Write-Host 'Pense à désactiver le débogage USB sur la télé (Options pour les développeurs).'
