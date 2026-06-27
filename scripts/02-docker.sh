#!/usr/bin/env bash
# djaploy — ШАГ 2: Docker (ставим, только если ещё нет) + зеркала реестра.
set -e

if ! command -v docker >/dev/null 2>&1; then
  # на свежих серверах фоновый unattended-upgrades держит apt-замок — ждём, иначе
  # установка падает с "Could not get lock /var/lib/dpkg/lock-frontend".
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "apt занят (фоновое обновление системы) — жду освобождения замка…"; sleep 5
  done
  echo "Docker не найден — устанавливаю официальный скрипт get.docker.com…"
  curl -fsSL https://get.docker.com | sh
fi

# зеркала реестра + надёжный DNS (8.8.8.8/1.1.1.1) — чтобы образы тянулись стабильнее,
# а сборка резолвила имена даже при кривом DNS провайдера (частая беда RU-серверов).
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{ "registry-mirrors": ["https://mirror.gcr.io", "https://dockerhub.timeweb.cloud"], "userland-proxy": false, "dns": ["8.8.8.8", "1.1.1.1"] }
JSON
systemctl restart docker || true

# проверяем, что плагин compose на месте
docker compose version >/dev/null 2>&1 || { echo "плагин docker compose недоступен"; exit 42; }
echo "Docker готов."
