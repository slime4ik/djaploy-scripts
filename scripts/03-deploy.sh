#!/usr/bin/env bash
# djaploy — ШАГ 3: клон репозитория и запуск контейнеров.
#
#   REPO  — твой репозиторий вида owner/name (подставляется автоматически)
#   TOKEN — короткоживущий токен GitHub App; в URL и в логи НЕ попадает
set -e

REPO="owner/name"
DIR="/opt/djaploy/${REPO##*/}"

mkdir -p /opt/djaploy
rm -rf "$DIR"               # чистим ТОЛЬКО нашу папку этого проекта, больше ничего

# Токен передаётся в заголовке Authorization (base64 от "x-access-token:TOKEN"),
# а НЕ в URL — поэтому он не светится ни в логах, ни в истории команд.
git -c http.extraheader="AUTHORIZATION: basic <base64(x-access-token:TOKEN)>" \
    clone --depth 1 "https://github.com/${REPO}.git" "$DIR"

# в проекте должен быть docker-compose.yml (или compose.yml)
test -f "$DIR/docker-compose.yml" || test -f "$DIR/compose.yml" || { echo "NO_COMPOSE"; exit 7; }

# Сборка и запуск. Для веб-приложений добавляем наш overlay с Caddy (HTTPS).
# Для ботов/воркеров — только твой docker-compose.yml.
cd "$DIR"
docker compose -f docker-compose.yml -f docker-compose.caddy.yml up -d --build --remove-orphans

echo "Контейнеры собраны и запущены."
