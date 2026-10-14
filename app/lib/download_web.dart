import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> downloadText(String name, String text, String mime) async {
  final blob = web.Blob([text.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(a);
  a.click();
  a.remove();
  return true;
}
