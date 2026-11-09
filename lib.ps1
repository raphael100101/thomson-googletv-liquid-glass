# Fonctions communes, chargées par les autres scripts avec : . "$PSScriptRoot\lib.ps1"
# Compatible Windows PowerShell 5.1 (fourni avec Windows) et PowerShell 7.
$ErrorActionPreference = 'Stop'
# Envoie de l'UTF-8 sans BOM aux programmes externes (sinon la 1re commande est corrompue).
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$UpstreamUrl    = 'https://github.com/Gathin23/cleanyourtv'
$UpstreamCommit = '6e8615eb0be0e843ceeebedae246d69f3e0a88d7'   # version testée avec ce kit
$LauncherPkg    = 'com.gathin.tvhome'
$StockLauncher  = 'com.google.android.apps.tv.launcherx'       # accueil Google TV d'origine
$StockHome      = "$StockLauncher/.home.HomeActivity"
$KitDir   = $PSScriptRoot
$Upstream = Join-Path $KitDir 'cleanyourtv'
$Py       = Join-Path $Upstream 'tools\venv\Scripts\python.exe'
$TvPy     = Join-Path $Upstream 'tools\tv.py'

function Set-TvIp([string]$Ip) {
    if (-not $Ip) {
        throw "Il manque l'adresse IP de la télé (Réglages > Réseau et Internet > ton Wi-Fi). Exemple : .\setup.ps1 -TvIp 192.168.1.50"
    }
    if ($Ip -notmatch '^\d{1,3}(\.\d{1,3}){3}(:\d+)?$') { throw "Adresse IP invalide : $Ip (format attendu : 192.168.1.50)" }
    $env:TV_HOST = $Ip
}

function Assert-Venv {
    if (-not (Test-Path -LiteralPath $Py)) { throw "Les outils ne sont pas encore installés : lance d'abord .\setup.ps1" }
}

# Lance une commande shell sur la télé et renvoie ses lignes. Pas de guillemets doubles dans $Cmd :
# Windows PowerShell 5.1 les retire des arguments passés aux programmes externes.
function Invoke-Tv([string]$Cmd) {
    $out = & $Py -I $TvPy $Cmd
    if ($LASTEXITCODE -ne 0) { throw "Échec de la commande sur la télé : $Cmd" }
    @($out | ForEach-Object { "$_".TrimEnd("`r") })
}

function Connect-Tv {
    $ErrorActionPreference = 'Continue'   # stderr d'un programme externe ne doit pas tout arrêter
    $probe = & $Py -I $TvPy --probe 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host ($probe -join "`n")
        throw "Connexion impossible à $env:TV_HOST. Vérifie : télé allumée, même réseau que le PC, Options pour les développeurs > Débogage USB activé, puis accepte la fenêtre « Autoriser le débogage » sur la télé (coche « Toujours autoriser ») et relance."
    }
    ($probe | ForEach-Object { "$_" }) -join ' '
}

# Question oui/non ; -Oui sur setup.ps1 répond oui à tout.
function Confirm-Step([string]$Question) {
    if ($global:KitAssumeYes) { return $true }
    $r = Read-Host "$Question [o/N]"
    return ($r -match '^[oOyY]')
}

function Write-Lines([string]$Path, $Lines) {
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($Path, [string[]]@($Lines), $enc)
}

function Read-PackageList([string]$Path) {
    @(Get-Content -LiteralPath $Path | ForEach-Object { ($_ -replace '#.*$', '').Trim() } |
        Where-Object { $_ } | ForEach-Object { ($_ -split '\s+')[0] })
}

function Get-EnabledPackages {
    @(Invoke-Tv 'pm list packages -e' | ForEach-Object { $_ -replace '^package:', '' } | Where-Object { $_ } | Sort-Object)
}
