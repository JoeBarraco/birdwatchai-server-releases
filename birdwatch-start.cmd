@echo off
REM Start BirdWatchAI Server. Equivalent to `docker compose up -d` in this folder.
REM Double-click or run from a shell. Re-running is harmless — Docker only recreates
REM containers whose definition changed.
cd /d "%~dp0"
docker compose up -d
if errorlevel 1 (
    echo.
    echo Failed to start. Is Docker Desktop running? Check the whale icon in the system tray.
    pause
    exit /b 1
)
echo.
echo BirdWatchAI is starting. Open http://localhost:8080 in your browser.
pause
