@echo off
rem Double-clique ce fichier pour lister les applis de la tele, sans rien changer.
cd /d "%~dp0"
set /p TVIP=Adresse IP de la tele : 
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -TvIp %TVIP% -OutilsSeulement
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0inventaire.ps1" -TvIp %TVIP%
echo.
pause
