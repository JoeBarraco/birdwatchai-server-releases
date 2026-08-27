# BirdWatchAI Server — macOS setup

Linear walkthrough from a fresh macOS machine to a running BirdWatchAI
install. Companion to [PISETUP.md](PISETUP.md) (Raspberry Pi) and
[WINDOWS-SETUP.md](WINDOWS-SETUP.md).

Total time: ~20–30 minutes, mostly waiting for Docker Desktop to download.

## What you need

**Hardware**
- macOS 12 Monterey or newer (Intel or Apple Silicon — the BirdWatchAI
  image is multi-arch and runs natively on both)
- 8 GB RAM minimum, 16 GB recommended (Docker Desktop is RAM-hungry)
- 20 GB free disk space (Docker image + the embedded Linux VM)
- Wired Ethernet or solid Wi-Fi to your RTSP camera
- An RTSP-capable IP camera (TP-Link Tapo, Reolink, Amcrest, etc.). The
  wired Pi camera path doesn't apply on macOS.

**Software** (install in steps 1–2)
- Docker Desktop for Mac
- Git — preinstalled on most Macs, or comes with Xcode Command Line Tools

## 1. Install Docker Desktop

> **You don't need a Docker account.** The installer and Docker Desktop's
> "sign in / sign up" prompts are optional — skip them. BirdWatchAI's image
> pulls from a public GitHub Container Registry that needs no login.

1. Download the right build from <https://www.docker.com/products/docker-desktop/>:
   - **Apple Silicon** (M1/M2/M3/M4): "Download for Mac — Apple Silicon"
   - **Intel**: "Download for Mac — Intel chip"

   If you're not sure, click the Apple menu → About This Mac. "Chip" reads
   either "Apple M…" or "Intel Core…".
2. Open the downloaded `.dmg`, drag **Docker** to **Applications**, then
   launch it from Launchpad. First launch takes 1–2 minutes — accept the
   privileged-helper prompt when it asks for your password.
3. Open **Docker Desktop → Settings → General** and verify:
   - ☑ **Start Docker Desktop when you log in.** This is what makes the
     BirdWatch stack come back automatically after a reboot.
   - The **Use Rosetta for x86_64/amd64 emulation** toggle (Apple Silicon
     only): leave at its default. The BirdWatchAI image is native arm64,
     so emulation never kicks in.
4. Skip the optional sign-in / tutorial / sponsorship prompts.

## 2. Confirm Git is available

```bash
git --version
```

If it prints a version, you're good. If it offers to install the Command
Line Tools, click **Install** and wait ~5 minutes — that brings in Git
plus a few other Unix utilities.

(If you'd rather not install the CLT, you can download the release repo as
a zip from
<https://github.com/JoeBarraco/birdwatchai-server-releases/archive/refs/heads/main.zip>
and extract it into your home folder. The trade-off: you'll have to
re-download the zip when `docker-compose.yml` changes.)

## 3. Get the BirdWatchAI release repo

Open **Terminal** (Cmd+Space → "Terminal") and run:

```bash
cd ~
git clone https://github.com/JoeBarraco/birdwatchai-server-releases.git BirdWatch
cd BirdWatch
```

(If you used the zip route, just `cd` to wherever you extracted it.)

## 4. Start the stack

```bash
docker compose up -d
```

First run downloads the ~600 MB BirdWatchAI image and the small Watchtower
sidecar image. Expect 1–5 minutes on typical home internet. When the
prompt returns:

```bash
docker ps
```

You should see **two** containers:
- `birdwatch`
- `birdwatch-watchtower`

If you only see one, the compose file is missing the Watchtower sidecar —
re-run `git pull` and `docker compose up -d`.

## 5. Open the dashboard

In your browser:

```
http://localhost:8080
```

The first-time setup wizard greets you. Walk through:
- **Camera** — paste your RTSP URL. For TP-Link Tapo, use `stream2` (720p)
  rather than `stream1` (2K) — 2K saturates the camera's uplink. Newer
  models can do 1080p on stream1; older sub-streams cap at 640×360.
- **Location** — ZIP code (used for outdoor temperature on each detection).
- **Notifications** — optional email + ntfy push.
- **License** — optional; a 30-day trial starts automatically.

## 6. Verify auto-start on reboot

The default setup brings everything back without you doing anything:
- **Docker Desktop**: auto-starts via the "Start when I log in" setting
  from step 1.3.
- **BirdWatch + Watchtower containers**: have `restart: unless-stopped` in
  the compose file, so they come up as soon as Docker is ready.

To test: reboot the Mac, log back in, wait ~30 seconds for Docker to
start, open `http://localhost:8080`. You should land on the dashboard.

## Daily-ops helper scripts

The repo ships a few `.command` files at the root that wrap the common
`docker compose` operations. Double-click any of them in Finder, or run
from a Terminal in the repo folder.

| Script | What it does |
|---|---|
| `birdwatch-start.command` | `docker compose up -d` |
| `birdwatch-stop.command` | `docker compose stop` (containers stay defined, just stopped) |
| `birdwatch-update.command` | `docker compose pull && docker compose up -d` — manual update path. You usually won't need this; the dashboard's **⬆ Update available** button does the same thing one-click. |
| `birdwatch-logs.command` | Live log tail. `Ctrl+C` to stop tailing (container keeps running). |

**First-time only**: macOS Gatekeeper may refuse to run a `.command` file
downloaded from the internet ("…cannot be opened because it is from an
unidentified developer"). Right-click the file → **Open** → **Open**
once, and macOS remembers your approval thereafter. Or `chmod +x
birdwatch-*.command` from Terminal.

## Updating

Two paths — same as on the Pi or Windows:

**One-click from the dashboard** (recommended): open
`http://localhost:8080` → wait for the ⬆ Update available button to appear
in the Engine status card (within 30 min of a new release being published)
→ click it → review the notes in the modal → click **Apply update**. The
Watchtower sidecar pulls the new image and recreates the container in
~90 seconds; the page reloads on the new version automatically.

**Manually from the shell** (or `birdwatch-update.command`):

```bash
cd ~/BirdWatch
docker compose pull
docker compose up -d
```

## Headless considerations

Docker Desktop on macOS requires a logged-in user session — the Linux VM
runs inside the GUI session, not as a system daemon. If you want truly
headless operation (Mac boots, no one logs in, BirdWatch is up):

1. **Auto-login**: System Settings → Users & Groups → **Automatically log
   in as…** → pick the BirdWatch user. Docker Desktop's "Start when I log
   in" then handles the rest. Trade-off: anyone with physical access has
   that account's permissions.

2. **colima** (Docker without Docker Desktop): an open-source
   alternative that can run as a launchd service without a GUI session.
   Much more involved than Docker Desktop and out of scope here — search
   "colima docker macos headless" for the standard recipe.

For a dedicated server-style install, a Raspberry Pi 5 or any spare Linux
box is genuinely simpler. [PISETUP.md](PISETUP.md) walks through that
path soup-to-nuts.

## Useful day-to-day commands

```bash
docker logs -f birdwatch              # live log tail
docker restart birdwatch              # bounce just the BirdWatch container
docker stop birdwatch                 # stop
docker start birdwatch                # start
docker compose down                   # stop both containers (BirdWatch + Watchtower)
docker compose up -d                  # start both
docker stats                          # live CPU / RAM / network per container
```

## If something didn't work

| Symptom | What to try |
|---|---|
| Docker Desktop won't launch ("Docker.app is damaged") | Some Apple Silicon Macs need Rosetta 2 even for Apple-Silicon-native apps. Open Terminal → `softwareupdate --install-rosetta --agree-to-license` → relaunch Docker Desktop. |
| `docker compose up -d` fails with `Cannot connect to the Docker daemon` | Docker Desktop isn't running. Open it from Launchpad and wait for the whale icon (top menu bar) to stop pulsing. |
| `denied: requires authentication` on `docker compose up` | The GHCR package isn't public yet — tell Joe. |
| Dashboard returns "site can't be reached" | `docker ps` — is `birdwatch` listed with status `Up`? If `Restarting`, `docker logs birdwatch` shows why. |
| Detection timestamps wrong by several hours | Docker Desktop on macOS runs containers in a Linux VM. The compose ships with `/etc/localtime` + `/etc/timezone` bind-mounted from the host, but the embedded VM may interpose its own timezone. Confirm with `docker exec birdwatch date` — if it disagrees with your wall clock, set `TZ` explicitly: edit `docker-compose.yml`, add `TZ: America/New_York` (or your zone) under the `birdwatch:` service's `environment:` block, then `docker compose up -d --force-recreate birdwatch`. |
| `.command` file says "cannot be opened because it is from an unidentified developer" | Right-click the file in Finder → **Open** → **Open**. macOS remembers your approval thereafter. Or `chmod +x birdwatch-*.command`. |
| Camera shows "disconnected" in the dashboard | Wrong RTSP URL, wrong credentials, or your camera blocks the connection from this Mac. Try the URL in VLC first to confirm (VLC is free at <https://www.videolan.org/vlc/>). |

For anything else, open an issue on this repo with the output of
`docker logs --tail 200 birdwatch` and a brief description of what you
tried.
