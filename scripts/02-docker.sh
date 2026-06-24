#!/usr/bin/env bash
# djaploy — ШАГ 2: Docker (ставим, только если ещё нет) + зеркала реестра.
set -e

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker не найден — устанавливаю официальный скрипт get.docker.com…"
  curl -fsSL https://get.docker.com | sh
fi

# зеркала реестра — чтобы образы тянулись стабильнее
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{ "registry-mirrors": ["https://mirror.gcr.io", "https://dockerhub.timeweb.cloud"], "userland-proxy": false }
JSON
systemctl restart docker || true

# проверяем, что плагин compose на месте
docker compose version >/dev/null 2>&1 || { echo "плагин docker compose недоступен"; exit 42; }
echo "Docker готов."
