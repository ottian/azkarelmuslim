import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_backend_stub.dart'
    if (dart.library.io) 'offline_backend_io.dart'
    if (dart.library.js_interop) 'offline_backend_web.dart';

/// سورة محفوظة على الجهاز
class SavedSurah {
  const SavedSurah({required this.moshafId, required this.surah, required this.url, required this.at});

  final int moshafId;
  final int surah;

  /// رابط الملف الأصلي (على الويب هو نفسه مفتاح الحفظ)
  final String url;
  final DateTime at;

  String get key => offlineKey(moshafId, surah);

  Map<String, dynamic> toJson() => {'m': moshafId, 's': surah, 'u': url, 't': at.millisecondsSinceEpoch};

  static SavedSurah? fromJson(Object? j) {
    if (j is! Map) return null;
    final m = j['m'], s = j['s'], u = j['u'], t = j['t'];
    if (m is! int || s is! int || u is! String) return null;
    return SavedSurah(moshafId: m, surah: s, url: u, at: DateTime.fromMillisecondsSinceEpoch(t is int ? t : 0));
  }
}

String offlineKey(int moshafId, int surah) => '$moshafId-$surah';

/// السور اللي المستخدم حفظها في مكتبته علشان يسمعها من غير نت.
///
/// أندرويد وويندوز: الملف بيتنزّل في فولدر التطبيق وبيشتغل منه.
/// الويب (الآيفون): الملف بيتحفظ في Cache Storage، والـ service worker (web/sw.js)
/// بيرد على رابط السورة من المحفوظ.
class OfflineStore extends ChangeNotifier {
  OfflineStore(this.prefs) {
    try {
      final raw = prefs.getString(_key);
      if (raw != null) {
        saved = (jsonDecode(raw) as List).map(SavedSurah.fromJson).whereType<SavedSurah>().toList();
      }
    } catch (_) {}
  }

  static const _key = 'offline_surahs';

  final SharedPreferences prefs;
  final _backend = OfflineBackend();

  /// الأحدث الأول
  List<SavedSurah> saved = [];

  /// نسبة التنزيل (0..1، أو null لو الحجم مش معروف) للسور اللي بتتنزّل دلوقتي
  final Map<String, double?> downloading = {};

  late final Future<void> ready = _backend.init().catchError((Object e) => debugPrint('offline init: $e'));

  bool isSaved(int moshafId, int surah) => saved.any((e) => e.moshafId == moshafId && e.surah == surah);

  bool isDownloading(int moshafId, int surah) => downloading.containsKey(offlineKey(moshafId, surah));

  double? progressOf(int moshafId, int surah) => downloading[offlineKey(moshafId, surah)];

  /// مسار الملف على أندرويد وويندوز (على الويب دايمًا null)
  String? localFile(int moshafId, int surah) =>
      isSaved(moshafId, surah) ? _backend.localFile(offlineKey(moshafId, surah)) : null;

  /// بينزّل السورة ويضيفها للمكتبة. بيرجّع رسالة الخطأ لو فشل.
  Future<String?> save(int moshafId, int surah, String url) async {
    final key = offlineKey(moshafId, surah);
    if (isSaved(moshafId, surah) || downloading.containsKey(key)) return null;
    downloading[key] = 0;
    notifyListeners();
    try {
      await ready;
      await _backend.download(url, key, (got, total) {
        downloading[key] = total == null || total <= 0 ? null : got / total;
        notifyListeners();
      });
      saved = [SavedSurah(moshafId: moshafId, surah: surah, url: url, at: DateTime.now()), ...saved];
      await _persist();
      return null;
    } catch (e) {
      debugPrint('download failed: $e');
      return 'مقدرتش أنزّل السورة، اتأكد من النت وجرب تاني';
    } finally {
      downloading.remove(key);
      notifyListeners();
    }
  }

  Future<void> remove(int moshafId, int surah) async {
    final item = saved.where((e) => e.moshafId == moshafId && e.surah == surah).firstOrNull;
    if (item == null) return;
    saved = saved.where((e) => e != item).toList();
    await _persist();
    notifyListeners();
    try {
      await ready;
      await _backend.delete(item.url, item.key);
    } catch (e) {
      debugPrint('offline delete: $e');
    }
  }

  Future<void> _persist() => prefs.setString(_key, jsonEncode(saved.map((e) => e.toJson()).toList()));
}
