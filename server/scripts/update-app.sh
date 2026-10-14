#!/usr/bin/env bash
# ينزّل آخر نسخة من التطبيقات (ويب، أندرويد، ويندوز) من GitHub Releases
# ويحطها على السيرفر: الويب في data/web والملفات في data/downloads
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="${REPO:-ottian/azkarelmuslim}"
TAG="${1:-latest}"

if [[ "$TAG" == latest ]]; then
  api="https://api.github.com/repos/$REPO/releases/latest"
else
  api="https://api.github.com/repos/$REPO/releases/tags/$TAG"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "==> بنجيب بيانات الإصدار $TAG"
curl -fsSL "$api" -o "$tmp/release.json"
urls=$(grep -o '"browser_download_url": *"[^"]*"' "$tmp/release.json" | cut -d'"' -f4)
if [[ -z "$urls" ]]; then
  echo "مفيش ملفات في الإصدار ده" >&2
  exit 1
fi

for url in $urls; do
  echo "   ↓ $(basename "$url")"
  curl -fsSL "$url" -o "$tmp/$(basename "$url")"
done

if [[ -f "$tmp/azkar-web.tar.gz" ]]; then
  echo "==> تحديث تطبيق الويب"
  rm -rf data/web.new && mkdir -p data/web.new
  tar -xzf "$tmp/azkar-web.tar.gz" -C data/web.new
  rm -rf data/web.old
  [[ -d data/web ]] && mv data/web data/web.old
  mv data/web.new data/web
  rm -rf data/web.old
fi

mkdir -p data/downloads
for f in "$tmp"/*.apk "$tmp"/*windows*.zip; do
  [[ -e "$f" ]] || continue
  echo "==> $(basename "$f") → data/downloads"
  cp "$f" data/downloads/
done

# Caddy شايل فولدر الويب، لازم نعيد تشغيله علشان يشوف الفولدر الجديد
docker compose restart caddy >/dev/null
echo "تم ✅"
