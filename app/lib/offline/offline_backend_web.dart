import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// الويب: الملف بيتحفظ في Cache Storage بنفس رابطه، و web/sw.js بيرد منه
class OfflineBackend {
  static const _cache = 'quran-audio';

  Future<void> init() async {
    // علشان المتصفح ميمسحش المحفوظ لو المساحة قلت
    try {
      await web.window.navigator.storage.persist().toDart;
    } catch (_) {}
  }

  String? localFile(String key) => null;

  Future<void> download(String url, String key, void Function(int got, int? total) onProgress) async {
    final resp = await web.window.fetch(url.toJS).toDart;
    if (!resp.ok) throw Exception('HTTP ${resp.status}');
    final total = int.tryParse(resp.headers.get('content-length') ?? '');
    final reader = resp.body!.getReader() as web.ReadableStreamDefaultReader;
    final chunks = <JSAny>[];
    var got = 0;
    while (true) {
      final r = await reader.read().toDart;
      if (r.done) break;
      final chunk = r.value as JSUint8Array;
      chunks.add(chunk);
      got += chunk.toDart.lengthInBytes;
      onProgress(got, total);
    }
    final blob = web.Blob(chunks.toJS, web.BlobPropertyBag(type: 'audio/mpeg'));
    final cache = await web.window.caches.open(_cache).toDart;
    final headers = web.Headers()
      ..set('Content-Type', 'audio/mpeg')
      ..set('Content-Length', '${blob.size}');
    await cache.put(url.toJS, web.Response(blob, web.ResponseInit(status: 200, headers: headers))).toDart;
  }

  Future<void> delete(String url, String key) async {
    final cache = await web.window.caches.open(_cache).toDart;
    await cache.delete(url.toJS).toDart;
  }
}
