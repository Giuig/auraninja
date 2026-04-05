@echo off
setlocal enabledelayedexpansion

echo ============================================
echo Auraninja Audio Pipeline
echo ============================================
echo.
echo Select mode:
echo   [1] Full Pipeline (normalize + optimize)
echo   [2] Normalize only (loudness -16 LUFS)
echo   [3] Optimize only (compress)
echo   [4] Dry run (preview)
echo   [Q] Quit
echo.
set /p choice="Enter choice: "

if /i "%choice%"=="1" (
    python "%~dp0audio_pipeline.py" --mode full
) else if /i "%choice%"=="2" (
    python "%~dp0audio_pipeline.py" --mode normalize
) else if /i "%choice%"=="3" (
    python "%~dp0audio_pipeline.py" --mode optimize
) else if /i "%choice%"=="4" (
    python "%~dp0audio_pipeline.py" --dry-run
) else if /i "%choice%"=="Q" (
    exit /b 0
) else (
    echo Invalid choice.
    timeout /t 2 >nul
    exit /b 1
)

echo.
echo ============================================
echo Done!
pause
