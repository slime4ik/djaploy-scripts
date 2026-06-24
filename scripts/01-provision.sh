#!/usr/bin/env bash
# djaploy — ШАГ 1: подготовка сервера (fail2ban + базовый фаервол).
# Выполняется один раз при первом деплое. Это реальные команды нашего движка.
set -e
export DEBIAN_FRONTEND=noninteractive

# не валимся, если споткнулся СТОРОННИЙ репозиторий (напр. свежий PPA без пакетов
# под новую Ubuntu) — нужные пакеты лежат в основном репозитории Ubuntu, он доступен.
apt-get update -y || echo "(apt-get update частично не прошёл — продолжаю)"
apt-get install -y fail2ban curl ca-certificates git

# fail2ban: бан IP после 5 неудачных попыток SSH на 1 час
cat > /etc/fail2ban/jail.local <<'INI'
[sshd]
enabled = true
maxretry = 5
bantime = 1h
INI
systemctl enable --now fail2ban
systemctl restart fail2ban

# открываем HTTP/HTTPS на локальном фаерволе (нужно Caddy и Let's Encrypt).
# Облачный фаервол (если есть) настраиваешь ты сам.
if command -v ufw >/dev/null 2>&1; then
  ufw allow 80/tcp  || true
  ufw allow 443/tcp || true
fi

echo "Сервер подготовлен, fail2ban активен."
