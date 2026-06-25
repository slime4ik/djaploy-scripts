#!/usr/bin/env bash
# djaploy — ШАГ (опционально): приватный VPN до сервера на AmneziaWG.
#
# AmneziaWG = WireGuard + обфускация (junk-пакеты, рандомизация заголовков), чтобы
# не блокировался DPI в РФ. Нужен, чтобы закрыть приватные разделы (напр. /admin,
# /grafana) — снаружи 404, через VPN открываются.
#
# ВАЖНО: приватные ключи генерируются ЗДЕСЬ, на твоём сервере, и наружу не уходят.
# Мы храним у себя только клиентский конфиг для скачивания (его создаёшь ты же).
set -e
export DEBIAN_FRONTEND=noninteractive

# 1) зависимости + заголовки ядра (AmneziaWG ставится DKMS-модулем под текущее ядро)
apt-get install -y software-properties-common curl iproute2 || true
apt-get install -y "linux-headers-$(uname -r)" || apt-get install -y linux-headers-generic || true

# 2) репозиторий AmneziaWG. На очень свежих Ubuntu у PPA может не быть пакетов под
#    наш релиз — нормализуем кодовое имя на LTS noble (DKMS соберётся под наше ядро),
#    чтобы не отравлять apt битым репозиторием.
add-apt-repository -y ppa:amnezia/ppa || true
for f in /etc/apt/sources.list.d/*amnezia*; do
  [ -f "$f" ] && sed -ri 's#(/ppa/ubuntu) +[a-z][a-z0-9]+ #\1 noble #; s/^(Suites:).*/\1 noble/' "$f" || true
done
apt-get update -y || true
apt-get install -y amneziawg amneziawg-tools

# 3) ключи (генерируются на сервере, приватные не покидают его)
WGDIR=/etc/amnezia/amneziawg
mkdir -p "$WGDIR"; cd "$WGDIR"; umask 077
[ -f server_private.key ] || awg genkey | tee server_private.key | awg pubkey > server_public.key
[ -f client_private.key ] || awg genkey | tee client_private.key | awg pubkey > client_public.key

# 4) сначала снимаем НАШ старый туннель (если остался) и подбираем свободный UDP-порт
#    (51820..51830) — чтобы ужиться с любым другим VPN на сервере и не падать с
#    "Address already in use".
systemctl stop awg-quick@awg0 2>/dev/null || true
awg-quick down awg0 2>/dev/null || true
ip link delete awg0 2>/dev/null || true
sleep 1
PORT=51820
for p in $(seq 51820 51830); do
  ss -uln 2>/dev/null | grep -qE ":$p[[:space:]]" || { PORT=$p; break; }
done

# 5) конфиг сервера: адрес 10.8.0.1/24, выбранный порт, NAT наружу, параметры обфускации
#    (Jc/Jmin/Jmax/S1/S2/H1..H4 — junk-пакеты и рандомизация заголовков против DPI).
#    Здесь — упрощённо; реальные ключи/значения генерируются на сервере при провижне.
cat > "$WGDIR/awg0.conf" <<CONF
[Interface]
Address = 10.8.0.1/24
ListenPort = $PORT
PrivateKey = <server_private>
Jc = 4
Jmin = 40
Jmax = 70
S1 = 50
S2 = 100
H1 = <rand>
H2 = <rand>
H3 = <rand>
H4 = <rand>
PostUp   = iptables -I FORWARD -i awg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o <ext_if> -j MASQUERADE
PostDown = iptables -D FORWARD -i awg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o <ext_if> -j MASQUERADE

[Peer]
PublicKey = <client_public>
AllowedIPs = 10.8.0.2/32
CONF
chmod 600 "$WGDIR/awg0.conf"

# 6) включаем форвардинг и открываем выбранный UDP-порт
sysctl -w net.ipv4.ip_forward=1 || true
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-djaploy-wg.conf
command -v ufw >/dev/null 2>&1 && ufw allow "$PORT"/udp || true
iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$PORT" -j ACCEPT

# 7) поднимаем туннель
systemctl enable awg-quick@awg0 || true
awg-quick up awg0
awg show awg0 >/dev/null && echo "VPN поднят."

# Клиентский конфиг (wg-client.conf) кладётся в папку проекта — его ты скачиваешь
# на странице деплоя и импортируешь в приложение AmneziaVPN.
