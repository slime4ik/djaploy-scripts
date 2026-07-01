#!/usr/bin/env bash
# djaploy — что мы делаем, когда ты УДАЛЯЕШЬ проект. Три режима, выбираешь ты.
#
# Прозрачно: мы трогаем ТОЛЬКО то, что сами разворачивали. Твои чужие данные,
# другие проекты и системные настройки — не касаемся.

REPO="owner/name"
NAME="${REPO##*/}"
DIR="/opt/djaploy/$NAME"
GW="/opt/djaploy/_gateway"
COMPOSE="docker compose -f docker-compose.yml -f docker-compose.caddy.yml"

# ─────────────────────────────────────────────────────────────────────────────
# Режим 1 — ОТВЯЗАТЬ: ничего на сервере не трогаем, убираем проект только из
# дашборда. Контейнеры продолжают работать, ты сам управляешь сервером дальше.
#   (на сервере НЕ выполняется ничего)

# ─────────────────────────────────────────────────────────────────────────────
# Режим 2 — ОСТАНОВИТЬ (teardown): гасим контейнеры, но ДАННЫЕ (volumes/БД) целы.
cd "$DIR" && $COMPOSE down --remove-orphans || true

# ─────────────────────────────────────────────────────────────────────────────
# Режим 3 — УДАЛИТЬ ПОЛНОСТЬЮ (purge): «как будто нас и не было».
cd "$DIR" && $COMPOSE down -v --rmi local --remove-orphans || true   # контейнеры + volumes (данные!) + собранные образы
rm -rf "$DIR"                                            # папка проекта

# убираем наш ключ доступа из authorized_keys (больше не сможем зайти)
grep -vF "<наш-публичный-ключ>" "$HOME/.ssh/authorized_keys" > "$HOME/.ssh/authorized_keys.tmp" \
  && mv "$HOME/.ssh/authorized_keys.tmp" "$HOME/.ssh/authorized_keys" || true

# если поднимали VPN — полностью сносим его (интерфейс, автозапуск, конфиг, порт)
SUDO=""; [ "$(id -u)" = "0" ] || SUDO="sudo -n"
$SUDO systemctl disable --now awg-quick@awg0 2>/dev/null || true
$SUDO awg-quick down awg0 2>/dev/null || true
$SUDO ip link delete awg0 2>/dev/null || true
$SUDO rm -rf /etc/amnezia/amneziawg /etc/sysctl.d/99-djaploy-wg.conf 2>/dev/null || true
# порт VPN мог быть автоподобран (51820..51830) — чистим весь диапазон
for pp in $(seq 51820 51830); do
  $SUDO iptables -D INPUT -p udp --dport "$pp" -j ACCEPT 2>/dev/null || true
  $SUDO ufw delete allow "$pp"/udp 2>/dev/null || true
done

# ─────────────────────────────────────────────────────────────────────────────
# Снимаем сайт с ОБЩЕГО Caddy-шлюза (и при остановке, и при полном удалении) —
# просто удаляем его сниппет. Остальные сайты на сервере продолжают работать,
# как будто этого и не было. Если сайт был последним — гасим шлюз целиком (reload
# на пустом конфиге бы упал). Ботов/воркеров не касается — у них сниппета нет.
rm -f "$GW/sites/$NAME.caddy"
if [ -n "$(ls -A "$GW/sites" 2>/dev/null)" ]; then
  (cd "$GW" && docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile) 2>/dev/null || true
else
  (cd "$GW" && docker compose down) 2>/dev/null || true
fi

# Что мы НЕ трогаем даже при полном удалении: Docker и системные пакеты (вдруг
# нужны другим проектам), твой root-доступ, другие папки и данные на сервере.
echo "Проект удалён — на сервере не осталось ничего нашего."
