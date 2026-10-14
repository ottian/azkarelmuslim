"""استيراد التلاوات مرة واحدة من mp3quran.net وتخزينها على السيرفر.

بعد الاستيراد مفيش أي اعتماد على خدمة خارجية: الإذاعة والتطبيق بيشتغلوا
من الملفات المحلية بس.

الاستخدام (جوه كونتينر الـ api):
    python importer.py list [--rewaya ID]     # يعرض القراء والروايات المتاحة
    python importer.py plan                    # يعرض اللي هيتنزل والمساحة المتوقعة
    python importer.py import                  # ينزل ويحوّل ويبني الفهرس والـ playlists
    python importer.py playlists               # يعيد بناء الفهرس والـ playlists بس
    python importer.py static --out catalog.json
        # فهرس لنسخة GitHub Pages: كل القراء والإذاعات، والصوت من سيرفرات mp3quran
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

API_BASE = os.environ.get("MP3QURAN_API", "https://mp3quran.net/api/v3")
MEDIA_DIR = Path(os.environ.get("MEDIA_DIR", "/media"))
LIBRARY_FILE = Path(os.environ.get("LIBRARY_FILE", "/config/library.json"))
LANGUAGE = os.environ.get("LIBRARY_LANGUAGE", "ar")
DOWNLOAD_WORKERS = int(os.environ.get("DOWNLOAD_WORKERS", "4"))
USER_AGENT = "azkarelmuslim-importer/1.0"

# متوسط مدة ختمة مرتلة بالساعات، للتقدير بس
AVG_KHATMA_HOURS = 28
CHANNEL_ID_RE = re.compile(r"^[a-z0-9_-]{1,32}$")


# ---------------------------------------------------------------- helpers

def normalize(text: str) -> str:
    """توحيد الأسماء العربية علشان المقارنة: من غير مسافات وتشكيل وهمزات."""
    text = re.sub(r"[ً-ْـ]", "", text)  # تشكيل وتطويل
    for src, dst in (("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ٱ", "ا"), ("ى", "ي"), ("ة", "ه")):
        text = text.replace(src, dst)
    return re.sub(r"\s+", "", text).lower()


def fetch_json(endpoint: str, **params) -> dict:
    params.setdefault("language", LANGUAGE)
    url = f"{API_BASE}/{endpoint}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return json.load(resp)
        except Exception as exc:  # noqa: BLE001
            if attempt == 3:
                raise RuntimeError(f"failed to fetch {url}: {exc}") from exc
            time.sleep(2 ** attempt)
    raise AssertionError("unreachable")


def load_library(path: Path = LIBRARY_FILE) -> dict:
    with path.open(encoding="utf-8") as fh:
        library = json.load(fh)
    for ch in library.get("channels", []):
        if not CHANNEL_ID_RE.match(ch.get("id", "")):
            raise ValueError(f"channel id must match {CHANNEL_ID_RE.pattern}: {ch.get('id')!r}")
    return library


def surah_list(moshaf: dict) -> list[int]:
    return [int(s) for s in str(moshaf.get("surah_list", "")).split(",") if s.strip().isdigit()]


def is_complete(moshaf: dict) -> bool:
    return len(set(surah_list(moshaf))) == 114


# ---------------------------------------------------------------- selection

def select_moshafs(library: dict, reciters: list[dict], riwayat: list[dict]) -> list[dict]:
    """يرجع قائمة المصاحف المختارة حسب library.json.

    كل عنصر: {reciter_id, reciter_name, moshaf: {...}}
    """
    flat = []
    for reciter in reciters:
        for moshaf in reciter.get("moshaf", []):
            flat.append({"reciter_id": reciter["id"], "reciter_name": reciter["name"], "moshaf": moshaf})

    chosen: dict[int, dict] = {}

    def add(entry: dict) -> None:
        chosen.setdefault(int(entry["moshaf"]["id"]), entry)

    for rule in library.get("reciters", []):
        style = normalize(rule.get("style", ""))
        complete_only = rule.get("complete_only", True)

        def ok(entry: dict, rewaya: int | None) -> bool:
            m = entry["moshaf"]
            if rewaya is not None and int(m.get("rewaya_id", -1)) != rewaya:
                return False
            if style and style not in normalize(m.get("name", "")):
                return False
            return not complete_only or is_complete(m)

        if "moshaf" in rule:
            for entry in flat:
                if int(entry["moshaf"]["id"]) == int(rule["moshaf"]):
                    add(entry)
        elif "reciter" in rule:
            wanted = normalize(rule["reciter"])
            matches = [e for e in flat if wanted in normalize(e["reciter_name"]) and ok(e, rule.get("rewaya"))]
            if not matches:
                print(f"  ! no moshaf found for {rule['reciter']!r}", file=sys.stderr)
            for entry in matches[: rule.get("count", 1)]:
                add(entry)
        elif "rewaya" in rule:
            matches = [e for e in flat if ok(e, int(rule["rewaya"]))]
            for entry in matches[: rule.get("count", 1)]:
                add(entry)
        elif "each_rewaya" in rule:
            excluded = set(rule.get("exclude_rewaya", []))
            excluded_names = [normalize(n) for n in rule.get("exclude_rewaya_names", [])]
            for rewaya in riwayat:
                rid = int(rewaya["id"])
                if rid in excluded or any(n in normalize(rewaya["name"]) for n in excluded_names):
                    continue
                matches = [e for e in flat if ok(e, rid)]
                for entry in matches[: int(rule["each_rewaya"])]:
                    add(entry)
    return list(chosen.values())


# ---------------------------------------------------------------- download

def audio_path(moshaf_id: int, surah: int) -> Path:
    return MEDIA_DIR / "audio" / str(moshaf_id) / f"{surah:03d}.mp3"


def free_gb(path: Path) -> float:
    path.mkdir(parents=True, exist_ok=True)
    return shutil.disk_usage(path).free / 1024 ** 3


def transcode(src: Path, dst: Path, bitrate: int) -> None:
    """تحويل لـ MP3 ثابت (CBR) مونو من غير tags، علشان الملفات تتوصل ببعض في بث واحد متصل."""
    tmp = dst.with_suffix(".part.mp3")
    cmd = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(src),
        "-vn", "-map_metadata", "-1", "-ac", "1", "-ar", "44100",
        "-c:a", "libmp3lame", "-b:a", f"{bitrate}k",
        "-write_xing", "0", "-id3v2_version", "0",
        str(tmp),
    ]
    subprocess.run(cmd, check=True)
    tmp.replace(dst)


def probe_duration(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", str(path)],
        check=True, capture_output=True, text=True,
    ).stdout.strip()
    try:
        return round(float(out), 1)
    except ValueError:
        return 0.0


def download_surah(server: str, moshaf_id: int, surah: int, bitrate: int, min_free: float) -> str:
    dst = audio_path(moshaf_id, surah)
    if dst.exists() and dst.stat().st_size > 0:
        return "skip"
    if free_gb(dst.parent) < min_free:
        raise RuntimeError(f"disk almost full (less than {min_free} GB free), stopping")
    url = urllib.parse.urljoin(server if server.endswith("/") else server + "/", f"{surah:03d}.mp3")
    with tempfile.TemporaryDirectory() as tmpdir:
        raw = Path(tmpdir) / "raw.mp3"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=120) as resp, raw.open("wb") as fh:
                    shutil.copyfileobj(resp, fh, 1024 * 256)
                break
            except Exception:  # noqa: BLE001
                if attempt == 3:
                    raise
                time.sleep(2 ** attempt)
        transcode(raw, dst, bitrate)
    return "ok"


def download_moshaf(entry: dict, bitrate: int, min_free: float) -> None:
    m = entry["moshaf"]
    mid = int(m["id"])
    surahs = surah_list(m)
    print(f"→ {entry['reciter_name']} | {m['name']} ({len(surahs)} سورة)")
    audio_path(mid, 1).parent.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(DOWNLOAD_WORKERS) as pool:
        futures = {pool.submit(download_surah, m["server"], mid, s, bitrate, min_free): s for s in surahs}
        done = 0
        for fut in concurrent.futures.as_completed(futures):
            fut.result()
            done += 1
            if done % 10 == 0 or done == len(surahs):
                print(f"   {done}/{len(surahs)}")


# ---------------------------------------------------------------- catalog & playlists

def build_catalog(library: dict, selection: list[dict], riwayat: list[dict], suwar: list[dict]) -> dict:
    """الفهرس اللي التطبيق بيقراه: بيشمل بس الملفات اللي موجودة فعلًا على الديسك."""
    rewaya_names = {int(r["id"]): r["name"] for r in riwayat}
    durations_file = MEDIA_DIR / "durations.json"
    durations: dict[str, float] = {}
    if durations_file.exists():
        durations = json.loads(durations_file.read_text(encoding="utf-8"))

    reciters: dict[int, dict] = {}
    for entry in selection:
        m = entry["moshaf"]
        mid = int(m["id"])
        present = []
        for s in sorted(set(surah_list(m))):
            p = audio_path(mid, s)
            if p.exists() and p.stat().st_size > 0:
                present.append(s)
                key = f"{mid}/{s}"
                if key not in durations:
                    durations[key] = probe_duration(p)
        if not present:
            continue
        r = reciters.setdefault(entry["reciter_id"], {"id": entry["reciter_id"], "name": entry["reciter_name"], "moshafs": []})
        r["moshafs"].append({
            "id": mid,
            "name": m["name"],
            "rewaya_id": int(m.get("rewaya_id", 0)),
            "rewaya_name": rewaya_names.get(int(m.get("rewaya_id", 0)), ""),
            "surahs": present,
            "durations": [durations.get(f"{mid}/{s}", 0.0) for s in present],
        })

    durations_file.write_text(json.dumps(durations), encoding="utf-8")
    used_riwayat = {m["rewaya_id"] for r in reciters.values() for m in r["moshafs"]}
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "station_name": library.get("station_name", "إذاعة أذكار المسلم"),
        "riwayat": [{"id": int(r["id"]), "name": r["name"]} for r in riwayat if int(r["id"]) in used_riwayat],
        "suwar": [{"id": int(s["id"]), "name": s["name"], "makkia": int(s.get("makkia", 0))} for s in suwar],
        "reciters": sorted(reciters.values(), key=lambda r: r["name"]),
        "channels": [],
    }


def _escape(value: str) -> str:
    return str(value).replace("\\", "").replace('"', "'").replace("\n", " ")


def channel_moshafs(channel: dict, catalog: dict) -> list[tuple[dict, dict]]:
    out = []
    excluded = set(channel.get("exclude_rewaya", []))
    for reciter in catalog["reciters"]:
        for m in reciter["moshafs"]:
            if "rewaya" in channel and m["rewaya_id"] != channel["rewaya"]:
                continue
            if m["rewaya_id"] in excluded:
                continue
            if "moshafs" in channel and m["id"] not in channel["moshafs"]:
                continue
            out.append((reciter, m))
    return out


def build_playlist(channel: dict, catalog: dict, media_root: str = "/media") -> list[str]:
    """ختمة متواصلة: كل سورة بصوت قارئ مختلف بالتناوب.

    بنعمل عدد ختمات قد عدد القراء، وكل ختمة بتبدأ بقارئ مختلف، علشان
    نفس السورة متتكررش بنفس الصوت كل مرة.
    """
    moshafs = channel_moshafs(channel, catalog)
    if not moshafs:
        return []
    surah_names = {s["id"]: s["name"] for s in catalog["suwar"]}
    lines = []
    for offset in range(len(moshafs)):
        for surah in range(1, 115):
            candidates = [(r, m) for r, m in moshafs if surah in m["surahs"]]
            if not candidates:
                continue
            reciter, m = candidates[(surah - 1 + offset) % len(candidates)]
            meta = {
                "title": f"سورة {surah_names.get(surah, surah)}",
                "artist": reciter["name"],
                "album": m["rewaya_name"] or m["name"],
                "surah": str(surah),
                "moshaf": str(m["id"]),
                "reciter": str(reciter["id"]),
            }
            annotations = ",".join(f'{k}="{_escape(v)}"' for k, v in meta.items())
            lines.append(f"annotate:{annotations}:{media_root}/audio/{m['id']}/{surah:03d}.mp3")
    return lines


def write_outputs(library: dict, catalog: dict) -> None:
    playlists_dir = MEDIA_DIR / "playlists"
    playlists_dir.mkdir(parents=True, exist_ok=True)
    active = []
    for channel in library.get("channels", []):
        lines = build_playlist(channel, catalog)
        path = playlists_dir / f"{channel['id']}.m3u"
        tmp = path.with_suffix(".tmp")
        tmp.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
        tmp.replace(path)
        if lines:
            active.append(channel)
            catalog["channels"].append({
                "id": channel["id"],
                "name": channel.get("name", channel["id"]),
                "description": channel.get("description", ""),
            })
        print(f"قناة {channel['id']}: {len(lines)} تلاوة")
    (playlists_dir / "channels.txt").write_text("\n".join(c["id"] for c in active) + "\n", encoding="utf-8")
    tmp = MEDIA_DIR / "catalog.json.tmp"
    tmp.write_text(json.dumps(catalog, ensure_ascii=False), encoding="utf-8")
    tmp.replace(MEDIA_DIR / "catalog.json")
    print(f"الفهرس: {len(catalog['reciters'])} قارئ، {sum(len(r['moshafs']) for r in catalog['reciters'])} مصحف")


# ---------------------------------------------------------------- commands

def remote_data() -> tuple[list[dict], list[dict], list[dict]]:
    reciters = fetch_json("reciters")["reciters"]
    riwayat = fetch_json("riwayat")["riwayat"]
    suwar = fetch_json("suwar")["suwar"]
    cache = MEDIA_DIR / "source"
    cache.mkdir(parents=True, exist_ok=True)
    for name, data in (("reciters", reciters), ("riwayat", riwayat), ("suwar", suwar)):
        (cache / f"{name}.json").write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return reciters, riwayat, suwar


def cached_data() -> tuple[list[dict], list[dict], list[dict]]:
    cache = MEDIA_DIR / "source"
    try:
        return tuple(json.loads((cache / f"{n}.json").read_text(encoding="utf-8")) for n in ("reciters", "riwayat", "suwar"))  # type: ignore[return-value]
    except FileNotFoundError:
        sys.exit("مفيش بيانات محفوظة، شغّل import الأول")


def cmd_list(args) -> None:
    reciters, riwayat, _ = remote_data()
    print("الروايات:")
    for r in riwayat:
        print(f"  {r['id']:>3}  {r['name']}")
    print("\nالمصاحف الكاملة:")
    for reciter in reciters:
        for m in reciter.get("moshaf", []):
            if args.rewaya and int(m.get("rewaya_id", -1)) != args.rewaya:
                continue
            if is_complete(m):
                print(f"  مصحف {m['id']:>4} | رواية {m.get('rewaya_id'):>3} | {reciter['name']} | {m['name']}")


def cmd_plan(_args) -> None:
    library = load_library()
    reciters, riwayat, _ = remote_data()
    selection = select_moshafs(library, reciters, riwayat)
    bitrate = int(library.get("bitrate_kbps", 64))
    for e in selection:
        print(f"  {e['reciter_name']} | {e['moshaf']['name']}")
    gb = len(selection) * AVG_KHATMA_HOURS * 3600 * bitrate * 1000 / 8 / 1024 ** 3
    print(f"\n{len(selection)} مصحف، المساحة المتوقعة حوالي {gb:.0f} جيجا، المتاح {free_gb(MEDIA_DIR):.0f} جيجا")


def cmd_import(_args) -> None:
    library = load_library()
    reciters, riwayat, suwar = remote_data()
    selection = select_moshafs(library, reciters, riwayat)
    bitrate = int(library.get("bitrate_kbps", 64))
    min_free = float(library.get("min_free_gb", 3))
    (MEDIA_DIR / "source" / "selection.json").write_text(json.dumps(selection, ensure_ascii=False), encoding="utf-8")
    try:
        for entry in selection:
            download_moshaf(entry, bitrate, min_free)
    finally:
        # حتى لو المساحة خلصت، نبني الفهرس باللي اتنزل
        catalog = build_catalog(library, selection, riwayat, suwar)
        write_outputs(library, catalog)


def cmd_playlists(_args) -> None:
    library = load_library()
    _, riwayat, suwar = cached_data()
    selection = json.loads((MEDIA_DIR / "source" / "selection.json").read_text(encoding="utf-8"))
    write_outputs(library, build_catalog(library, selection, riwayat, suwar))


def build_static_catalog(reciters: list[dict], riwayat: list[dict], suwar: list[dict], radios: list[dict],
                         featured: dict | None = None) -> dict:
    """فهرس نسخة GitHub Pages: مفيش سيرفر خاص، فكل مصحف معاه رابط ملفاته
    على mp3quran، والبث المباشر هو إذاعات mp3quran.

    لو featured موجود (server/featured.json) بناخد القراء والإذاعات اللي فيه بس، بنفس ترتيبه.
    """
    if featured:
        order = {int(r["id"]): i for i, r in enumerate(featured.get("reciters", []))}
        reciters = sorted((r for r in reciters if int(r["id"]) in order), key=lambda r: order[int(r["id"])])
        missing = set(order) - {int(r["id"]) for r in reciters}
        if missing:
            print(f"  ! reciters not found on mp3quran: {sorted(missing)}", file=sys.stderr)
        radio_order = {name.strip(): i for i, name in enumerate(featured.get("radios", []))}
        radios = sorted((r for r in radios if r["name"].strip() in radio_order), key=lambda r: radio_order[r["name"].strip()])
    rewaya_names = {int(r["id"]): r["name"] for r in riwayat}
    out = []
    for reciter in reciters:
        moshafs = []
        for m in reciter.get("moshaf", []):
            surahs = sorted(set(surah_list(m)))
            server = str(m.get("server", ""))
            if not surahs or not server.startswith("https://"):
                continue
            moshafs.append({
                "id": int(m["id"]),
                "name": m["name"],
                "rewaya_id": int(m.get("rewaya_id", 0)),
                "rewaya_name": rewaya_names.get(int(m.get("rewaya_id", 0)), ""),
                "server": server if server.endswith("/") else server + "/",
                "surahs": surahs,
            })
        if moshafs:
            out.append({"id": int(reciter["id"]), "name": reciter["name"], "moshafs": moshafs})
    used = {m["rewaya_id"] for r in out for m in r["moshafs"]}
    channels = [
        {"id": f"radio-{r['id']}", "name": r["name"].strip(), "description": "", "stream_url": r["url"]}
        for r in radios
        if str(r.get("url", "")).startswith("https://")
    ]
    return {
        "mode": "static",
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "station_name": "إذاعة أذكار المسلم",
        "riwayat": [{"id": int(r["id"]), "name": r["name"]} for r in riwayat if int(r["id"]) in used],
        "suwar": [{"id": int(s["id"]), "name": s["name"], "makkia": int(s.get("makkia", 0))} for s in suwar],
        "reciters": out if featured else sorted(out, key=lambda r: r["name"]),
        "channels": channels,
    }


def cmd_static(args) -> None:
    catalog = build_static_catalog(
        fetch_json("reciters")["reciters"],
        fetch_json("riwayat")["riwayat"],
        fetch_json("suwar")["suwar"],
        fetch_json("radios")["radios"],
        json.loads(Path(args.featured).read_text(encoding="utf-8")) if args.featured else None,
    )
    if len(catalog["reciters"]) < 10 or len(catalog["suwar"]) != 114:
        sys.exit("الفهرس ناقص، مش هنكتبه")
    Path(args.out).write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{len(catalog['reciters'])} قارئ، {sum(len(r['moshafs']) for r in catalog['reciters'])} مصحف، {len(catalog['channels'])} إذاعة")


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p_list = sub.add_parser("list")
    p_list.add_argument("--rewaya", type=int)
    p_list.set_defaults(func=cmd_list)
    sub.add_parser("plan").set_defaults(func=cmd_plan)
    sub.add_parser("import").set_defaults(func=cmd_import)
    sub.add_parser("playlists").set_defaults(func=cmd_playlists)
    p_static = sub.add_parser("static")
    p_static.add_argument("--out", required=True)
    p_static.add_argument("--featured", help="server/featured.json: القراء والإذاعات اللي تظهر بس")
    p_static.set_defaults(func=cmd_static)
    args = parser.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
