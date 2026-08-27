#!/usr/bin/env bash
# Double-click this file (Finder) or run it from Terminal to stop the BirdWatchAI server.
# Wraps `docker compose stop` — containers remain defined, just stopped, so the next
# birdwatch-start.command brings them right back without re-downloading anything.
cd "$(dirname "$0")"
echo "Stopping BirdWatchAI…"
docker compose stop
echo "Done."
read -n 1 -s -r -p "Press any key to close…"
echo
