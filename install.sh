#!/bin/bash
# navidrome-radio — interactive installer
# Run as root inside a fresh Debian 12 LXC container.
# https://github.com/tytopop/navidrome-radio

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}▸ $*${RESET}"; }
success() { echo -e "${GREEN}✅ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠️  $*${RESET}"; }
error()   { echo -e "${RED}❌ $*${RESET}"; exit 1; }
section() { echo -e "\n${BOLD}══════════════════════════════════════${RESET}"; \
            echo -e "${BOLD}  $*${RESET}"; \
            echo -e "${BOLD}══════════════════════════════════════${RESET}"; }

ask() {
    local prompt="$1" default="$2" var_name="$3"
    local value
    read -rp "$(echo -e "${YELLOW}  ${prompt}${default:+ [$default]}${RESET}: ")" value
    printf -v "$var_name" '%s' "${value:-$default}"
}

ask_pass() {
    local prompt="$1" var_name="$2"
    local value
    read -rsp "$(echo -e "${YELLOW}  ${prompt}${RESET}: ")" value
    echo ""
    printf -v "$var_name" '%s' "$value"
}

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || error "Please run as root: sudo bash install.sh"

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}"
cat <<'EOF'
  _   _             _     _                  ____           _ _
 | \ | | __ ___   _(_) __| |_ __ ___  _ __ |  _ \ __ _  __| (_) ___
 |  \| |/ _` \ \ / / |/ _` | '__/ _ \| '_ \| |_) / _` |/ _` | |/ _ \
 | |\  | (_| |\ V /| | (_| | | | (_) | | | |  _ < (_| | (_| | | (_) |
 |_| \_|\__,_| \_/ |_|\__,_|_|  \___/|_| |_|_| \_\__,_|\__,_|_|\___/

  Icecast2 + Liquidsoap radio stream from your Navidrome library
EOF
echo -e "${RESET}"

# ── Gather config ─────────────────────────────────────────────────────────────
section "Step 1 / 5 — Configuration"
echo ""
warn "All values can be changed later in /etc/radio/radio.conf"
echo ""

ask  "Navidrome URL (no trailing slash)" "http://localhost:4533" NAV_URL
ask  "Navidrome username"               "admin"                  NAV_USER
ask_pass "Navidrome password"                                    NAV_PASS
ask  "Tracks per playlist"              "600"                    TRACK_COUNT
echo ""
ask  "IP of THIS container (shown in stream URLs)" "$(hostname -I | awk '{print $1}')" RADIO_IP
ask_pass "Icecast source password (Liquidsoap → Icecast)" ICECAST_SOURCE_PASS
ask_pass "Icecast admin panel password"                   ICECAST_ADMIN_PASS

echo ""
echo -e "${BOLD}Summary:${RESET}"
echo "  Navidrome URL : $NAV_URL"
echo "  Navidrome user: $NAV_USER"
echo "  Tracks        : $TRACK_COUNT"
echo "  Radio IP      : $RADIO_IP"
echo "  Stream URL    : http://${RADIO_IP}:8000/radio"
echo ""
read -rp "$(echo -e "${YELLOW}Proceed with installation? [Y/n]: ${RESET}")" confirm
[[ "${confirm,,}" =~ ^(y|yes|"")$ ]] || { echo "Aborted."; exit 0; }

# ── Install packages ──────────────────────────────────────────────────────────
section "Step 2 / 5 — Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq icecast2 liquidsoap python3 python3-requests curl
success "Packages installed"

# ── Directory structure ───────────────────────────────────────────────────────
section "Step 3 / 5 — Creating directories & files"

mkdir -p /etc/radio /var/log/liquidsoap /etc/liquidsoap
chown -R liquidsoap:liquidsoap /var/log/liquidsoap 2>/dev/null || true

# radio.conf
cat > /etc/radio/radio.conf <<EOF
# Navidrome Radio — config file
# Edit and run: radio restart

NAV_URL="${NAV_URL}"
NAV_USER="${NAV_USER}"
NAV_PASS="${NAV_PASS}"
TRACK_COUNT="${TRACK_COUNT}"
PLAYLIST_PATH="/etc/radio/radio.m3u"
CLIENT_ID="navidrome-radio"
EOF
chmod 600 /etc/radio/radio.conf
success "Config written to /etc/radio/radio.conf"

# gen_playlist.py
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/scripts/gen_playlist.py" ]]; then
    cp "$SCRIPT_DIR/scripts/gen_playlist.py" /etc/radio/gen_playlist.py
else
    # Fallback: download from GitHub
    curl -fsSL "https://raw.githubusercontent.com/tytopop/navidrome-radio/main/scripts/gen_playlist.py" \
        -o /etc/radio/gen_playlist.py
fi
chmod +x /etc/radio/gen_playlist.py
success "gen_playlist.py installed"

# radio control script
if [[ -f "$SCRIPT_DIR/scripts/radio" ]]; then
    cp "$SCRIPT_DIR/scripts/radio" /usr/local/bin/radio
else
    curl -fsSL "https://raw.githubusercontent.com/tytopop/navidrome-radio/main/scripts/radio" \
        -o /usr/local/bin/radio
fi
chmod +x /usr/local/bin/radio
success "radio command installed → /usr/local/bin/radio"

# icecast.xml
cat > /etc/icecast2/icecast.xml <<EOF
<icecast>
    <location>Home Server</location>
    <admin>admin@localhost</admin>
    <limits>
        <clients>20</clients>
        <sources>2</sources>
        <queue-size>524288</queue-size>
        <client-timeout>30</client-timeout>
        <header-timeout>15</header-timeout>
        <source-timeout>10</source-timeout>
        <burst-on-connect>1</burst-on-connect>
        <burst-size>65535</burst-size>
    </limits>
    <authentication>
        <source-password>${ICECAST_SOURCE_PASS}</source-password>
        <admin-user>admin</admin-user>
        <admin-password>${ICECAST_ADMIN_PASS}</admin-password>
        <relay-password>relay_$(tr -dc 'a-z0-9' < /dev/urandom | head -c12)</relay-password>
    </authentication>
    <hostname>${RADIO_IP}</hostname>
    <listen-socket><port>8000</port></listen-socket>
    <http-headers>
        <header name="Access-Control-Allow-Origin" value="*" />
    </http-headers>
    <fileserve>1</fileserve>
    <paths>
        <basedir>/usr/share/icecast2</basedir>
        <logdir>/var/log/icecast2</logdir>
        <webroot>/usr/share/icecast2/web</webroot>
        <adminroot>/usr/share/icecast2/admin</adminroot>
        <alias source="/" destination="/status.xsl"/>
    </paths>
    <logging>
        <accesslog>access.log</accesslog>
        <errorlog>error.log</errorlog>
        <loglevel>3</loglevel>
        <logsize>10000</logsize>
    </logging>
    <security><chroot>0</chroot></security>
</icecast>
EOF
success "icecast.xml configured"

# radio.liq
cat > /etc/liquidsoap/radio.liq <<EOF
settings.init.allow_root := true
settings.log.stdout      := true
settings.log.level       := 2

def format_metadata(m) =
  artist = m["artist"] or ""
  title  = m["title"]  or ""
  if   artist != "" and title != "" then "#{artist} - #{title}"
  elsif artist != ""                then artist
  elsif title  != ""                then title
  else                                   "Unknown"
  end
end

src = playlist(mode="randomize", reload=3600, reload_mode="rounds", "/etc/radio/radio.m3u")
src = mksafe(src)
src = metadata.map(f=format_metadata, src)

output.icecast(
  %mp3(bitrate=192, samplerate=44100, stereo=true),
  host="127.0.0.1", port=8000,
  password="${ICECAST_SOURCE_PASS}",
  mount="radio",
  name="Home Navidrome Radio",
  description="Endless random music from your Navidrome library",
  genre="Random",
  src
)
EOF
success "radio.liq configured"

# systemd units
for unit in radio-liquidsoap.service radio-playlist.service radio-playlist.timer; do
    if [[ -f "$SCRIPT_DIR/systemd/$unit" ]]; then
        cp "$SCRIPT_DIR/systemd/$unit" "/etc/systemd/system/$unit"
    else
        curl -fsSL "https://raw.githubusercontent.com/tytopop/navidrome-radio/main/systemd/$unit" \
            -o "/etc/systemd/system/$unit"
    fi
done
success "systemd units installed"

# ── Enable & start ────────────────────────────────────────────────────────────
section "Step 4 / 5 — Enabling services"

systemctl daemon-reload
systemctl enable icecast2 radio-liquidsoap radio-playlist.timer
success "Services enabled for autostart"

# ── First run ─────────────────────────────────────────────────────────────────
section "Step 5 / 5 — First start"

info "Generating initial playlist …"
python3 /etc/radio/gen_playlist.py || warn "Playlist generation failed. Check Navidrome connection."

info "Starting services …"
systemctl start icecast2
sleep 2
systemctl start radio-liquidsoap
sleep 4

echo ""
if systemctl is-active radio-liquidsoap &>/dev/null; then
    success "Installation complete!"
    echo ""
    echo -e "${BOLD}  Stream URL : ${GREEN}http://${RADIO_IP}:8000/radio${RESET}"
    echo -e "${BOLD}  Icecast UI : ${GREEN}http://${RADIO_IP}:8000/status.xsl${RESET}"
    echo -e "${BOLD}  Admin      : ${GREEN}http://${RADIO_IP}:8000/admin/${RESET}"
    echo ""
    echo -e "${BOLD}  Quick commands:${RESET}"
    echo "    radio on      — start stream"
    echo "    radio off     — stop stream"
    echo "    radio status  — show status & current track"
    echo "    radio update  — refresh playlist now"
    echo "    radio logs    — tail liquidsoap logs"
else
    warn "Liquidsoap did not start. Run the following to diagnose:"
    echo "    journalctl -u radio-liquidsoap -n 40"
fi
echo ""
