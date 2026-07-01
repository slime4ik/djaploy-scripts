#!/usr/bin/env bash
# djaploy — ШАГ 4 (опционально, по твоему выбору): отдельный non-root пользователь.
# Чтобы повторные деплои и авто-деплой (CD) шли НЕ под root.
# ВАЖНО: твой root-доступ при этом не меняется — мы его не трогаем.
set -e

USER="deploy"               # имя выбираешь ты в форме
DIR="/opt/djaploy/<repo>"

# создаём пользователя (если ещё нет) и даём доступ к Docker без sudo
id -u "$USER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$USER"
getent group docker >/dev/null 2>&1 && usermod -aG docker "$USER" || true

# отдельный SSH-ключ ТОЛЬКО для деплоя.
# Приватную часть храним у себя в зашифрованном виде; на сервер кладём только публичную.
mkdir -p "/home/$USER/.ssh" && chmod 700 "/home/$USER/.ssh"
echo "<публичный-ключ-деплоя>" >> "/home/$USER/.ssh/authorized_keys"
chmod 600 "/home/$USER/.ssh/authorized_keys"
chown -R "$USER:$USER" "/home/$USER/.ssh"

# передаём этому пользователю владение папкой проекта
chown -R "$USER:$USER" "$DIR"
# и папкой общего Caddy-шлюза — чтобы non-root мог обновлять его конфиг при деплоях
chown -R "$USER:$USER" /opt/djaploy/_gateway 2>/dev/null || true

echo "Готово — дальнейшие деплои идут под '$USER', root не тронут."
