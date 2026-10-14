"""API إذاعة أذكار المسلم.

  GET /api/health                    → حالة السيرفر
  GET /api/catalog                   → القراء والروايات والسور والقنوات
  GET /api/live                      → القنوات اللايف وبيتقري إيه دلوقتي وعدد المستمعين
  GET /api/play/<moshaf>?from=N&to=M → السور ورا بعض كبث MP3 واحد متصل
                                       (للآيفون: التشغيل في الخلفية مش بيقف بين السور)

الملفات نفسها (/media/audio/...) بيقدمها Caddy مباشرة.
"""

from __future__ import annotations

import json
import os
import re
import time
import urllib.request
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

MEDIA_DIR = Path(os.environ.get("MEDIA_DIR", "/media"))
STATE_DIR = Path(os.environ.get("STATE_DIR", "/state"))
ICECAST_STATUS_URL = os.environ.get("ICECAST_STATUS_URL", "http://icecast:8000/status-json.xsl")
STREAM_PREFIX = os.environ.get("STREAM_PREFIX", "/stream")
BITRATE_KBPS = int(os.environ.get("BITRATE_KBPS", "64"))
# أول كام ثانية بتتبعت بسرعة علشان التشغيل يبدأ فورًا، وبعدها بنبعت أسرع
# من سرعة التشغيل بشوية بس، علشان منصرفش باندويدث على حاجة محدش هيسمعها
BURST_SECONDS = int(os.environ.get("PLAY_BURST_SECONDS", "30"))
PACE_FACTOR = float(os.environ.get("PLAY_PACE_FACTOR", "1.5"))
CHUNK = 16 * 1024

MOSHAF_RE = re.compile(r"^/api/play/(\d{1,6})/?$")


class Catalog:
    """بيقرا catalog.json ويعيد تحميله لو اتغير."""

    def __init__(self, path: Path):
        self.path = path
        self._mtime = 0.0
        self._data: dict = {}
        self._raw = b"{}"

    def get(self) -> tuple[dict, bytes]:
        try:
            mtime = self.path.stat().st_mtime
        except FileNotFoundError:
            empty = {"station_name": "", "riwayat": [], "suwar": [], "reciters": [], "channels": []}
            return empty, json.dumps(empty).encode()
        if mtime != self._mtime:
            raw = self.path.read_bytes()
            self._data = json.loads(raw)
            self._raw = raw
            self._mtime = mtime
        return self._data, self._raw

    def moshaf(self, moshaf_id: int) -> dict | None:
        data, _ = self.get()
        for reciter in data.get("reciters", []):
            for m in reciter.get("moshafs", []):
                if m["id"] == moshaf_id:
                    return {**m, "reciter_name": reciter["name"]}
        return None


catalog = Catalog(MEDIA_DIR / "catalog.json")
_listeners_cache: dict = {"at": 0.0, "data": {}}


def icecast_listeners() -> dict[str, int]:
    if time.time() - _listeners_cache["at"] < 5:
        return _listeners_cache["data"]
    result: dict[str, int] = {}
    try:
        with urllib.request.urlopen(ICECAST_STATUS_URL, timeout=2) as resp:
            # Icecast ساعات بيطلع JSON فيه "title": - بايظ لو مفيش عنوان
            text = resp.read().decode("utf-8", "replace").replace('"title": -', '"title": null')
        sources = json.loads(text).get("icestats", {}).get("source", [])
        if isinstance(sources, dict):
            sources = [sources]
        for src in sources:
            mount = urlparse(src.get("listenurl", "")).path.lstrip("/")
            result[mount] = int(src.get("listeners", 0))
    except Exception:  # noqa: BLE001
        pass
    _listeners_cache.update(at=time.time(), data=result)
    return result


def now_playing(channel_id: str) -> dict | None:
    try:
        return json.loads((STATE_DIR / f"nowplaying-{channel_id}.json").read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def live_channels() -> list[dict]:
    data, _ = catalog.get()
    listeners = icecast_listeners()
    return [
        {
            **ch,
            "stream_url": f"{STREAM_PREFIX}/{ch['id']}",
            "listeners": listeners.get(ch["id"], 0),
            "now": now_playing(ch["id"]),
        }
        for ch in data.get("channels", [])
    ]


class Handler(BaseHTTPRequestHandler):
    server_version = "azkar-api/1.0"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # noqa: N802
        if os.environ.get("API_ACCESS_LOG") == "1":
            super().log_message(fmt, *args)

    def _send_json(self, body: bytes | dict | list, status: int = 200, cache: int = 0) -> None:
        if not isinstance(body, bytes):
            body = json.dumps(body, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", f"public, max-age={cache}" if cache else "no-store")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _error(self, status: int, message: str) -> None:
        self._send_json({"error": message}, status)

    def do_HEAD(self):  # noqa: N802
        self.do_GET()

    def do_GET(self):  # noqa: N802
        url = urlparse(self.path)
        path = url.path
        if path == "/api/health":
            self._send_json({"ok": True})
        elif path == "/api/catalog":
            _, raw = catalog.get()
            self._send_json(raw, cache=300)
        elif path == "/api/live":
            self._send_json(live_channels())
        elif m := MOSHAF_RE.match(path):
            self._play(int(m.group(1)), parse_qs(url.query))
        else:
            self._error(HTTPStatus.NOT_FOUND, "not found")

    def _play(self, moshaf_id: int, query: dict) -> None:
        moshaf = catalog.moshaf(moshaf_id)
        if not moshaf:
            return self._error(HTTPStatus.NOT_FOUND, "moshaf not found")
        try:
            start = int(query.get("from", ["1"])[0])
            end = int(query.get("to", ["114"])[0])
        except ValueError:
            return self._error(HTTPStatus.BAD_REQUEST, "from/to must be numbers")
        surahs = [s for s in moshaf["surahs"] if start <= s <= end]
        if not surahs:
            return self._error(HTTPStatus.NOT_FOUND, "no surahs in range")
        files = [MEDIA_DIR / "audio" / str(moshaf_id) / f"{s:03d}.mp3" for s in surahs]
        files = [f for f in files if f.is_file()]

        self.send_response(200)
        self.send_header("Content-Type", "audio/mpeg")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Accept-Ranges", "none")
        self.send_header("Content-Length", str(sum(f.stat().st_size for f in files)))
        self.end_headers()
        if self.command == "HEAD":
            return

        bytes_per_sec = BITRATE_KBPS * 1000 / 8
        burst = bytes_per_sec * BURST_SECONDS
        started = time.monotonic()
        sent = 0
        try:
            for f in files:
                with f.open("rb") as fh:
                    while chunk := fh.read(CHUNK):
                        self.wfile.write(chunk)
                        sent += len(chunk)
                        if sent > burst:
                            ahead = (sent - burst) / (bytes_per_sec * PACE_FACTOR) - (time.monotonic() - started)
                            if ahead > 0:
                                time.sleep(ahead)
        except (BrokenPipeError, ConnectionResetError):
            pass


def main() -> None:
    port = int(os.environ.get("PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    server.daemon_threads = True
    print(f"azkar api listening on :{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
