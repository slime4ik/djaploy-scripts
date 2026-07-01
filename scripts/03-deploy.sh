#!/usr/bin/env bash
# djaploy — ШАГ 3: клон репозитория и запуск контейнеров.
#
#   REPO  — твой репозиторий вида owner/name (подставляется автоматически)
#   TOKEN — короткоживущий токен GitHub App; в URL и в логи НЕ попадает
set -e

REPO="owner/name"
NAME="${REPO##*/}"
DIR="/opt/djaploy/$NAME"

mkdir -p /opt/djaploy
rm -rf "$DIR"               # чистим ТОЛЬКО нашу папку этого проекта, больше ничего

# Токен передаётся в заголовке Authorization (base64 от "x-access-token:TOKEN"),
# а НЕ в URL — поэтому он не светится ни в логах, ни в истории команд.
git -c http.extraheader="AUTHORIZATION: basic <base64(x-access-token:TOKEN)>" \
    clone --depth 1 "https://github.com/${REPO}.git" "$DIR"

# в проекте должен быть docker-compose.yml (или compose.yml)
test -f "$DIR/docker-compose.yml" || test -f "$DIR/compose.yml" || { echo "NO_COMPOSE"; exit 7; }

cd "$DIR"

# Собираем и поднимаем. Для веба поверх твоего compose кладём наш overlay
# docker-compose.caddy.yml — сам Caddy он НЕ содержит: HTTPS раздаёт ОДИН общий
# Caddy-шлюз на сервер (см. Caddyfile.example и README). Overlay лишь добавляет
# опциональный мониторинг и bind-volume'ы под статику/медиа. Бот/воркер — только
# твой docker-compose.yml, без overlay.
docker compose -f docker-compose.yml -f docker-compose.caddy.yml up -d --build --remove-orphans

# Веб-проект цепляем к общей docker-сети шлюза "djaploy" под алиасом app-<repo> —
# так общий Caddy находит контейнер по имени и проксирует на него, без публикации
# host-портов (за 80/443 сайты не дерутся). Бота/воркера не цепляем — у него нет
# входящих портов. ("web" ниже — имя твоего сервиса из compose, по умолчанию web.)
CID=$(docker compose -f docker-compose.yml -f docker-compose.caddy.yml ps -q web | head -1)
docker network connect --alias "app-$NAME" djaploy "$CID"

echo "Контейнеры собраны и запущены."
