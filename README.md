# إذاعة أذكار المسلم

إذاعة قرآن كريم لايف 24 ساعة، ومعاها مكتبة تختار منها الشيخ والرواية والسورة.
كل حاجة مستضافة على سيرفرك (Oracle Cloud Always Free) من غير أي خدمة خارجية،
وفيه تطبيق للأندرويد والويندوز، ونسخة ويب للآيفون تتضاف للشاشة الرئيسية.

```
                ┌──────────── سيرفر Oracle (Ubuntu 24.04 ARM) ────────────┐
                │                                                          │
 الموبايل  ───► │  Caddy (80/443) ─┬─► /stream/*  ─► Icecast ◄─ Liquidsoap │
 والكمبيوتر     │                  ├─► /api/*     ─► API (Python)          │
                │                  ├─► /media/audio/*  (ملفات السور)        │
                │                  └─► /  تطبيق الويب                       │
                └──────────────────────────────────────────────────────────┘
```

## محتوى الريبو

| الفولدر | فيه إيه |
|---|---|
| `server/` | السيرفر كله بـ Docker: Icecast للبث، Liquidsoap للجدول 24 ساعة، API، و Caddy |
| `server/api/importer.py` | بينزّل التلاوات **مرة واحدة** من mp3quran.net ويحوّلها ويبني الإذاعة |
| `server/library.json` | القراء والروايات اللي هتتنزل، والقنوات اللايف |
| `app/` | تطبيق Flutter: أندرويد وويندوز وويب |
| `.github/workflows/` | بيبني التطبيقات تلقائي ويعمل Release |
| `docs/` | خطوات إنشاء السيرفر على Oracle |

## 1. تجهيز السيرفر

1. اعمل السيرفر على Oracle بالخطوات اللي في [docs/oracle-instance.md](docs/oracle-instance.md).
2. ادخل عليه بـ SSH ونزّل الريبو وشغّل التركيب:

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/ottian/azkarelmuslim.git
cd azkarelmuslim/server

# من غير دومين (هيشتغل على الـ IP):
sudo ./install.sh
# أو بدومين و HTTPS (لازم الدومين يشاور على IP السيرفر الأول):
sudo ./install.sh radio.example.com you@example.com
```

السكريبت بيركّب Docker، ويفتح بورتات 80 و443، ويعمل باسوردات عشوائية في `server/.env`، ويشغّل الإذاعة.

## 2. تنزيل التلاوات (مرة واحدة)

```bash
cd ~/azkarelmuslim/server
sudo docker compose run --rm api python3 importer.py plan     # هينزّل إيه والمساحة المتوقعة
sudo docker compose run --rm api python3 importer.py import   # ينزّل ويبني الإذاعة (بياخد ساعات)
sudo docker compose restart liquidsoap
```

- التلاوات بتتحول لـ MP3 مونو 64kbps، الختمة المرتلة حوالي 0.6 لـ 0.9 جيجا.
- لو المساحة قربت تخلص الاستيراد بيقف لوحده (`min_free_gb` في `library.json`) وبيبني الإذاعة باللي اتنزل.
- لو وقف لأي سبب شغّله تاني، هيكمّل من مكان ما وقف.
- علشان تشوف كل القراء والروايات المتاحة: `importer.py list` أو `importer.py list --rewaya 2`

### تعديل القراء والقنوات (`server/library.json`)

```jsonc
"reciters": [
  { "reciter": "مشاري العفاسي", "rewaya": 1, "style": "مرتل" },   // شيخ بالاسم
  { "moshaf": 123 },                                              // مصحف برقمه من importer.py list
  { "rewaya": 2, "count": 2 },                                    // أول مصحفين كاملين برواية معينة
  { "each_rewaya": 1, "exclude_rewaya": [1] }                     // مصحف من كل رواية
],
"channels": [
  { "id": "main", "name": "البث الرئيسي", "rewaya": 1 },           // قناة لرواية معينة
  { "id": "qiraat", "name": "إذاعة القراءات", "exclude_rewaya": [1] },
  { "id": "afasy", "name": "العفاسي", "moshafs": [123] }          // قناة لمصاحف معينة
]
```

بعد التعديل: `importer.py import` لو فيه قراء جداد، أو `importer.py playlists` لو غيرت القنوات بس، وبعدين `docker compose restart liquidsoap`.

كل قناة بتشتغل ختمة متواصلة، كل سورة بصوت قارئ مختلف بالتناوب، ورابطها `http(s)://السيرفر/stream/<id>`.

## 3. التطبيقات

### بناء التطبيقات
GitHub Actions بيبني التطبيقات تلقائي. قبل أول بناء:
- **Settings > Secrets and variables > Actions > Variables**: ضيف `SERVER_URL` بعنوان السيرفر (مثلًا `https://radio.example.com` أو `http://1.2.3.4`).
- (اختياري) مفتاح توقيع الأندرويد في الـ Secrets، التفاصيل في أول [apps.yml](.github/workflows/apps.yml). من غيره الـ APK بيتوقّع بمفتاح debug، وده بيشتغل عادي بس مينفعش يترفع على Google Play.

علشان تطلع نسخة: اعمل tag
```bash
git tag v1.0.0 && git push origin v1.0.0
```
وبعد ما الـ Release يخلص، على السيرفر:
```bash
sudo ./scripts/update-app.sh
```
ده بيحط تطبيق الويب على السيرفر، وملفات الأندرويد والويندوز في `http(s)://السيرفر/downloads/`.

### على كل جهاز
| الجهاز | إزاي |
|---|---|
| **أندرويد** | نزّل `azkar-android.apk` من `/downloads/` وثبّته. بيكمل في الخلفية وفيه أزرار في الإشعارات وشاشة القفل |
| **ويندوز** | نزّل `azkar-windows.zip`، فكّه، وشغّل `azkar_radio.exe` |
| **آيفون** | افتح عنوان السيرفر في **Safari** ← زرار المشاركة ← **Add to Home Screen**. بيكمل في الخلفية والشاشة مقفولة |

> على الآيفون الاستماع لشيخ معين بيتبعت كبث واحد متصل (`/api/play/<مصحف>?from=<سورة>`) علشان Safari ميوقفش بين السور في الخلفية.
> الآيفون محتاج HTTPS علشان يتعامل كتطبيق كامل، يعني محتاج دومين.

## 4. حدود Oracle Always Free

| | الحد | ملاحظة |
|---|---|---|
| الباندويدث | 10 تيرا في الشهر | البث 64kbps = حوالي 21 جيجا لكل مستمع شغال طول الشهر، يعني حوالي **480 مستمع في نفس الوقت** |
| المساحة | 200 جيجا للحساب كله | الختمة المرتلة حوالي 0.8 جيجا |
| أقصى عدد مستمعين | `ICECAST_MAX_LISTENERS` في `.env` (500) | |

> Oracle ممكن تسحب السيرفر المجاني لو استهلاكه فضل قليل جدًا 7 أيام. الحل المضمون ترقية الحساب لـ Pay As You Go (الموارد المجانية بتفضل مجانية) مع Budget alert بصفر.

## أوامر مفيدة

```bash
sudo docker compose ps                  # حالة الخدمات
sudo docker compose logs -f liquidsoap  # بيتقري إيه دلوقتي
curl http://localhost/api/live          # القنوات وعدد المستمعين
git pull && sudo docker compose up -d --build   # تحديث السيرفر
```

## التطوير

```bash
# اختبارات السيرفر
cd server/api && python3 -m unittest

# التطبيق
cd app
flutter pub get
flutter run -d chrome                                   # ويب (لازم السيرفر يكون على نفس الدومين)
flutter run -d windows --dart-define=SERVER_URL=http://IP
flutter test
```

## المصادر والحقوق

- التلاوات من [mp3quran.net](https://mp3quran.net). قبل التشغيل للعامة لازم تاخد إذن منهم لإعادة البث.
- الخطوط: Noto Sans Arabic و Noto Sans (رخصة SIL Open Font License، في `app/assets/fonts/LICENSE-noto.txt`).
