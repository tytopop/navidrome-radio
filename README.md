# navidrome-radio

**Turn your Navidrome music library into a live internet radio stream**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=for-the-badge&logo=python&logoColor=white)](#quick-start)
[![Icecast](https://img.shields.io/badge/Icecast-2-orange?style=for-the-badge)](#quick-start)
[![Liquidsoap](https://img.shields.io/badge/Liquidsoap-2.x-purple?style=for-the-badge)](#quick-start)
[![Proxmox](https://img.shields.io/badge/Proxmox-LXC-E57000?style=for-the-badge)](#quick-start)
[![Stars](https://img.shields.io/github/stars/tytopop/navidrome-radio?style=for-the-badge)](https://github.com/tytopop/navidrome-radio/stargazers)
[![Validated](https://img.shields.io/badge/Docs-Validated-4c1?style=for-the-badge)](#quick-start)

> Endless shuffle · Hourly playlist refresh · One-command control · Debian LXC

```
Navidrome  →  gen_playlist.py  →  Liquidsoap  →  Icecast2  →  http://<ip>:8000/radio
```

---

<details>
<summary>🇬🇧 English</summary>

## Quick start

```bash
git clone https://github.com/tytopop/navidrome-radio.git
cd navidrome-radio
bash install.sh
```

```bash
radio on      # start
radio status  # current track
radio update  # refresh playlist
```

See [INSTALL.md](INSTALL.md) for manual setup.

</details>

---

<details open>
<summary>🇷🇺 Русский</summary>

## Быстрый старт

```bash
git clone https://github.com/tytopop/navidrome-radio.git
cd navidrome-radio
bash install.sh
```

```bash
radio on
radio status
radio update
```

Подробная установка: [INSTALL.md](INSTALL.md) и [README.ru.md](README.ru.md).

</details>

---

## License

MIT — [LICENSE](LICENSE)

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=tytopop/navidrome-radio&type=Date)](https://star-history.com/#tytopop/navidrome-radio&Date)
