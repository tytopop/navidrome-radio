# Manual Installation Guide

Step-by-step alternative to `install.sh`.  
All `<PLACEHOLDER>` values must be replaced with your own before use.

---

## 1. Create LXC container (Proxmox)

**Via Web UI:**

| Setting | Value |
|---|---|
| Template | `debian-12-standard` |
| Hostname | `radio-stream` |
| Root Disk | 4 GB |
| Memory | 512 MB |
| Swap | 512 MB |
| CPU | 1 core |
| Network | Static IP, bridge `vmbr0` |
| Options | Start at boot ✅ · Unprivileged ✅ |

**Via community-script:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/debian.sh)"
```

---

## 2. Install packages

```bash
apt update && apt upgrade -y
apt install -y icecast2 liquidsoap python3 python3-requests nano curl
```

During `icecast2` installation, press **OK** on all prompts — you'll overwrite the config in the next step.

---

## 3. Create directories

```bash
mkdir -p /etc/radio /var/log/liquidsoap /etc/liquidsoap
chown -R liquidsoap:liquidsoap /var/log/liquidsoap
```

---

## 4. Write config file

`/etc/radio/radio.conf`

```bash
NAV_URL="http://<NAVIDROME_IP>:<NAVIDROME_PORT>"
NAV_USER="<NAVIDROME_USER>"
NAV_PASS="<NAVIDROME_PASS>"
TRACK_COUNT="600"
PLAYLIST_PATH="/etc/radio/radio.m3u"
CLIENT_ID="navidrome-radio"
```

```bash
chmod 600 /etc/radio/radio.conf
```

---

## 5. Install scripts

```bash
# Playlist generator
cp scripts/gen_playlist.py /etc/radio/gen_playlist.py
chmod +x /etc/radio/gen_playlist.py

# Control command
cp scripts/radio /usr/local/bin/radio
chmod +x /usr/local/bin/radio

# Test playlist generation
python3 /etc/radio/gen_playlist.py
```

---

## 6. Configure Icecast2

Replace contents of `/etc/icecast2/icecast.xml` with `config/icecast.xml`, substituting:
- `<ICECAST_SOURCE_PASS>` — password Liquidsoap uses to push the stream
- `<ICECAST_ADMIN_PASS>` — admin panel password
- `<RADIO_IP>` — IP of this container

```bash
systemctl restart icecast2
systemctl status icecast2   # should show: active (running)
```

---

## 7. Configure Liquidsoap

Copy `config/radio.liq` to `/etc/liquidsoap/radio.liq`, replacing `<ICECAST_SOURCE_PASS>` with the same value used in `icecast.xml`.

Check syntax:

```bash
liquidsoap --check /etc/liquidsoap/radio.liq
```

---

## 8. Install systemd units

```bash
cp systemd/radio-liquidsoap.service /etc/systemd/system/
cp systemd/radio-playlist.service   /etc/systemd/system/
cp systemd/radio-playlist.timer     /etc/systemd/system/

systemctl daemon-reload
systemctl enable icecast2 radio-liquidsoap radio-playlist.timer
```

---

## 9. Start

```bash
radio on
radio status
```

Stream: `http://<RADIO_IP>:8000/radio`
