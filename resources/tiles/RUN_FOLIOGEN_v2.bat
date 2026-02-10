@echo off
setlocal
cd /d "%~dp0"

REM Lancia lo script singolo (genera card.txt + renderizza)
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0BuildFolioPreviews_SINGLE_v2.ps1" -Count 30
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0BuildFolioPreviews_SINGLE_v2.ps1" -Count 30
)

echo.
echo Fatto. Premi un tasto per chiudere.
pause >nul
