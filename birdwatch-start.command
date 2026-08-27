#!/usr/bin/env bash
# Double-click this file (Finder) or run it from Terminal to start the BirdWatchAI server.
# Wraps `docker compose up -d` and leaves the Terminal window open so you can read the result.
cd "$(dirname "$0")"
echo "Starting BirdWatchAI…"
docker compose up -d
echo
echo "Done. Dashboard at http://localhost:8080"
read -n 1 -s -r -p "Press any key to close…"
echo
