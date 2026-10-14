#!/usr/bin/env bash
# تركيب إذاعة أذكار المسلم على Ubuntu 24.04 (Oracle Cloud Ampere A1)
#
#   sudo ./install.sh                         # من غير دومين، على الـ IP
#   sudo ./install.sh radio.example.com you@example.com   # بدومين و HTTPS
#
# السكريبت آمن إنك تشغله أكتر من مرة.
set -euo pipefail

cd "$(dirname "$0")"

DOMAIN="${1:-}"
EMAIL="${2:-admin@localhost}"

if [[ $EUID -ne 0 ]]; then
  echo "شغّل السكريبت بـ sudo" >&2
  exit 1
fi

echo "==> تركيب Docker"
if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-v2
  systemctl enable --now docker
fi
if [[ -n "${SUDO_USER:-}" ]]; then
  usermod -aG docker "$SUDO_USER" || true
fi

echo "==> فتح البورتات 80 و 443"
# صور Ubuntu بتاعة Oracle فيها iptables بيرفض أي بورت غير 22.
# (لازم كمان تفتحهم في Security List من لوحة Oracle)
open_port() {
  local proto=$1 port=$2
  if ! iptables -C INPUT -p "$proto" --dport "$port" -j ACCEPT 2>/dev/null; then
    iptables -I INPUT -p "$proto" --dport "$port" -j ACCEPT
  fi
}
open_port tcp 80
open_port tcp 443
open_port udp 443
if command -v netfilter-persistent >/dev/null; then
  netfilter-persistent save
fi

echo "==> إعداد .env"
public_ip() {
  curl -4 -fsS -m 5 https://ifconfig.me 2>/dev/null
}
if [[ ! -f .env ]]; then
  cp .env.example .env
  sed -i "s|^ICECAST_SOURCE_PASSWORD=.*|ICECAST_SOURCE_PASSWORD=$(openssl rand -hex 16)|" .env
  sed -i "s|^ICECAST_ADMIN_PASSWORD=.*|ICECAST_ADMIN_PASSWORD=$(openssl rand -hex 16)|" .env
  chmod 600 .env
fi
if [[ -n "$DOMAIN" ]]; then
  sed -i "s|^SITE_ADDRESS=.*|SITE_ADDRESS=$DOMAIN|; s|^PUBLIC_HOST=.*|PUBLIC_HOST=$DOMAIN|; s|^ACME_EMAIL=.*|ACME_EMAIL=$EMAIL|" .env
else
  ip="$(public_ip || true)"
  if [[ -n "$ip" ]]; then
    sed -i "s|^PUBLIC_HOST=.*|PUBLIC_HOST=$ip|" .env
  fi
fi

echo "==> تجهيز الفولدرات"
mkdir -p data/media/audio data/media/playlists data/state data/web data/downloads
# Liquidsoap بيشتغل بيوزر رقمه 100
chown -R 100:101 data/state data/media/playlists
if [[ ! -f data/web/index.html ]]; then
  cat > data/web/index.html <<'HTML'
<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><title>إذاعة أذكار المسلم</title>
<body style="font-family:sans-serif;text-align:center;padding:3em">
<h1>إذاعة أذكار المسلم</h1>
<audio controls src="/stream/main" preload="none"></audio>
<p>التطبيق لسه بيتجهز، شغّل scripts/update-app.sh</p>
</body></html>
HTML
fi

echo "==> تشغيل الإذاعة"
docker compose up -d --build

host="$(grep '^PUBLIC_HOST=' .env | cut -d= -f2)"
scheme=http
[[ -n "$DOMAIN" ]] && scheme=https
cat <<EOF

تم التركيب ✅

الخطوة الجاية: تنزيل التلاوات مرة واحدة (بياخد وقت، سيبه شغال):
  cd $(pwd)
  sudo docker compose run --rm api python3 importer.py plan     # يوريك هينزل إيه والمساحة
  sudo docker compose run --rm api python3 importer.py import   # ينزل ويبني الإذاعة
  sudo docker compose restart liquidsoap

وبعدين نزّل التطبيق على السيرفر:
  sudo ./scripts/update-app.sh

الإذاعة:      $scheme://$host/
البث المباشر: $scheme://$host/stream/main
EOF
