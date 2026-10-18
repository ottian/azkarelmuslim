import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// أندرويد وويندوز: ملفات في فولدر التطبيق
class OfflineBackend {
  Directory? _dir;

  Future<void> init() async {
    final base = await getApplicationSupportDirectory();
    _dir = Directory('${base.path}${Platform.pathSeparator}offline');
    await _dir!.create(recursive: true);
  }

  String _path(String key) => '${_dir!.path}${Platform.pathSeparator}$key.mp3';

  String? localFile(String key) {
    if (_dir == null) return null;
    final f = File(_path(key));
    return f.existsSync() ? f.path : null;
  }

  Future<void> download(String url, String key, void Function(int got, int? total) onProgress) async {
    final client = http.Client();
    final part = File('${_path(key)}.part');
    try {
      final resp = await client.send(http.Request('GET', Uri.parse(url)));
      if (resp.statusCode != 200) throw HttpException('HTTP ${resp.statusCode}');
      final sink = part.openWrite();
      var got = 0;
      try {
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          got += chunk.length;
          onProgress(got, resp.contentLength);
        }
      } finally {
        await sink.close();
      }
      await part.rename(_path(key));
    } catch (_) {
      if (await part.exists()) await part.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> delete(String url, String key) async {
    final f = File(_path(key));
    if (await f.exists()) await f.delete();
  }
}
