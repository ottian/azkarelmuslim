/// مفيش حفظ على المنصة دي
class OfflineBackend {
  Future<void> init() async {}

  String? localFile(String key) => null;

  Future<void> download(String url, String key, void Function(int got, int? total) onProgress) =>
      throw UnsupportedError('offline');

  Future<void> delete(String url, String key) async {}
}
