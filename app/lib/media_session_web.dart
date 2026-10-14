import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// اسم السورة والشيخ في شاشة القفل، وزراير السورة اللي بعدها واللي قبلها
void setMediaSession({
  required String title,
  required String artist,
  String album = '',
  void Function()? onNext,
  void Function()? onPrevious,
}) {
  try {
    final session = web.window.navigator.mediaSession;
    session.metadata = web.MediaMetadata(web.MediaMetadataInit(
      title: title,
      artist: artist,
      album: album,
      artwork: [
        web.MediaImage(src: 'icons/Icon-512.png', sizes: '512x512', type: 'image/png'),
      ].toJS,
    ));
    session.setActionHandler('nexttrack', onNext == null ? null : (() => onNext()).toJS);
    session.setActionHandler('previoustrack', onPrevious == null ? null : (() => onPrevious()).toJS);
  } catch (_) {
    // المتصفح مش بيدعم Media Session
  }
}
