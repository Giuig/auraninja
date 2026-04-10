@echo off
echo ============================================
echo Auraninja Audio Pipeline
echo ============================================
echo.
echo Running normalization...
echo.
python "%~dp0audio_pipeline.py" --mode normalize
echo.
echo ============================================
echo Done! Press any key to exit...
pause >nul
