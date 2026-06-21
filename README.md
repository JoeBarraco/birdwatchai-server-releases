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

You'll also need a camera. Two supported types:

- **RTSP / IP camera** (TP-Link Tapo, Reolink, Amcrest, etc.). What most installs use.
  The setup wizard asks for the RTSP URL.
- **Wired Raspberry Pi camera** (Raspberry Pi Camera Module, Arducam, etc., attached
  over the CSI ribbon cable). See "Using a Pi camera" below.

Optionally, a ZIP code for weather correlation. The setup wizard walks through that.

## Using a Pi camera (CSI ribbon cable)

The dashboard supports a wired Arducam / Raspberry Pi Camera Module attached over the
CSI ribbon cable, as an alternative to RTSP. Capture goes through libcamera (the
modern Pi camera stack), not legacy v4l2 — so the container needs a broader set of
device passthroughs than a USB webcam would. One-time setup:

1. **Plug the ribbon cable in with the Pi powered off.** Lift the CSI port's clip,
   slide the ribbon in (contacts toward the HDMI port on Pi 4 / 5), press the clip
   back down.
2. **Enable the camera interface on the Pi.** On Pi OS Bookworm, `sudo raspi-config`
   → Interface Options → Camera → Yes → Finish → reboot. (No-op on most fresh installs:
   libcamera + v4l2 compat are enabled by default.)
3. **Verify the OS sees it.** SSH in and run `libcamera-hello --list-cameras` — you
   should see at least one camera listed (e.g. `imx519` for an Arducam motorized-lens
   module, `imx708` for the Camera Module 3). If "No cameras available!", go back to
   the ribbon-cable seat — that's the most common cause.
4. **Edit `~/birdwatch/docker-compose.yml`** to expose the camera into the container.
   The file ships with the relevant lines commented out at the bottom of the
   `birdwatch:` service. Uncomment (a) the single line to add to `volumes:`
   (`- /run/udev:/run/udev:ro`), (b) the whole `devices:` block, and (c) the whole
   `group_add:` block.
5. **Recreate the container** with the new mounts:
   ```bash
   cd ~/birdwatch
   docker compose up -d
   ```
6. **Switch the camera type in the dashboard.** Open `http://<your-host>:8080` →
   Settings → Camera → set "Camera type" to **Pi camera** → leave the device path at
   `0` (libcamera's camera index; the field also accepts `/dev/video0` for
   compatibility) → click **Test camera**. A frame should come back within a few
   seconds. **Save**.

If Test camera errors out, the most useful diagnostic is:

```bash
docker exec birdwatch libcamera-hello --list-cameras
```

Run inside the container — if it doesn't see the camera, the devices/udev mounts
aren't right. Compare the dashboard logs (`docker logs birdwatch --tail 30`) against
what rpicam-still reports for hints.

The existing motion + identify pipeline runs on the Pi camera feed the same as on
RTSP — frame-diff motion detection is the default trigger (Settings → Detection →
Motion detection threshold). ONVIF doesn't apply to wired cameras.

## Releases

See the [Releases tab](../../releases) for changelogs. The dashboard polls
this repo's GitHub Releases API every 30 min and surfaces an **Update
available** prompt when a newer version is published.

## Reporting issues

The product site lives at <https://www.birdwatchai.com>. For
operational issues, open an issue on this repo — please include the output
of `docker logs --tail 200 birdwatch` and the contents of
`data/config.json` (with any API keys / passwords redacted).
