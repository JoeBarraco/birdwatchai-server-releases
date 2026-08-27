#!/usr/bin/env bash
# Pull the latest BirdWatchAI image and recreate the container.
# This is the same thing the dashboard's "Apply update" button does — provided for users who'd
# rather drive the upgrade from the shell.
cd "$(dirname "$0")"
echo "Pulling latest image…"
docker compose pull
echo
echo "Recreating container…"
docker compose up -d --force-recreate birdwatch
echo
echo "Done. Tail the logs to confirm a clean startup:"
echo "  docker logs -f birdwatch"
read -n 1 -s -r -p "Press any key to close…"
echo
