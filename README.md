# BirdWatchAI Server

Public installer + release feed for **BirdWatchAI Server** — the bird-feeder
camera that identifies species on-device and lets you watch your backyard
from anywhere. Source code lives in a private repository; this repo ships
release tags, install instructions, and a ready-to-go `docker-compose.yml`.

The server is one Docker image (~600 MB, multi-arch — Raspberry Pi 4/5 and
x86 Linux both work). Once it's running you'll have a web dashboard at
`http://<your-host>:8080` with a first-time setup wizard.

## Quick start

> **New to Docker?** Use one of the platform-specific walkthroughs instead —
> they cover everything from a bare machine to a running dashboard in a
> single linear flow:
>
> - [**Raspberry Pi (bare SD card)**](PISETUP.md)
> - [**Windows 10 / 11 (Docker Desktop)**](WINDOWS-SETUP.md)
>
> The Quick Start below assumes you already have Docker installed.

### 1. Install Docker (skip if you already have it)

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in so the docker permission applies.
```

### 2. Get this repo and start the server

```bash
git clone https://github.com/JoeBarraco/birdwatchai-server-releases.git ~/birdwatch
cd ~/birdwatch
docker compose up -d
```

The compose file pulls
`ghcr.io/joebarraco/birdwatchai-server:latest`, mounts a local `data/`
folder for the database + config, and binds to host port 8080.

### 3. Open the dashboard

```
http://<your-host-ip>:8080
```

Follow the setup wizard to point at your camera, set your location, and
configure notifications. Your detection history + config persist in
`~/birdwatch/data/` — back that folder up if you care about it.

## Updating

Two paths — both end up at the same place.

### One-click from the dashboard (recommended)

When a newer release is published, the **⬆ Update available** button
appears in the Engine status card. Click it → review the release notes
in the modal → click **Apply update**. The Watchtower sidecar (included
in `docker-compose.yml`) pulls the new image, recreates the container,
and the page reloads on the new version in ~90 seconds.

This requires that you started the stack with the included
`docker-compose.yml` — it wires the `birdwatch` and `watchtower` services
together with a shared token. Older installs that predate this file
won't have the watchtower container; the modal will say so and the
Apply button will stay disabled. Update the manual way (below) once,
re-pull this repo, and the auto-apply path lights up.

### Manually from the shell

```bash
cd ~/birdwatch
docker compose pull
docker compose up -d
```

Pulls the latest image and recreates the container. Your `data/`
folder is untouched.

## Useful day-to-day commands

```bash
docker logs -f birdwatch       # live log tail (Ctrl+C to stop tailing)
docker restart birdwatch       # bounce the container without rebuilding
docker stop birdwatch          # stop
docker start birdwatch         # start
```

## Hardware

Tested on:
- Raspberry Pi 4 / 5 (4 GB+, Raspberry Pi OS Lite 64-bit)
- Any x86_64 Linux box with Docker

You'll also need an RTSP-capable camera (Tapo, Reolink, etc.) and optionally
a ZIP code for weather correlation. The setup wizard walks through both.

## Releases

See the [Releases tab](../../releases) for changelogs. The dashboard polls
this repo's GitHub Releases API every 30 min and surfaces an **Update
available** prompt when a newer version is published.

## Reporting issues

The product site lives at <https://www.birdwatchai.com>. For
operational issues, open an issue on this repo — please include the output
of `docker logs --tail 200 birdwatch` and the contents of
`data/config.json` (with any API keys / passwords redacted).
