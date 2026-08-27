# Can't find your BirdWatchAI server? Scan for it.

Normally you reach the dashboard at **`http://birdwatch.local:8080`** (or
whatever hostname you set when imaging the Pi). That `.local` name is published
automatically over your network — no IP address needed.

But some setups can't resolve `.local` names: older Windows, machines on a work
VPN, or a "Guest" Wi-Fi that isolates devices from each other. And because a
headless Pi has no screen, you can't just read its IP address off a monitor.

These little scripts solve that. Each one scans your local network, finds every
BirdWatchAI server on it, and prints a clickable dashboard link — no IP hunting.
They only talk to devices on your own network; nothing is installed and nothing
is sent anywhere.

> **First, the easy check.** Make sure the computer you're scanning from is on
> the **same Wi-Fi / network as the Pi** — not a "Guest" network and not a work
> VPN. That alone fixes most "can't reach it" reports.

## Windows — the easy way (download and double-click)

1. Download **[BirdWatchFinder.exe](https://github.com/JoeBarraco/BirdWatchAI-Releases/releases/download/v1.0.0-finder/BirdWatchFinder.exe)**
   (hosted on the BirdWatchAI-Releases repo, which is where our binaries live —
   this repo publishes tags and release notes only).
2. **Double-click it.** A window opens, scans your network, shows the dashboard
   address, and offers to open it in your browser.

That's it — nothing to install, no PowerShell, no typing.

> **Setting up a new camera?** The `.exe` also scans for **feeder cameras**
> (Tapo and other ONVIF cameras) and prints their IP addresses — handy during
> first-time setup, when you need the camera's IP to build its RTSP URL. See
> [Finding your camera](#finding-your-camera) below. (The PowerShell/Mac/Linux
> scripts find servers only.)

> **"Windows protected your PC" / SmartScreen warning?** This happens with any
> new program that isn't code-signed yet. The finder only scans your own
> network — it's safe. Click **More info** → **Run anyway**. (If you'd rather
> not, use the PowerShell option below instead — it does the exact same thing.)

### Windows — the PowerShell alternative

If you'd rather not download an `.exe`, open **PowerShell** (Start menu → type
"PowerShell" → Enter) and paste:

```powershell
irm https://raw.githubusercontent.com/JoeBarraco/birdwatchai-server-releases/main/find-birdwatch.ps1 | iex
```

That downloads and runs the finder in one step. Or download
[`find-birdwatch.ps1`](find-birdwatch.ps1) and run it from the folder you saved
it in (this version also offers to open the dashboard for you):

```powershell
powershell -ExecutionPolicy Bypass -File .\find-birdwatch.ps1
```

## macOS / Linux

Open **Terminal** and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/JoeBarraco/birdwatchai-server-releases/main/find-birdwatch.sh | bash
```

Or download [`find-birdwatch.sh`](find-birdwatch.sh) and run it — that version
also offers to open the dashboard for you:

```bash
chmod +x find-birdwatch.sh
./find-birdwatch.sh
```

## What you'll see

```
BirdWatchAI Server finder
-------------------------
Scanning 192.168.1.0/24 on port 8080 ...

Found 1 BirdWatchAI server:

  [1] Joe's Backyard Feeder
      http://192.168.1.42:8080
      host: birdwatch-serverpi   camera: Connected   detections today: 7   monitoring: Running

Found 1 camera:

  * 192.168.1.50    Tapo C113   (ONVIF discovery)

Open it in your browser? [Y/n]
```

The **feeder name** (set under Settings → Community) and the **host name** help
you tell servers apart when you have more than one. The host name also means you
can reach the dashboard at `http://birdwatch.local:8080` — a stable address that
survives IP changes. The finder recovers the host name over the network (mDNS)
even when the server itself doesn't report it, so you'll usually see it
regardless of the server's version or Docker setup.

Bookmark that address so you don't have to scan again.

## Finding your camera

The `.exe` also scans for **feeder cameras** on your network — useful during
first-time setup, when you need the camera's IP to fill in its RTSP URL. It finds
them two ways:

- **ONVIF discovery** — most IP cameras (including Tapo) announce themselves; this
  gives you the model name too, e.g. `Tapo C113`.
- **Port scan** — anything answering on the RTSP port (554) shows up as a
  "possible camera" even if it doesn't announce itself.

> **Camera detection is best-effort.** Cameras on Wi-Fi answer slowly and
> sometimes miss a scan (a busy camera, or one briefly rate-limiting a flurry of
> probes). If a camera you expect isn't listed, **just run the finder again** —
> the camera scan takes ~10–15 seconds and a second pass usually catches it. You
> can also give it more time with `BirdWatchFinder.exe --timeout 800`.

Once you have the IP, your camera's RTSP URL looks like:

```
rtsp://<username>:<password>@192.168.1.50:554/stream2
```

> **Tapo cameras need a "Camera Account" first.** In the Tapo phone app, open your
> camera → **Advanced Settings → Camera Account** (a.k.a. Third-Party
> Compatibility) and set a username + password. Those are the credentials you put
> in the RTSP URL — and until you set them, the camera may not appear in the scan
> at all. Use **`stream2`** on most Tapo models (720p, the right default); some
> low-cost models cap `stream2` at 360p and need `stream1` — see the camera step
> in [PISETUP.md](PISETUP.md).

To scan for servers only (skip the camera scan), run `BirdWatchFinder.exe
--no-cameras`.

## If it finds nothing

| Symptom | Try |
|---|---|
| "No BirdWatchAI servers found" | Confirm the Pi is powered on and on the **same** network (not Guest Wi-Fi / VPN). |
| Slow or busy Wi-Fi | Give each host more time — Exe: `BirdWatchFinder.exe --timeout 800`  ·  PowerShell: `.\find-birdwatch.ps1 -TimeoutMs 800`  ·  Mac/Linux: `TIMEOUT=1.5 ./find-birdwatch.sh` |
| Your network isn't a `192.168.x.x` /24 | Force the prefix — Exe: `BirdWatchFinder.exe --subnet 10.0.0`  ·  PowerShell: `.\find-birdwatch.ps1 -Subnet 10.0.0`  ·  Mac/Linux: `SUBNET=10.0.0 ./find-birdwatch.sh` |
| Still nothing | Open your **router's admin page** — its list of connected devices shows the Pi by the hostname you set (e.g. `birdwatch`) with its IP next to it. |

> To pass flags to the `.exe`, run it from a terminal (`cd` to where you saved
> it, then `BirdWatchFinder.exe --timeout 800`), or just use the PowerShell
> version — double-clicking the exe always uses the defaults.

## Stop the IP from changing

If the finder shows a *different* address each time you scan, your router is
handing the Pi a new IP on each lease. Fix it once: in your router's admin page,
find the DHCP / LAN settings and **reserve** (sometimes called "static lease" or
"bind") the Pi's current IP to its MAC address. After that the address is stable
and you can bookmark it for good.
