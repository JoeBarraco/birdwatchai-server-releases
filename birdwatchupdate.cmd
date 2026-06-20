@echo off
REM Manually pull + restart BirdWatchAI. You usually won't need this — the dashboard's
REM "Apply update" button (Engine status card) does the same thing with no SSH/cmd.
REM This script is here for the case where the dashboard is unreachable or you'd just
REM rather drive from the shell.
cd /d "%~dp0"
echo Pulling latest image from GitHub Container Registry...
docker compose pull
if errorlevel 1 (
    echo.
    echo Pull failed. Is Docker Desktop running? Is the GHCR package still public?
    pause
    exit /b 1
)
echo.
echo Recreating containers...
docker compose up -d
if errorlevel 1 (
    echo.
    echo Recreate failed. Check the Docker Desktop UI for details.
    pause
    exit /b 1
)
echo.
echo Update complete. Refresh http://localhost:8080.
pause
