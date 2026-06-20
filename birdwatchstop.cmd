@echo off
REM Stop BirdWatchAI Server. Equivalent to `docker compose stop` — containers stay
REM defined (no data loss) so birdwatch-start.cmd starts them again instantly.
cd /d "%~dp0"
docker compose stop
echo.
echo BirdWatchAI is stopped.
pause
