import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// عنوان السيرفر بيتحدد وقت البناء:
///   flutter build apk --dart-define=SERVER_URL=https://ottian.github.io/azkarelmuslim
/// ونسخة الويب بتستخدم نفس العنوان اللي متفتحة منه.
///
/// العنوان ممكن يكون:
///  - GitHub Pages: فيه catalog.json بس، والصوت والإذاعات من mp3quran
///  - سيرفرنا (server/): فيه /api و /stream و /media
const _buildServerUrl = String.fromEnvironment('SERVER_URL');
const _serverKey = 'server_url';

class Api {
  Api(this._prefs);

  final SharedPreferences _prefs;
  SharedPreferences get prefs => _prefs;
  final _client = http.Client();

  String get baseUrl {
    if (kIsWeb) {
      // فولدر الصفحة من غير الملف والـ query، مثلًا https://ottian.github.io/azkarelmuslim
      final path = Uri.base.path;
      return Uri.base.origin + path.substring(0, path.lastIndexOf('/'));
    }
    final saved = _prefs.getString(_serverKey);
    if (saved != null && saved.isNotEmpty) return saved;
    return _buildServerUrl;
  }

  bool get isConfigured => baseUrl.isNotEmpty;

  /// السيرفر ممكن يتغير من الإعدادات في تطبيق الأندرويد والويندوز
  bool get canChangeServer => !kIsWeb;

  Future<void> setBaseUrl(String url) async {
    var clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.isNotEmpty && !clean.startsWith('http')) clean = 'http://$clean';
    await _prefs.setString(_serverKey, clean);
  }

  /// الروابط الكاملة بترجع زي ما هي، و "x" بتتحسب من فولدر التطبيق، و "/x" من أول الدومين
  Uri url(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return Uri.parse(path);
    return Uri.parse('$baseUrl/').resolve(path);
  }

  Future<dynamic> _get(String path) async {
    final resp = await _client.get(url(path)).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw ApiException('السيرفر رد بـ ${resp.statusCode}');
    }
    return jsonDecode(utf8.decode(resp.bodyBytes));
  }

  /// الأول بندور على catalog.json (GitHub Pages)، ولو مش موجود نسأل الـ API.
  /// آخر فهرس اتحمّل بيتحفظ، علشان المحفوظ في مكتبتي يشتغل من غير نت.
  Future<Catalog> catalog() async {
    try {
      final data = await _fetchCatalog();
      await _prefs.setString(_catalogCacheKey, jsonEncode(data));
      return Catalog.fromJson(data);
    } catch (e) {
      final cached = _prefs.getString(_catalogCacheKey);
      if (cached == null) rethrow;
      return Catalog.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
  }

  static const _catalogCacheKey = 'catalog_cache';

  Future<Map<String, dynamic>> _fetchCatalog() async {
    try {
      final data = await _get('catalog.json');
      if (data is Map<String, dynamic> && data['mode'] == 'static') return data;
    } catch (_) {
      // مش GitHub Pages
    }
    return await _get('/api/catalog') as Map<String, dynamic>;
  }

  /// أصحاب صور القراء ورخصها (scripts/fetch_media.py)
  Future<Map<String, dynamic>> photoCredits() async =>
      (await _get('photos/credits.json') as Map).cast<String, dynamic>();

  Future<List<LiveChannel>> live(Catalog? catalog) async {
    if (catalog != null && catalog.isStatic) return catalog.channels;
    return (await _get('/api/live') as List)
        .cast<Map<String, dynamic>>()
        .map(LiveChannel.fromJson)
        .toList();
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
