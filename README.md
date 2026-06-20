# BirdWatchAI Server

Public installer + release feed for **BirdWatchAI Server** — the bird-feeder
camera that identifies species on-device and lets you watch your backyard
from anywhere. Source code lives in a private repository; this repo ships
release tags, install instructions, and a ready-to-go `docker-compose.yml`.

The server is one Docker image (~600 MB, multi-arch — Raspberry Pi 4/5 and
x86 Linux both work). Once it's running you'll have a web dashboard at
`http://<your-host>:8080` with a first-time setup wizard.

## Quick start

### 1. Install Docker (skip if you already have it)

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in so the docker permission applies.
