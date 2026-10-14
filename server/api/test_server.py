import json
import os
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

TMP = tempfile.TemporaryDirectory()
os.environ["MEDIA_DIR"] = TMP.name
os.environ["STATE_DIR"] = TMP.name
os.environ["ICECAST_STATUS_URL"] = "http://127.0.0.1:9/none"

import server  # noqa: E402


class ServerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        media = Path(TMP.name)
        (media / "audio" / "7").mkdir(parents=True)
        for s, data in ((1, b"A" * 100), (2, b"B" * 50), (3, b"C" * 10)):
            (media / "audio" / "7" / f"{s:03d}.mp3").write_bytes(data)
        catalog = {
            "station_name": "test",
            "riwayat": [],
            "suwar": [],
            "reciters": [{"id": 1, "name": "x", "moshafs": [{"id": 7, "name": "m", "rewaya_id": 1, "surahs": [1, 2, 3]}]}],
            "channels": [{"id": "main", "name": "main", "description": ""}],
        }
        (media / "catalog.json").write_text(json.dumps(catalog))
        (media / "nowplaying-main.json").write_text(json.dumps({"title": "t", "surah": "2"}))
        cls.httpd = server.ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        cls.base = f"http://127.0.0.1:{cls.httpd.server_address[1]}"
        threading.Thread(target=cls.httpd.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()

    def get(self, path):
        with urllib.request.urlopen(self.base + path, timeout=5) as resp:
            return resp.status, resp.headers, resp.read()

    def test_catalog(self):
        _, _, body = self.get("/api/catalog")
        self.assertEqual(json.loads(body)["reciters"][0]["id"], 1)

    def test_live_includes_now_playing(self):
        _, _, body = self.get("/api/live")
        ch = json.loads(body)[0]
        self.assertEqual(ch["stream_url"], "/stream/main")
        self.assertEqual(ch["now"]["surah"], "2")

    def test_play_concatenates_range(self):
        status, headers, body = self.get("/api/play/7?from=2")
        self.assertEqual(status, 200)
        self.assertEqual(headers["Content-Type"], "audio/mpeg")
        self.assertEqual(body, b"B" * 50 + b"C" * 10)

    def test_play_unknown_moshaf(self):
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            self.get("/api/play/99")
        self.assertEqual(ctx.exception.code, 404)

    def test_path_traversal_rejected(self):
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            self.get("/api/play/..%2f..%2fetc")
        self.assertEqual(ctx.exception.code, 404)


if __name__ == "__main__":
    unittest.main()
