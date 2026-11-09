@echo off
rem Double-clique ce fichier pour installer le kit sur la tele (Windows).
cd /d "%~dp0"
set /p TVIP=Adresse IP de la tele (Parametres ^> Reseau et Internet ^> ton Wi-Fi) : 
rem -Lat / -Lon : Paris. Remplace par ta ville si besoin.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -TvIp %TVIP% -Lat 48.85 -Lon 2.35
echo.
pause
