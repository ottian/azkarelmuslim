import unittest

import importer


def moshaf(mid, rewaya, name="حفص عن عاصم - مرتل", surahs=range(1, 115)):
    return {"id": mid, "name": name, "rewaya_id": rewaya, "server": "https://x/", "surah_list": ",".join(map(str, surahs))}


RECITERS = [
    {"id": 1, "name": "مشاري العفاسي", "moshaf": [moshaf(10, 1), moshaf(11, 12, "الدوري عن الكسائي - مرتل", [1, 2])]},
    {"id": 2, "name": "عبد الباسط عبد الصمد", "moshaf": [moshaf(20, 1), moshaf(21, 1, "حفص عن عاصم - مجود")]},
    {"id": 3, "name": "قارئ ورش", "moshaf": [moshaf(30, 2, "ورش عن نافع - مرتل")]},
    {"id": 4, "name": "قارئ معلم", "moshaf": [moshaf(40, 19, "المصحف المعلم")]},
]
RIWAYAT = [{"id": 1, "name": "حفص عن عاصم"}, {"id": 2, "name": "ورش عن نافع"}, {"id": 19, "name": "المصحف المعلم"}]


class SelectTest(unittest.TestCase):
    def test_normalize_ignores_spaces_and_hamza(self):
        self.assertEqual(importer.normalize("عبد الباسط"), importer.normalize("عبدالباسط"))
        self.assertEqual(importer.normalize("أحمد"), importer.normalize("احمد"))

    def test_by_reciter_name_and_style(self):
        lib = {"reciters": [{"reciter": "عبدالباسط عبدالصمد", "rewaya": 1, "style": "مرتل"}]}
        ids = [e["moshaf"]["id"] for e in importer.select_moshafs(lib, RECITERS, RIWAYAT)]
        self.assertEqual(ids, [20])

    def test_each_rewaya_skips_excluded_and_incomplete(self):
        lib = {"reciters": [{"each_rewaya": 1, "exclude_rewaya": [1], "exclude_rewaya_names": ["المعلم"]}]}
        ids = [e["moshaf"]["id"] for e in importer.select_moshafs(lib, RECITERS, RIWAYAT)]
        self.assertEqual(ids, [30])

    def test_no_duplicates(self):
        lib = {"reciters": [{"moshaf": 10}, {"reciter": "العفاسي", "rewaya": 1}]}
        ids = [e["moshaf"]["id"] for e in importer.select_moshafs(lib, RECITERS, RIWAYAT)]
        self.assertEqual(ids, [10])


class PlaylistTest(unittest.TestCase):
    def catalog(self):
        return {
            "suwar": [{"id": i, "name": f"س{i}"} for i in range(1, 115)],
            "reciters": [
                {"id": 1, "name": "أ", "moshafs": [{"id": 10, "name": "x", "rewaya_id": 1, "rewaya_name": "حفص", "surahs": list(range(1, 115))}]},
                {"id": 2, "name": "ب", "moshafs": [{"id": 20, "name": "y", "rewaya_id": 1, "rewaya_name": "حفص", "surahs": list(range(1, 115))}]},
                {"id": 3, "name": "ج", "moshafs": [{"id": 30, "name": "z", "rewaya_id": 2, "rewaya_name": "ورش", "surahs": [1]}]},
            ],
        }

    def test_rotates_reciters_and_covers_every_surah(self):
        lines = importer.build_playlist({"id": "main", "rewaya": 1}, self.catalog())
        self.assertEqual(len(lines), 2 * 114)
        first, second = lines[0], lines[114]
        self.assertTrue(first.endswith("/media/audio/10/001.mp3"))
        self.assertTrue(second.endswith("/media/audio/20/001.mp3"))
        self.assertIn('surah="1"', first)

    def test_exclude_rewaya(self):
        lines = importer.build_playlist({"id": "q", "exclude_rewaya": [1]}, self.catalog())
        self.assertEqual(len(lines), 1)
        self.assertTrue(lines[0].endswith("/media/audio/30/001.mp3"))

    def test_annotation_escapes_quotes(self):
        cat = self.catalog()
        cat["reciters"][0]["name"] = 'a"b'
        line = importer.build_playlist({"id": "m", "moshafs": [10]}, cat)[0]
        self.assertIn("artist=\"a'b\"", line)


class StaticCatalogTest(unittest.TestCase):
    def test_static_catalog_keeps_audio_server_and_radios(self):
        suwar = [{"id": i, "name": f"س{i}"} for i in range(1, 115)]
        radios = [
            {"id": 1, "name": " إذاعة ", "url": "https://backup.qurango.net/radio/x"},
            {"id": 2, "name": "قديمة", "url": "http://insecure/radio"},
        ]
        cat = importer.build_static_catalog(RECITERS, RIWAYAT, suwar, radios)
        self.assertEqual(cat["mode"], "static")
        m = cat["reciters"][0]["moshafs"][0]
        self.assertTrue(m["server"].endswith("/"))
        self.assertEqual(cat["channels"], [{"id": "radio-1", "name": "إذاعة", "description": "", "stream_url": "https://backup.qurango.net/radio/x"}])


if __name__ == "__main__":
    unittest.main()
