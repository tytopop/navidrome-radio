<div align="center">

# 🎧 navidrome-radio

**Turn your Navidrome music library into a live internet radio stream**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Debian](https://img.shields.io/badge/Debian-12-red?logo=debian)](https://debian.org)
[![Icecast](https://img.shields.io/badge/Icecast-2-orange)](https://icecast.org)
[![Liquidsoap](https://img.shields.io/badge/Liquidsoap-2.x-purple)](https://liquidsoap.info)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE-E57000?logo=proxmox)](https://proxmox.com)

*Endless shuffle · Hourly playlist refresh · Auto-start on boot · One-command control*

</div>

---

## What this does

`navidrome-radio` connects to your [Navidrome](https://navidrome.org) instance via its Subsonic API, fetches a shuffled playlist of your tracks, and streams them continuously via **Icecast2** + **Liquidsoap** — just like a real radio station, available on your local network (or the internet).

```
Navidrome library  →  gen_playlist.py (Subsonic API)  →  radio.m3u
                                                              ↓
                                              Liquidsoap (shuffles & streams)
                                                              ↓
                                               Icecast2 (HTTP broadcast)
                                                              ↓
                                    http://<your-ip>:8000/radio  🎵
```

---

## Requirements

| Component | Notes |
|---|---|
| Proxmox VE | Any recent version; LXC container recommended |
| Debian 12 LXC | 1 CPU core · 512 MB RAM · 4 GB disk |
| Navidrome | Running on the same network |

> **Note:** The scripts work on any Debian/Ubuntu host — Proxmox is optional.

---

## Quick start

```bash
# 1. Clone the repo inside your Debian LXC container
git clone https://github.com/tytopop/navidrome-radio.git
cd navidrome-radio

# 2. Run the interactive installer (as root)
bash install.sh
```

The installer will ask for your Navidrome URL, credentials, and IP, then configure and start everything automatically.

After installation:

```bash
radio on      # start the stream
radio off     # stop the stream
radio status  # show status + current track
radio update  # refresh playlist now
radio logs    # tail live logs
```

Stream is available at **`http://<RADIO_IP>:8000/radio`**

---

## Manual installation

If you prefer to set up step by step, see **[INSTALL.md](INSTALL.md)**.

---

## Project structure

```
navidrome-radio/
├── install.sh                    # Interactive one-shot installer
├── scripts/
│   ├── gen_playlist.py           # Fetches random tracks via Subsonic API → M3U
│   └── radio                     # Control script (on/off/status/update/logs)
├── config/
│   ├── icecast.xml               # Icecast2 config template
│   ├── radio.liq                 # Liquidsoap config template
│   └── radio.conf                # Runtime variables template
└── systemd/
    ├── radio-liquidsoap.service  # Main stream service
    ├── radio-playlist.service    # One-shot playlist updater
    └── radio-playlist.timer      # Hourly playlist refresh timer
```

After installation, deployed files live at:

```
/etc/radio/          → gen_playlist.py, radio.conf, radio.m3u (generated)
/etc/liquidsoap/     → radio.liq
/etc/icecast2/       → icecast.xml
/etc/systemd/system/ → radio-*.service / radio-*.timer
/usr/local/bin/      → radio
```

---

## Configuration

All runtime settings are stored in `/etc/radio/radio.conf`:

```bash
NAV_URL="http://<NAVIDROME_IP>:<PORT>"  # Navidrome address
NAV_USER="admin"                         # Navidrome login
NAV_PASS="your_password"                 # Navidrome password
TRACK_COUNT="600"                        # Tracks per playlist
```

After editing, apply with:

```bash
radio restart
```

---

## How the playlist works

`gen_playlist.py` calls the Navidrome **Subsonic API** endpoint `getRandomSongs` and writes an M3U file with streaming URLs:

```
GET /rest/getRandomSongs?size=600&u=...&p=...&v=1.16.0&f=json
```

Each track URL points directly to Navidrome's `/rest/stream` endpoint, so Liquidsoap pulls audio in real time — no local file copies needed.

The playlist is refreshed automatically every hour by the systemd timer, and also on every service start.

---

## Troubleshooting

**Stream returns 404**
```bash
systemctl status icecast2 radio-liquidsoap
journalctl -u radio-liquidsoap -n 40
```

**Can't connect to Navidrome**
```bash
# Test API connectivity:
curl "http://<NAVIDROME_IP>:<PORT>/rest/ping?v=1.16.0&f=json&u=admin&p=PASSWORD&c=test"
# Expected: {"subsonic-response":{"status":"ok",...}}
```

**`password` mismatch error in Liquidsoap logs**
→ `password=` in `radio.liq` must match `<source-password>` in `icecast.xml`.

**`fallible` / `Switch to blank` warnings**
→ Normal at startup while the first track buffers. Persistent? Check that `mksafe()` is present in `radio.liq`.

**Playlist not refreshing**
```bash
python3 /etc/radio/gen_playlist.py          # manual test
systemctl list-timers radio-playlist.timer  # check next run
```

**Missing python3-requests**
```bash
apt install -y python3-requests
```

---

## Expose to the internet

Once your local stream is stable, you can put it behind Nginx + Let's Encrypt:

```nginx
# /etc/nginx/sites-available/radio
server {
    listen 80;
    server_name radio.yourdomain.com;

    location /radio {
        proxy_pass      http://<RADIO_IP>:8000/radio;
        proxy_buffering off;
        proxy_cache     off;
    }
}
```

```bash
certbot --nginx -d radio.yourdomain.com
```

Then update `<hostname>` in `/etc/icecast2/icecast.xml` to your domain and restart:

```bash
radio restart
```

---

## Security notes

- `/etc/radio/radio.conf` is created with `chmod 600` (root-only).
- For better isolation, create a dedicated read-only Navidrome user for the API calls (no 2FA required).
- The Icecast admin panel is only needed for diagnostics — consider disabling `<fileserve>` and setting a strong admin password if you expose port 8000 publicly.

---

## Contributing

PRs and issues welcome. Please open an issue before large changes.

---

## License

[MIT](LICENSE)
