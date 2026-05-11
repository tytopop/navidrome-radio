#!/usr/bin/env python3
"""
Navidrome Radio — Playlist Generator
Fetches random tracks from Navidrome via Subsonic API and writes an M3U playlist.

Config is read from environment variables (set by systemd service)
or falls back to /etc/radio/radio.conf if it exists.
"""

import os
import sys
import requests

# ── Config: env vars → conf file → defaults ──────────────────────────────────
def _get(key, default=""):
    val = os.environ.get(key, "")
    if val:
        return val
    conf = "/etc/radio/radio.conf"
    if os.path.exists(conf):
        with open(conf) as f:
            for line in f:
                line = line.strip()
                if line.startswith(key + "="):
                    return line.split("=", 1)[1].strip().strip('"')
    return default

NAV_URL       = _get("NAV_URL",       "http://localhost:4533")
NAV_USER      = _get("NAV_USER",      "admin")
NAV_PASS      = _get("NAV_PASS",      "")
TRACK_COUNT   = int(_get("TRACK_COUNT", "600"))
PLAYLIST_PATH = _get("PLAYLIST_PATH", "/etc/radio/radio.m3u")
CLIENT_ID     = _get("CLIENT_ID",     "navidrome-radio")
# ─────────────────────────────────────────────────────────────────────────────


def fetch_random_songs():
    url = (
        f"{NAV_URL}/rest/getRandomSongs"
        f"?size={TRACK_COUNT}"
        f"&u={NAV_USER}"
        f"&p={NAV_PASS}"
        f"&v=1.16.0"
        f"&f=json"
        f"&c={CLIENT_ID}"
    )
    try:
        resp = requests.get(url, timeout=30)
        resp.raise_for_status()
    except requests.exceptions.ConnectionError:
        print(f"❌ Cannot connect to Navidrome at {NAV_URL}", file=sys.stderr)
        sys.exit(1)
    except requests.exceptions.Timeout:
        print("❌ Navidrome request timed out", file=sys.stderr)
        sys.exit(1)
    except requests.exceptions.HTTPError as e:
        print(f"❌ HTTP error: {e}", file=sys.stderr)
        sys.exit(1)

    body = resp.json().get("subsonic-response", {})

    if body.get("status") != "ok":
        err = body.get("error", {})
        print(f"❌ Navidrome API error {err.get('code')}: {err.get('message')}", file=sys.stderr)
        sys.exit(1)

    songs = body.get("randomSongs", {}).get("song", [])
    if not songs:
        print("⚠️  No tracks returned. Check that your library is not empty.", file=sys.stderr)
        sys.exit(1)

    return songs


def build_stream_url(song_id):
    return (
        f"{NAV_URL}/rest/stream"
        f"?id={song_id}"
        f"&u={NAV_USER}"
        f"&p={NAV_PASS}"
        f"&v=1.16.0"
        f"&f=mp3"
        f"&c={CLIENT_ID}"
    )


def write_playlist(songs):
    os.makedirs(os.path.dirname(PLAYLIST_PATH), exist_ok=True)
    with open(PLAYLIST_PATH, "w", encoding="utf-8") as f:
        f.write("#EXTM3U\n")
        for song in songs:
            artist = song.get("artist", "Unknown")
            title  = song.get("title",  "Unknown")
            sid    = song.get("id")
            f.write(f"#EXTINF:-1,{artist} - {title}\n")
            f.write(build_stream_url(sid) + "\n")


def main():
    if not NAV_PASS:
        print("❌ NAV_PASS is not set. Edit /etc/radio/radio.conf or set the environment variable.", file=sys.stderr)
        sys.exit(1)

    print(f"→ Fetching {TRACK_COUNT} random tracks from {NAV_URL} …")
    songs = fetch_random_songs()
    write_playlist(songs)
    print(f"✅ Playlist updated: {len(songs)} tracks → {PLAYLIST_PATH}")


if __name__ == "__main__":
    main()
