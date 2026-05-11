# Ручная установка

Пошаговая альтернатива `install.sh`.  
Все значения `<PLACEHOLDER>` замените на свои перед использованием.

---

## 1. Создание LXC-контейнера (Proxmox)

**Через Web UI:**

| Параметр | Значение |
|---|---|
| Template | `debian-12-standard` |
| Hostname | `radio-stream` |
| Root Disk | 4 ГБ |
| Memory | 512 МБ |
| Swap | 512 МБ |
| CPU | 1 ядро |
| Network | Статический IP, мост `vmbr0` |
| Options | Start at boot ✅ · Unprivileged ✅ |

**Через community-script:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/debian.sh)"
```

---

## 2. Установка пакетов

```bash
apt update && apt upgrade -y
apt install -y icecast2 liquidsoap python3 python3-requests nano curl
```

При установке `icecast2` нажимайте **OK** на все вопросы — конфиг перезапишем на следующем шаге.

---

## 3. Создание папок

```bash
mkdir -p /etc/radio /var/log/liquidsoap /etc/liquidsoap
chown -R liquidsoap:liquidsoap /var/log/liquidsoap
```

---

## 4. Файл конфигурации

`/etc/radio/radio.conf`

```bash
NAV_URL="http://<IP_NAVIDROME>:<ПОРТ>"
NAV_USER="<ЛОГИН>"
NAV_PASS="<ПАРОЛЬ>"
TRACK_COUNT="600"
PLAYLIST_PATH="/etc/radio/radio.m3u"
CLIENT_ID="navidrome-radio"
```

```bash
chmod 600 /etc/radio/radio.conf
```

---

## 5. Установка скриптов

```bash
# Генератор плейлиста
cp scripts/gen_playlist.py /etc/radio/gen_playlist.py
chmod +x /etc/radio/gen_playlist.py

# Команда управления
cp scripts/radio /usr/local/bin/radio
chmod +x /usr/local/bin/radio

# Тест генерации плейлиста
python3 /etc/radio/gen_playlist.py
```

---

## 6. Настройка Icecast2

Замените содержимое `/etc/icecast2/icecast.xml` на `config/icecast.xml`, подставив:
- `<ICECAST_SOURCE_PASS>` — пароль, который Liquidsoap использует для отправки потока
- `<ICECAST_ADMIN_PASS>` — пароль админ-панели
- `<RADIO_IP>` — IP этого контейнера

```bash
systemctl restart icecast2
systemctl status icecast2   # должно быть: active (running)
```

---

## 7. Настройка Liquidsoap

Скопируйте `config/radio.liq` в `/etc/liquidsoap/radio.liq`, заменив `<ICECAST_SOURCE_PASS>` на тот же пароль, что в `icecast.xml`.

Проверьте синтаксис:

```bash
liquidsoap --check /etc/liquidsoap/radio.liq
```

---

## 8. Systemd-сервисы

```bash
cp systemd/radio-liquidsoap.service /etc/systemd/system/
cp systemd/radio-playlist.service   /etc/systemd/system/
cp systemd/radio-playlist.timer     /etc/systemd/system/

systemctl daemon-reload
systemctl enable icecast2 radio-liquidsoap radio-playlist.timer
```

---

## 9. Запуск

```bash
radio on
radio status
```

Поток: `http://<RADIO_IP>:8000/radio`

---

## Быстрые команды

```bash
radio on        # запустить поток
radio off       # остановить поток
radio restart   # перезапустить
radio status    # статус + текущий трек
radio update    # обновить плейлист вручную
radio logs      # логи в реальном времени
```
