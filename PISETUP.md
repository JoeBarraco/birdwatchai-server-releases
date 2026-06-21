# Raspberry Pi setup, from a blank SD card

A linear walkthrough that takes a brand-new Raspberry Pi from "still in the
box" to "running BirdWatchAI Server and watching your feeder." If you've
already got Docker running on a Pi (or any Linux box) and just want to
install the app, the [README](README.md) Quick Start is the shorter path.

Total time: about 45 minutes, mostly waiting for things to flash, boot, or
download. ~15 minutes of which is actually hands-on.

## What you need

**Hardware**
- **Raspberry Pi 4 (4 GB or 8 GB)** or **Pi 5**. The 2 GB variants
  technically work but make ONNX classification slow.
- **microSD card, 32 GB or larger, class A2** (e.g. SanDisk Extreme,
  Samsung Pro Endurance). Cheap cards die fast under database write
  load — get a decent one.
- **Official USB-C power supply** for the Pi 4 / 5. Underpowered
  supplies cause random lockups under camera + AI load.
- **Network**: either an Ethernet cable to your router, or Wi-Fi
  credentials handy. Wired is more reliable for an always-on camera.
- **A camera**: any RTSP-capable IP camera (TP-Link Tapo, Reolink,
  Amcrest, etc.). The setup wizard asks for its RTSP URL later.

**Tools on your Windows PC**
- A USB SD-card reader.
- [Raspberry Pi Imager](https://www.raspberrypi.com/software/) — free,
  ~50 MB download from raspberrypi.com.

## 1. Image the SD card from Windows

1. Plug the SD card into your PC.
2. Open **Raspberry Pi Imager**.
3. Click **Choose Device** → pick the model you have (Pi 4 or Pi 5).
4. Click **Choose OS** → **Raspberry Pi OS (other)** → **Raspberry Pi OS
   Lite (64-bit)**. "Lite" matters — the full desktop OS wastes RAM the
   server could use.
5. Click **Choose Storage** → pick the SD card. **Double-check this is
   the SD card and not your laptop's main drive — Imager will erase it.**
6. Click **Next**. When it asks **"Would you like to apply OS
   customisation settings?"** → click **Edit Settings**.

   **General tab:**
   - **Set hostname**: `birdwatch` (or anything — this becomes how you
     reach the Pi on the network: `birdwatch.local`).
   - **Set username and password**: pick something memorable; you'll SSH
     in with these. Don't leave the default username — `pi` is well-known.
   - **Configure wireless LAN**: tick this if you're using Wi-Fi. Enter
     your SSID + password. Pick your Wi-Fi country (e.g. US).
   - **Set locale settings**: time zone + keyboard layout for your region.
     **Don't skip the time zone** — Pi OS defaults to `Etc/UTC` if you leave
     it blank, which makes every dashboard timestamp read several hours off
     from your wall clock. The fix later is `sudo timedatectl set-timezone
     America/New_York` (or whatever zone) + `docker compose restart birdwatch`,
     but it's much less hassle to set it here.

   **Services tab:**
   - **Enable SSH** → **Use password authentication**.

   Click **Save**.

7. Back at the prompt, click **Yes** to apply customisations, **Yes** to
   confirm erase. Wait ~5 minutes for write + verify. Eject the SD card
   when it finishes.

## 2. Boot the Pi

1. Insert the SD card into the Pi.
2. Plug in the Ethernet cable, **or** trust the Wi-Fi you configured
   above. (You can always switch later.)
3. Plug in power.
4. Wait ~2 minutes. The first boot expands the filesystem and applies
   your customisations. The Pi's activity LED will blink rapidly during
   this and settle when it's ready.

## 3. SSH in from Windows

From PowerShell or Windows Terminal:

```powershell
ssh birdwatch@birdwatch.local
```

(Replace `birdwatch` on both sides with whatever username + hostname you
set in Step 1.) Accept the fingerprint when prompted, enter your password.

**If `.local` doesn't resolve** (some Windows configs disable mDNS), find
the Pi's IP in your router's admin page (look for the hostname you set),
then `ssh birdwatch@<that IP>`.

### If Wi-Fi didn't come up on first boot

Pi Imager's Wi-Fi pre-config doesn't always survive Bookworm's switch to
NetworkManager — you might tick the Wi-Fi box and still find the Pi
unreachable. The reliable recovery: **plug in Ethernet temporarily**, SSH
in over the wire, then set up Wi-Fi from the Pi shell with the built-in
TUI:

```bash
sudo nmtui
```

In the menu: **Activate a connection** → pick your SSID → enter the
Wi-Fi password → OK → Back → Quit. Takes ~30 seconds. Then verify with
`nmcli device status` — `wlan0` should show `connected` with your SSID.
At that point you can unplug Ethernet and the Pi keeps going on Wi-Fi;
NetworkManager remembers the connection across reboots.

**If `nmcli device wifi list` returns nothing** (no networks visible at
all), the Wi-Fi country code probably isn't set:

```bash
sudo raspi-config nonint do_wifi_country US   # or your country code
sudo nmcli device wifi list                   # should now list networks
```

Pi 5 radios refuse to scan until a country code is registered.

## 4. Update the OS and install git

Once you're at the Pi's prompt:

```bash
sudo apt update && sudo apt upgrade -y && sudo apt install -y git
```

Takes 2-5 minutes depending on how stale the image was. (Raspberry Pi OS
Lite doesn't ship with `git` — we install it now so the BirdWatchAI
clone step works.)

## 5. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo reboot
```

The reboot is what lets you run `docker` without `sudo`. It's faster than
logging out + back in.

The SSH session will drop. Wait ~30 s and reconnect:

```powershell
ssh birdwatch@birdwatch.local
```

## 6. Install BirdWatchAI Server

```bash
git clone https://github.com/JoeBarraco/birdwatchai-server-releases.git ~/birdwatch
cd ~/birdwatch
docker compose up -d
```

The first `docker compose up -d` pulls the ~600 MB image from
GitHub Container Registry. On Wi-Fi that's typically 1-5 minutes;
on a fast Ethernet connection well under a minute. When it's done:

```bash
docker ps
```

Should list a container named `birdwatch` with status `Up X seconds`.

## 7. Open the dashboard

In your browser, on the same network:

```
http://birdwatch.local:8080
```

(Or `http://<pi-ip>:8080` if `.local` doesn't resolve.)

You'll land on the **First-time setup wizard**. The card on top says
"👋 First-time setup" and points you at `/setup` — click **Start setup**.

## 8. Run the setup wizard

The wizard walks through:

- **Welcome** — quick orientation.
- **Camera** — paste your camera's RTSP URL. For TP-Link Tapo, the
  format is `rtsp://username:password@cameraip/stream2`. **Use
  `stream2`, not `stream1`** — `stream1` is 2K and saturates Wi-Fi,
  causing h264 corruption. `stream2` is 720p and reliable.
- **Location** — ZIP code. Used to fetch outdoor temperature for each
  detection (Open-Meteo, no API key needed).
- **Email notifications** — optional. SMTP server + credentials. Gmail
  works with an app-specific password.
- **ntfy push** — optional. Free, account-less push notifications to
  your phone. Pick a hard-to-guess topic name.
- **License activation** — optional. Skip for now; a 30-day trial starts
  automatically. Activate later under **Settings → License**.
- **Done.**

When you finish, you land on the main dashboard. The Engine status card
should show monitoring `Running`, camera `Connected`, and within a few
minutes your first detection (assuming there are birds at the feeder).

## What just happened

- Your detection history + config live at `~/birdwatch/data/` on the Pi.
  Back this folder up if you care about the data — losing it means
  losing every detection and your settings.
- The container has `restart: unless-stopped`, so it auto-starts on boot
  and recovers from crashes. No need to start it manually after a reboot.
- The dashboard polls
  [this repo's releases](https://github.com/JoeBarraco/birdwatchai-server-releases/releases)
  every 30 minutes. When a newer release publishes, the **⬆ Update
  available** button appears on the Engine status card — click it for
  the changelog, then update with `docker compose pull && docker compose up -d`
  in `~/birdwatch/`.

## If something didn't work

| Symptom | What to try |
|---|---|
| `ssh: Could not resolve hostname` | Use the Pi's IP instead of `.local`. Find it in your router's admin page. |
| `Permission denied (publickey,password)` | Username typo, or you didn't enable password SSH in Step 1's Services tab. Re-image. |
| `docker: command not found` after Step 5 | The Docker install script failed silently. Run again and watch for errors. |
| `denied: requires authentication` on `docker compose up` | The GHCR package isn't public yet. Tell Joe. |
| Dashboard returns "site can't be reached" | `docker ps` — is the container running? If not, `docker logs birdwatch` shows why. |
| Camera shows "disconnected" in the dashboard | Wrong RTSP URL, wrong credentials, or the camera blocks the connection. Try the URL in VLC first to confirm. |
| Detection timestamps off by several hours | The host's timezone is wrong (defaulted to `Etc/UTC`). Fix: `sudo timedatectl set-timezone America/New_York` (substitute your zone — list them with `timedatectl list-timezones \| grep America`), then `cd ~/birdwatch && docker compose restart birdwatch`. `docker exec birdwatch date` should now match your wall clock. |

For anything else, open an issue on this repo with the output of
`docker logs --tail 200 birdwatch` and a brief description of what you
tried.
