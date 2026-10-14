#!/usr/bin/env python3
"""بينزّل صوت الأذان وصور القراء من ويكيميديا كومنز ويحطهم في الريبو.

بيتشغّل مرة واحدة يدوي (مش في كل بناء)، والملفات الناتجة بتترفع مع الكود:
  app/assets/audio/adhan.mp3                      الأذان (ويندوز والويب)
  app/android/app/src/main/res/raw/adhan.mp3      صوت إشعار الأذان على أندرويد
  server/photos/<id>.jpg                          صور القراء (مربعة 240 على وش الشيخ)
  server/photos/credits.json                      أصحاب الصور ورخصها

محتاج ffmpeg.  python3 scripts/fetch_media.py
"""
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UA = {"User-Agent": "azkarelmuslim/1.0 (https://github.com/ottian/azkarelmuslim)"}
API = "https://commons.wikimedia.org/w/api.php"

# أذان كامل (دقيقتين ونص تقريبًا)، رخصة CC0
ADHAN = {
    "file": "Beautiful adhan.ogg",
    "sha256": "35fe06b08fe80505c550c33fed8a783fa9901ddc81ac884958b4be048f5b2a79",
}


def get(url, raw=False):
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                b = r.read()
                return b if raw else json.loads(b)
        except Exception as e:  # ويكيميديا ساعات بترجع 429
            if attempt == 4:
                raise
            print(f"  retry ({e})", file=sys.stderr)
            time.sleep(5 * (attempt + 1))


def imageinfo(name, width=None):
    q = {"action": "query", "titles": "File:" + name, "prop": "imageinfo",
         "iiprop": "url|extmetadata", "format": "json"}
    if width:
        q["iiurlwidth"] = width
    pages = get(API + "?" + urllib.parse.urlencode(q))["query"]["pages"]
    return list(pages.values())[0]["imageinfo"][0]


def plain(html):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", html or "")).strip()


def fetch_adhan():
    info = imageinfo(ADHAN["file"])
    data = get(info["url"], raw=True)
    digest = hashlib.sha256(data).hexdigest()
    if digest != ADHAN["sha256"]:
        sys.exit(f"adhan sha256 mismatch: {digest}")
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "adhan.ogg"
        src.write_bytes(data)
        for out in [ROOT / "app/assets/audio/adhan.mp3",
                    ROOT / "app/android/app/src/main/res/raw/adhan.mp3"]:
            out.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src),
                            "-ac", "1", "-ar", "44100", "-b:a", "64k", "-map_metadata", "-1",
                            str(out)], check=True)
            print("wrote", out.relative_to(ROOT), out.stat().st_size)


def square(src, dst, focus):
    """قص مربع حوالين الوش: focus = [مركز x, مركز y, حجم المربع] كنسبة من الصورة"""
    cx, cy, size = focus
    crop = (f"crop=w='min(iw,ih)*{size}':h='min(iw,ih)*{size}'"
            f":x='clip(iw*{cx}-ow/2,0,iw-ow)':y='clip(ih*{cy}-oh/2,0,ih-oh)'")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src),
                    "-vf", f"{crop},scale=240:240",
                    "-q:v", "3", str(dst)], check=True)


def fetch_photos():
    featured = json.loads((ROOT / "server/featured.json").read_text(encoding="utf-8"))
    folder = ROOT / "server/photos"
    folder.mkdir(parents=True, exist_ok=True)
    focus = featured.get("photo_focus", {})
    credits = {}
    for old in folder.glob("*.*"):
        old.unlink()
    tmp = Path(tempfile.mkdtemp())
    for rid, name in featured["photos"].items():
        time.sleep(2)
        info = imageinfo(name, width=320)
        md = info.get("extmetadata", {})
        url = info.get("thumburl") or info["url"]
        ext = Path(urllib.parse.urlparse(url).path).suffix.lower() or ".jpg"
        time.sleep(1)
        src = tmp / f"{rid}{ext}"
        src.write_bytes(get(url, raw=True))
        square(src, folder / f"{rid}.jpg", focus.get(rid, [0.5, 0.35, 1.0]))
        credits[rid] = {
            "file": name,
            "page": info.get("descriptionurl", ""),
            "artist": plain(md.get("Artist", {}).get("value")),
            "license": plain(md.get("LicenseShortName", {}).get("value")),
        }
        print("photo", rid, credits[rid]["license"], credits[rid]["artist"])
    (folder / "credits.json").write_text(
        json.dumps(credits, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    fetch_adhan()
    fetch_photos()
