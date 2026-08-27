# Pi as a camera access point

A walkthrough for running BirdWatchAI Server on a Pi that **hosts its own Wi-Fi
network for the camera** while staying on the internet through a second
Wi-Fi connection.

This is the setup you want when the camera can't or shouldn't join the
existing Wi-Fi: a feeder out of range of the house router, a portable rig you
carry to a classroom or a field site, or any network where you can't put an
IP camera on the main SSID. The camera joins a small private network the Pi
runs; the Pi reaches the internet separately; nothing else on the host network
can see the camera.

**Do [PISETUP.md](PISETUP.md) steps 1-5 first.** This guide picks up at a Pi
you can SSH into, with Docker installed, *before* you install BirdWatchAI.
Total time: about 30 minutes.

## What you need on top of the normal build

- **A USB Wi-Fi adapter.** Not optional — see below.
- **The camera's Tapo (or equivalent) app credentials**, because you'll
  re-onboard the camera onto the new network.

### Why a second adapter

A single Wi-Fi radio *can* host an access point and be a client at the same
time, but both roles are forced onto **one channel**, and the client side wins.
Your AP then follows whatever channel the upstream router picks, moves when it
moves, and drops the camera every time the uplink reconnects. Worse, if the
upstream network is 5 GHz, your AP is 5 GHz too — and Tapo cameras are
2.4 GHz-only, so they simply can't join.

Two radios means two independent channels and two independent link states. For
an unattended camera this is the difference between "works" and "works until
something reconnects."

Pick an adapter with a mainline-supported chipset — **MT7612U, MT7921U**, or
RTL8812BU as a last resort. Avoid unbranded adapters needing an out-of-tree
driver; they break on every kernel upgrade, which on a headless Pi means a
device that silently stops working after `apt upgrade`.

### Which radio does which job

| Radio | Role | Why |
|---|---|---|
| **Built-in** (`wlan0`) | **Access point** for the camera | Known-good AP support, and 2.4 GHz reaches further through a wall to a feeder |
| **USB adapter** (`wlan1`) | **Internet uplink** | Can sit on 5 GHz independently; easy to swap if a venue's network needs different hardware |

## 1. Set the Wi-Fi country

An unset country code means the radio refuses to start an AP at all, and the
error doesn't say so.

```bash
sudo raspi-config nonint do_wifi_country US
```

Substitute your country code. Then install the DHCP/DNS helper
NetworkManager's shared mode needs:

```bash
sudo apt update && sudo apt install -y dnsmasq-base
```

## 2. Identify your two interfaces

Plug in the USB adapter, then:

```bash
nmcli device status
```

You'll see two `wifi` devices, typically `wlan0` (built-in) and `wlan1` (USB).
**Confirm which is which** — don't assume the USB one is `wlan1`:

```bash
for d in /sys/class/net/wlan*; do echo "$(basename $d): $(readlink -f $d | grep -q usb && echo USB || echo built-in)"; done
```

If your names differ from `wlan0`/`wlan1`, substitute yours everywhere below.

## 3. Create the access point

This is one command. Replace the SSID and passphrase — **use a real
passphrase**, at least 12 characters; this network has internet access and a
camera on it.

```bash
sudo nmcli con add type wifi ifname wlan0 con-name birdcam-ap autoconnect yes ssid BirdCam-AP mode ap
```

```bash
sudo nmcli con modify birdcam-ap 802-11-wireless.band bg 802-11-wireless.channel 6 802-11-wireless.powersave 2 wifi-sec.key-mgmt wpa-psk wifi-sec.proto rsn wifi-sec.pairwise ccmp wifi-sec.psk 'CHANGE-THIS-passphrase' ipv4.method shared connection.autoconnect-priority 10
```

What the important parts do:

- **`ipv4.method shared`** is the whole networking stack in one setting.
  NetworkManager gives the Pi `10.42.0.1`, runs DHCP and DNS for the AP
  subnet, enables IP forwarding, and adds the NAT rules that let the camera
  reach the internet through the uplink.
- **`band bg` + `channel 6`** pins it to 2.4 GHz, which is all a Tapo camera
  can join. Channel 6 is a reasonable default; 1 or 11 if you find 6 congested.
- **`powersave 2`** disables Wi-Fi power management. Its Pi implementation is a
  well-known cause of links that silently stall after hours of idle.
- **`wifi-sec.proto rsn` + `pairwise ccmp`** forces WPA2-AES. Some cameras fail
  to associate when the AP offers a mixed TKIP/AES configuration.

Bring it up:

```bash
sudo nmcli con up birdcam-ap
```

> **Your camera needs the internet, even though the Pi is right there.** Tapo
> cameras check in with TP-Link's cloud and refuse to serve RTSP when they
> can't reach it. This is why the AP is NAT'd (`shared`) rather than isolated.
> If you'd rather the camera not have general internet access, that's a
> firewall-rule exercise, not a `manual` addressing one — and test it before
> you rely on it.

## 4. Connect the uplink

```bash
sudo nmcli device wifi connect 'YourNetworkSSID' password 'YourPassword' ifname wlan1
```

Then apply three settings that matter for an unattended device:

```bash
sudo nmcli con modify 'YourNetworkSSID' wifi.cloned-mac-address permanent 802-11-wireless.powersave 2 connection.autoconnect-retries 0
```

- **`cloned-mac-address permanent`** turns off MAC randomization. With it on,
  every reconnect looks like a new device to a captive portal, so you re-auth
  constantly and can hit per-device limits.
- **`autoconnect-retries 0`** means *infinite*. The default is 4 — after four
  failures NetworkManager gives up on the profile entirely and won't retry
  until something wakes it. That default is why unattended Pis "never come
  back" after a router reboot.

For a guest network with a click-through portal, see
[the captive-portal section](#8-optional-uplink-watchdog-for-guest-networks).

## 5. Verify both radios are up together

```bash
nmcli device status
```

`wlan0` should read `connected` with your AP name, `wlan1` `connected` with
the upstream SSID. Then confirm each side independently:

```bash
ip -brief addr show wlan0 && ping -c 2 -I wlan1 1.1.1.1
```

You want `10.42.0.1/24` on `wlan0` and successful pings out `wlan1`. If the AP
has no address, `sudo journalctl -u NetworkManager -n 50` will usually name the
reason — most often the country code from Step 1.

## 6. Join the camera to the AP

1. On your phone, join the **BirdCam-AP** network.
2. Open the Tapo app and add the camera as if it were new. When it asks which
   Wi-Fi the camera should join, pick **BirdCam-AP**.
3. In the camera's settings, enable the **Camera Account** (Advanced →
   Camera Account). That's the RTSP credential — the Tapo login won't work.

Then find the camera's address from the Pi:

```bash
ip neigh show dev wlan0
```

It'll be something like `10.42.0.x`. Your RTSP URL is
`rtsp://USER:PASS@10.42.0.x:554/stream2`.

Use **stream2** (the sub-stream) on a C113 — it's 720p and the right default.
On a C120 or similar, stream2 caps at 640×360, so use stream1 configured to
1080p in the Tapo app. Don't run stream1 at 2K: it saturates the camera's own
Wi-Fi uplink and produces h264 corruption.

> **Do this at home, before you travel.** The camera remembers the AP, and the
> AP travels with the Pi. At the venue the only thing that changes is Step 4's
> uplink — which you can redo in one command. Onboarding a camera over an
> unfamiliar network with a room waiting on you is not where you want to be.

## 7. Install BirdWatchAI in host-network mode

Follow [PISETUP.md](PISETUP.md) step 6 to clone and start the stack, then make
one edit. A container in AP mode generally needs the host's network namespace,
which changes how the update sidecar is reached.

```bash
cd ~/birdwatch && nano docker-compose.yml
```

Under the `birdwatch` service: **uncomment `network_mode: host`** and **delete
the `ports:` block** (Docker discards published ports in host mode, and leaving
them there just misleads you later).

Leave the `watchtower` service alone — it already publishes its API on
`127.0.0.1:8081`, which is how a host-networked container finds it. Do not add
a `BirdWatch__Update__WatchtowerUrl` line; without one the app probes both
addresses and works in either mode.

```bash
docker compose up -d
```

Confirm the update path can find the sidecar:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8081/v1/update
```

**`401` is the success case** — reachable, asking for its token. `000` means
unreachable; check the `ports:` line on the watchtower service.

The dashboard is at `http://<pi-hostname>.local:8080` from either network.

## 8. Optional: uplink watchdog for guest networks

Skip this on a home network. On a school or corporate guest SSID, sessions
often expire on a timer, and the failure mode is nasty: you stay associated
with a valid IP, the gateway still pings, but every request is intercepted by
the portal. Nothing reconnects because nothing thinks anything is wrong. The
check therefore has to be an **HTTP** check, not a ping.

Create `/usr/local/bin/uplink-watchdog`:

```bash
sudo nano /usr/local/bin/uplink-watchdog
```

```sh
#!/bin/bash
set -u
UPLINK=wlan1                    # the INTERNET interface, never the AP
PROFILE="YourNetworkSSID"
STATE=/run/uplink-watchdog.fails
URL="http://networkcheck.kde.org/"

code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 \
       --interface "$UPLINK" "$URL" 2>/dev/null || echo 000)

if [ "$code" = "200" ] || [ "$code" = "204" ]; then
    echo 0 > "$STATE"; exit 0
fi

fails=$(( $(cat "$STATE" 2>/dev/null || echo 0) + 1 ))
echo "$fails" > "$STATE"
logger -t uplink-watchdog "check failed (http=$code), consecutive=$fails"

case "$fails" in
    1|2) exit 0 ;;                                    # ride out a blip
    3)   nmcli con down "$PROFILE"; sleep 3; nmcli con up "$PROFILE" ;;
    4|5) nmcli dev disconnect "$UPLINK"; sleep 5; nmcli dev connect "$UPLINK" ;;
    *)   logger -t uplink-watchdog "escalating to reboot"
         echo 0 > "$STATE"; systemctl reboot ;;
esac
```

```bash
sudo chmod +x /usr/local/bin/uplink-watchdog
```

Then a timer that runs it every two minutes:

```bash
printf '[Unit]\nDescription=Uplink connectivity watchdog\n[Service]\nType=oneshot\nExecStart=/usr/local/bin/uplink-watchdog\n' | sudo tee /etc/systemd/system/uplink-watchdog.service
```

```bash
printf '[Unit]\nDescription=Run uplink watchdog every 2 minutes\n[Timer]\nOnBootSec=3min\nOnUnitActiveSec=2min\n[Install]\nWantedBy=timers.target\n' | sudo tee /etc/systemd/system/uplink-watchdog.timer
```

```bash
sudo systemctl daemon-reload && sudo systemctl enable --now uplink-watchdog.timer
```

**The watchdog only ever touches the uplink.** Every command names `$UPLINK`
explicitly so a flapping internet connection can never take the camera's
network down with it.

**A dead uplink is not a dead server.** RTSP is Pi-to-camera on the local AP,
so detection and recording keep working; you lose notifications, community
sharing, and update checks. That's an argument for a patient watchdog — long
backoff, reboot only as a last resort — rather than an aggressive one.

**What a watchdog can't fix:** a portal that needs a human to tick "I accept."
Reconnecting bounces you straight back to the portal. Ask the venue's IT to
register the Pi's MAC address instead — one email, and the whole problem
disappears. Get the MAC with `cat /sys/class/net/wlan1/address`.

## Verify the whole thing

Before you call it done:

```bash
nmcli device status && docker ps --format '{{.Names}} | {{.Status}}'
```

- [ ] `wlan0` connected as the AP, `wlan1` connected upstream
- [ ] `birdwatch` and `birdwatch-watchtower` both `Up`
- [ ] Dashboard loads at `http://<hostname>.local:8080`
- [ ] Camera shows **connected**, live frames arriving
- [ ] `curl` to `127.0.0.1:8081/v1/update` returns **401**
- [ ] Reboot the Pi (`sudo reboot`) and confirm everything returns unattended

That last one is the only test that matters for a device you're going to leave
running. Do it.

## If something didn't work

| Symptom | What to try |
|---|---|
| AP never gets an IP; `wlan0` stuck at `connecting` | Wi-Fi country not set. `sudo raspi-config nonint do_wifi_country US`, then `sudo nmcli con up birdcam-ap`. |
| AP is up but clients get no address | `dnsmasq-base` missing. `sudo apt install -y dnsmasq-base`, then restart the connection. |
| Camera won't join the AP | Almost always 5 GHz or WPA3. Confirm `band bg` and that `wifi-sec.proto` is `rsn` with `pairwise ccmp`. |
| Camera joins but RTSP times out | The camera can't reach TP-Link's cloud. Check `ipv4.method` is `shared`, and `ping -c2 -I wlan1 1.1.1.1` from the Pi. |
| Camera connected, dashboard shows disconnected | RTSP credentials. You need the **Camera Account**, not your Tapo login. |
| Both radios connect, but the uplink dies after hours | Power save. `sudo nmcli con modify <uplink> 802-11-wireless.powersave 2` and reconnect. |
| Uplink won't retry after a router reboot | `connection.autoconnect-retries 0` (infinite) — the default of 4 gives up permanently. |
| "Watchtower unreachable" on Apply update | Host mode plus a missing `ports:` line on watchtower. See [PISETUP.md](PISETUP.md) troubleshooting. |
| Dashboard unreachable after enabling host mode | You left the `ports:` block on `birdwatch`. Remove it and `docker compose up -d`. |

For anything else, open an issue with `nmcli device status`,
`sudo journalctl -u NetworkManager -n 100`, and `docker logs --tail 200 birdwatch`.
