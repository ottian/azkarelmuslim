import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// عنوان السيرفر بيتحدد وقت البناء:
///   flutter build apk --dart-define=SERVER_URL=https://radio.example.com
/// ونسخة الويب بتستخدم نفس الدومين اللي متفتحة منه.
const _buildServerUrl = String.fromEnvironment('SERVER_URL');
const _serverKey = 'server_url';

class Api {
  Api(this._prefs);

  final SharedPreferences _prefs;
  final _client = http.Client();

  String get baseUrl {
    if (kIsWeb) return Uri.base.origin;
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

  Uri url(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _get(String path) async {
    final resp = await _client.get(url(path)).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw ApiException('السيرفر رد بـ ${resp.statusCode}');
    }
    return jsonDecode(utf8.decode(resp.bodyBytes));
  }

  Future<Catalog> catalog() async =>
      Catalog.fromJson(await _get('/api/catalog') as Map<String, dynamic>);

  Future<List<LiveChannel>> live() async => (await _get('/api/live') as List)
      .cast<Map<String, dynamic>>()
      .map(LiveChannel.fromJson)
      .toList();
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
