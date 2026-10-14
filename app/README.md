# تطبيق إذاعة أذكار المسلم (Flutter)

أندرويد وويندوز وويب (الآيفون بيستخدم نسخة الويب من Safari).

- `lib/api.dart`: الاتصال بالسيرفر. العنوان من `--dart-define=SERVER_URL=...` أو من الإعدادات، والويب بيستخدم نفس الدومين.
- `lib/player.dart`: التشغيل. اللايف بيرجع لوحده لو النت فصل، والويب بيشغّل الشيخ كبث واحد متصل علشان الآيفون.
- `lib/screens/`: الشاشات (مباشر، القراء، المفضلة، الإعدادات).

```bash
flutter pub get
flutter analyze && flutter test
flutter build web --release --no-web-resources-cdn
flutter build apk --release --dart-define=SERVER_URL=https://radio.example.com
flutter build windows --release --dart-define=SERVER_URL=https://radio.example.com
```
