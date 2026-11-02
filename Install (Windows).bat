@echo off
rem Installs Anim Layers into DaVinci Resolve's Fusion folder for the current user.
setlocal
set "DEST=%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion"

if /I "%~1"=="uninstall" goto uninstall

echo Installing Anim Layers to:
echo   %DEST%
robocopy "%~dp0Fusion" "%DEST%" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
	echo.
	echo Install failed. Copy the "Fusion" folder into the path above by hand.
	pause
	exit /b 1
)
echo.
echo Done. Restart DaVinci Resolve, then press L in the Fusion Nodes panel.
pause
exit /b 0

:uninstall
del /Q "%DEST%\Config\AnimLayers.fu" "%DEST%\Modules\Lua\animlayers.lua" 2>nul
rmdir /S /Q "%DEST%\Scripts\Comp\Anim Layers" 2>nul
echo Anim Layers removed. Restart DaVinci Resolve.
pause
exit /b 0
