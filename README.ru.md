<div align="center">

# 🎧 navidrome-radio

**Превратите вашу библиотеку Navidrome в живое интернет-радио**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Debian](https://img.shields.io/badge/Debian-12-red?logo=debian)](https://debian.org)
[![Icecast](https://img.shields.io/badge/Icecast-2-orange)](https://icecast.org)
[![Liquidsoap](https://img.shields.io/badge/Liquidsoap-2.x-purple)](https://liquidsoap.info)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE-E57000?logo=proxmox)](https://proxmox.com)

*Бесконечный шаффл · Обновление плейлиста каждый час · Автозапуск · Управление одной командой*

[🇬🇧 English](README.md) · **🇷🇺 Русский**

</div>

---

## Что это делает

`navidrome-radio` подключается к вашему [Navidrome](https://navidrome.org) через Subsonic API, формирует перемешанный плейлист из вашей коллекции и транслирует треки непрерывно через **Icecast2** + **Liquidsoap** — как настоящая радиостанция, доступная в локальной сети или в интернете.

```
Библиотека Navidrome  →  gen_playlist.py (Subsonic API)  →  radio.m3u
                                                                 ↓
                                             Liquidsoap (перемешивает и стримит)
                                                                 ↓
                                              Icecast2 (HTTP-вещание)
                                                                 ↓
                                   http://<ваш-ip>:8000/radio  🎵
```

---

## Требования

| Компонент | Примечание |
|---|---|
| Proxmox VE | Любая актуальная версия; рекомендуется LXC-контейнер |
| Debian 12 LXC | 1 ядро CPU · 512 МБ RAM · 4 ГБ диска |
| Navidrome | Запущен в той же сети |

> **Примечание:** Скрипты работают на любом хосте Debian/Ubuntu — Proxmox не обязателен.

---

## Быстрый старт

```bash
# 1. Клонируйте репозиторий внутри Debian LXC контейнера
git clone https://github.com/tytopop/navidrome-radio.git
cd navidrome-radio

# 2. Запустите интерактивный установщик (от root)
bash install.sh
```

Установщик спросит адрес Navidrome, логин, пароль и IP контейнера — и настроит всё автоматически.

После установки:

```bash
radio on      # запустить поток
radio off     # остановить поток
radio status  # статус + текущий трек
radio update  # обновить плейлист прямо сейчас
radio logs    # смотреть логи в реальном времени
```

Поток доступен по адресу: **`http://<RADIO_IP>:8000/radio`**

---

## Ручная установка

Если хотите настроить пошагово — смотрите **[INSTALL.ru.md](INSTALL.ru.md)**.

---

## Структура проекта

```
navidrome-radio/
├── install.sh                    # Интерактивный установщик одной командой
├── scripts/
│   ├── gen_playlist.py           # Получает случайные треки через Subsonic API → M3U
│   └── radio                     # Скрипт управления (on/off/status/update/logs)
├── config/
│   ├── icecast.xml               # Шаблон конфига Icecast2
│   ├── radio.liq                 # Шаблон конфига Liquidsoap
│   └── radio.conf                # Шаблон переменных окружения
└── systemd/
    ├── radio-liquidsoap.service  # Основной сервис потока
    ├── radio-playlist.service    # Одноразовое обновление плейлиста
    └── radio-playlist.timer      # Таймер обновления (каждый час)
```

После установки файлы разворачиваются в:

```
/etc/radio/          → gen_playlist.py, radio.conf, radio.m3u (генерируется)
/etc/liquidsoap/     → radio.liq
/etc/icecast2/       → icecast.xml
/etc/systemd/system/ → radio-*.service / radio-*.timer
/usr/local/bin/      → radio
```

---

## Конфигурация

Все настройки хранятся в `/etc/radio/radio.conf`:

```bash
NAV_URL="http://<IP_NAVIDROME>:<ПОРТ>"  # Адрес Navidrome
NAV_USER="admin"                         # Логин
NAV_PASS="ваш_пароль"                   # Пароль
TRACK_COUNT="600"                        # Треков в плейлисте
```

После изменений примените:

```bash
radio restart
```

---

## Как работает плейлист

`gen_playlist.py` вызывает эндпоинт Subsonic API `getRandomSongs` и записывает M3U-файл со ссылками на стриминг:

```
GET /rest/getRandomSongs?size=600&u=...&p=...&v=1.16.0&f=json
```

Каждая ссылка ведёт напрямую на `/rest/stream` Navidrome — Liquidsoap тянет аудио в реальном времени без локального копирования файлов.

Плейлист автоматически обновляется каждый час через systemd-таймер, а также при каждом старте сервиса.

---

## Диагностика

**Поток возвращает 404**
```bash
systemctl status icecast2 radio-liquidsoap
journalctl -u radio-liquidsoap -n 40
```

**Не подключается к Navidrome**
```bash
# Проверьте API:
curl "http://<IP_NAVIDROME>:<ПОРТ>/rest/ping?v=1.16.0&f=json&u=admin&p=ПАРОЛЬ&c=test"
# Ожидаемый ответ: {"subsonic-response":{"status":"ok",...}}
```

**Ошибка несовпадения пароля в логах Liquidsoap**
→ Значение `password=` в `radio.liq` должно совпадать с `<source-password>` в `icecast.xml`.

**Предупреждения `fallible` / `Switch to blank`**
→ Нормально при старте, пока буферизуется первый трек. Если постоянно — проверьте, что `mksafe()` присутствует в `radio.liq`.

**Плейлист не обновляется**
```bash
python3 /etc/radio/gen_playlist.py          # тест вручную
systemctl list-timers radio-playlist.timer  # следующий запуск
```

**Нет модуля python3-requests**
```bash
apt install -y python3-requests
```

**Нет метаданных в плеере**
→ VLC: `Ctrl+I` во время воспроизведения. mpv: нажмите `i`.
→ Попробуйте другой плеер: foobar2000, Clementine, Substreamer.

---

## Вывод в интернет

Когда локальный поток стабильно работает, можно поставить Nginx + Let's Encrypt:

```nginx
# /etc/nginx/sites-available/radio
server {
    listen 80;
    server_name radio.вашдомен.com;

    location /radio {
        proxy_pass      http://<RADIO_IP>:8000/radio;
        proxy_buffering off;
        proxy_cache     off;
    }
}
```

```bash
certbot --nginx -d radio.вашдомен.com
```

Затем обновите `<hostname>` в `/etc/icecast2/icecast.xml` на свой домен и перезапустите:

```bash
radio restart
```

Поток будет доступен по адресу: `https://radio.вашдомен.com/radio`

---

## Безопасность

- `/etc/radio/radio.conf` создаётся с правами `chmod 600` (только root).
- Для лучшей изоляции создайте отдельного пользователя Navidrome только для API (без 2FA, права только на чтение).
- Icecast admin-панель нужна только для диагностики — если открываете порт 8000 публично, установите надёжный пароль и рассмотрите отключение `<fileserve>`.

---

## Участие в разработке

PR и issues приветствуются. Пожалуйста, откройте issue перед крупными изменениями.

---

## Лицензия

[MIT](LICENSE)
