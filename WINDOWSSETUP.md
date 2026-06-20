# BirdWatchAI Server — Windows setup

Linear walkthrough from a fresh Windows 10/11 machine to a running BirdWatchAI
install. Companion to [PISETUP.md](PISETUP.md) for Raspberry Pi installs.

Total time: ~30–45 minutes, mostly waiting for Docker Desktop to download.

## What you need

**Hardware**
- Windows 10 64-bit (build 1903+) or Windows 11
- 8 GB RAM minimum, 16 GB recommended (Docker Desktop is RAM-hungry)
- 20 GB free disk space (Docker image + WSL2 storage)
- Wired Ethernet recommended for reliability — Wi-Fi works fine but is the
  most common source of "weird intermittent issues" reports
- An RTSP-capable IP camera (TP-Link Tapo, Reolink, Amcrest, etc.). The
  wired Pi camera path doesn't apply on Windows.

**Software** (install in steps 1–2)
- Docker Desktop for Windows
- Git for Windows (optional but recommended — needed for the
  `git pull` update path)

## 1. Install Docker Desktop

1. Download from <https://www.docker.com/products/docker-desktop/>.
2. Run the installer. Accept defaults — **Use WSL 2 based engine** must be
   checked (it's the default on Windows 10 2004+ and Windows 11).
3. Restart Windows when prompted.
4. After login, Docker Desktop should auto-launch (whale icon in the system
   tray). First launch takes 1–2 minutes to bring the engine up.
5. Open **Docker Desktop → Settings → General** and verify:
   - ☑ **Start Docker Desktop when you sign in.** This is what makes the
     BirdWatch stack come back automatically after a reboot.
   - ☑ **Use the WSL 2 based engine.**
6. Skip the optional sign-in / tutorial / sponsorship pages.

## 2. Install Git for Windows (recommended)

Download from <https://git-scm.com/download/win> and accept all defaults.

If you'd rather not install Git, you can download the BirdWatchAI release
repo as a ZIP from
<https://github.com/JoeBarraco/birdwatchai-server-releases/archive/refs/heads/main.zip>
and extract it to e.g. `C:\Users\<you>\BirdWatch\`. The trade-off: you'll
have to re-download the zip when the `docker-compose.yml` changes (every
few months, when the install contract evolves).

## 3. Get the BirdWatchAI release repo

Open **PowerShell** or **Command Prompt** and run:

```cmd
cd %USERPROFILE%
git clone https://github.com/JoeBarraco/birdwatchai-server-releases.git BirdWatch
cd BirdWatch
```

(If you used the ZIP route, just `cd` to wherever you extracted it.)

## 4. Start the stack

```cmd
docker compose up -d
```

First run downloads the ~600 MB BirdWatchAI image and the small Watchtower
image. Expect 1–5 minutes on typical home internet. When the prompt returns:

```cmd
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
  rather than `stream1` (2K) — 2K saturates the camera's uplink.
- **Location** — ZIP code (used for outdoor temperature on each detection).
- **Notifications** — optional email + ntfy push.
- **License** — optional; a 30-day trial starts automatically.

## 6. Verify auto-start on boot

The default setup brings everything back without you doing anything:
- **Docker Desktop**: auto-starts via the "Start when I sign in" setting
  from step 1.5.
- **BirdWatch + Watchtower containers**: have `restart: unless-stopped` in
  the compose file, so they come up as soon as Docker is ready.

To test: reboot Windows, log back in, wait ~30 seconds for Docker to start,
open `http://localhost:8080`. You should land on the dashboard.

## Daily-ops helper scripts

The repo ships a few `.cmd` files at the root that wrap the common
`docker compose` operations. Double-click any of them or run from a shell.

| Script | What it does |
|---|---|
| `birdwatch-start.cmd` | `docker compose up -d` |
| `birdwatch-stop.cmd` | `docker compose stop` (containers stay defined, just stopped) |
| `birdwatch-update.cmd` | `docker compose pull && docker compose up -d` — manual update path. You usually won't need this; the dashboard's **⬆ Update available** button does the same thing one-click. |
| `birdwatch-logs.cmd` | Live log tail. `Ctrl+C` to stop tailing (container keeps running). |

## Updating

Two paths — same as on the Pi:

**One-click from the dashboard** (recommended): open
`http://localhost:8080` → wait for the ⬆ Update available button to appear
in the Engine status card (within 30 min of a new release being published)
→ click it → review the notes in the modal → click **Apply update**. The
Watchtower sidecar pulls the new image and recreates the container in
~90 seconds; the page reloads on the new version automatically.

**Manually from the shell** (or `birdwatch-update.cmd`):

```cmd
cd %USERPROFILE%\BirdWatch
docker compose pull
docker compose up -d
```

## Optional: a Scheduled Task for extra-reliable startup

The default Docker Desktop + `restart: unless-stopped` flow above is enough
for most installs. Add a Scheduled Task if you want belt-and-suspenders —
something that polls for Docker to become ready and re-runs
`docker compose up -d` if for any reason the auto-restart didn't fire.

Open PowerShell **as Administrator** and run, from the `%USERPROFILE%\BirdWatch`
folder:

```powershell
.\setup-scheduled-task.ps1
```

That script registers a task named **BirdWatchAI Server Autostart** that
runs `birdwatch-start.cmd` at user login, after waiting up to 5 minutes
for Docker Desktop to come up. Idempotent — running it again just updates
the existing task.

To remove the task later:

```powershell
Unregister-ScheduledTask -TaskName "BirdWatchAI Server Autostart" -Confirm:$false
```

## Hands-off mode (no Windows login required)

Docker Desktop requires a logged-in Windows session — the engine doesn't
run as a system service. If you want truly headless operation (Windows
boots, no one logs in, BirdWatch is up):

1. **Auto-login**: configure Windows to auto-log into a dedicated account
   at boot (`netplwiz` → uncheck "Users must enter a username and
   password..."). Docker Desktop's "Start when I sign in" then handles the
   rest. Trade-off: anyone with physical access has that account's
   permissions. Acceptable for a dedicated homelab box, not a shared PC.

2. **Docker without Docker Desktop**: install the Docker engine directly
   on WSL2 (or in Windows Server containers mode). Much more involved and
   out of scope here. Search "Docker on WSL2 without Docker Desktop".

For a dedicated Pi or x86 Linux host, headless is the default — that's why
[PISETUP.md](PISETUP.md) is so much shorter on this point.

## Useful day-to-day commands

```cmd
docker logs -f birdwatch              :: live log tail
docker restart birdwatch              :: bounce just the BirdWatch container
docker stop birdwatch                 :: stop
docker start birdwatch                :: start
docker compose down                   :: stop both containers (BirdWatch + Watchtower)
docker compose up -d                  :: start both
docker stats                          :: live CPU / RAM / network per container
```

## If something didn't work

| Symptom | What to try |
|---|---|
| Docker Desktop installer says "WSL 2 installation incomplete" | Open PowerShell as Admin → `wsl --install` → reboot → re-run the Docker Desktop installer. |
| `docker compose up -d` fails with `Cannot connect to the Docker daemon` | Docker Desktop isn't running. Open it from the Start menu and wait for the whale icon to settle. |
| `denied: requires authentication` on `docker compose up` | The GHCR package isn't public yet — tell Joe. |
| Dashboard returns "site can't be reached" | `docker ps` — is `birdwatch` listed with status `Up`? If `Restarting`, `docker logs birdwatch` shows why. |
| Detection timestamps wrong by several hours | Docker Desktop on Windows runs containers in a Linux VM that uses its own timezone. The compose file's `TZ` env var picks up `${TZ}` from your environment — set it explicitly: edit `docker-compose.yml` and replace `${TZ:-UTC}` with e.g. `America/New_York`, then `docker compose up -d`. |
| Camera shows "disconnected" in the dashboard | Wrong RTSP URL, wrong credentials, or your camera blocks the connection from this PC. Try the URL in VLC first to confirm. |

For anything else, open an issue on this repo with the output of
`docker logs --tail 200 birdwatch` and a brief description of what you
tried.
