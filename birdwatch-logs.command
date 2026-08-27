#!/usr/bin/env bash
# Live log tail for the BirdWatchAI container. Ctrl+C to stop tailing (the container keeps
# running). Useful when you want to watch startup, debug a "what's it doing right now?" question,
# or see why an upgrade went sideways.
cd "$(dirname "$0")"
docker logs -f birdwatch
