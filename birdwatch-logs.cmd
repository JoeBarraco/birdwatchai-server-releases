@echo off
REM Live log tail for the BirdWatchAI container. Ctrl+C to stop tailing — the
REM container keeps running. Useful for watching the engine pick up motion,
REM identify birds, send notifications, etc. in real time.
cd /d "%~dp0"
docker compose logs -f birdwatch
