import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'api.dart';
import 'models.dart';

sealed class Playback {
  const Playback();
}

class LivePlayback extends Playback {
  const LivePlayback(this.channel);
  final LiveChannel channel;
}

class MoshafPlayback extends Playback {
  const MoshafPlayback(this.moshaf, this.startSurah);
  final Moshaf moshaf;
  final int startSurah;
}

/// بيشغّل اللايف أو مصحف شيخ معين، وبيكمل في الخلفية.
///
/// على الويب (الآيفون) المصحف بيتشغّل كبث واحد متصل من /api/play علشان
/// Safari ميوقفش بين السور والشاشة مقفولة. على الأندرويد والويندوز
/// بيتشغّل كقائمة ملفات علشان التقديم والترجيع.
class PlayerController extends ChangeNotifier {
  PlayerController(this._api) {
    _subs.add(player.playerStateStream.listen(_onState));
    _subs.add(player.currentIndexStream.listen((_) => _updateSurah()));
    _subs.add(player.positionStream.listen((_) {
      if (kIsWeb) _updateSurah();
    }));
  }

  final Api _api;
  final AudioPlayer player = AudioPlayer();
  final List<StreamSubscription> _subs = [];

  Playback? playback;
  int? currentSurah;
  String? error;
  Catalog? catalog;
  DateTime? sleepAt;
  Timer? _sleepTimer;
  Timer? _reconnect;

  bool get isLive => playback is LivePlayback;
  bool get continuousStream => kIsWeb;

  Future<void> playLive(LiveChannel channel) async {
    playback = LivePlayback(channel);
    currentSurah = null;
    await _load(AudioSource.uri(
      _api.url(channel.streamUrl),
      tag: MediaItem(
        id: 'live-${channel.id}',
        title: channel.name,
        artist: 'إذاعة أذكار المسلم - بث مباشر',
      ),
    ));
  }

  Future<void> playMoshaf(Moshaf moshaf, int surah) async {
    playback = MoshafPlayback(moshaf, surah);
    currentSurah = surah;
    final reciter = moshaf.reciter.name;
    if (continuousStream) {
      await _load(AudioSource.uri(
        _api.url('/api/play/${moshaf.id}?from=$surah'),
        tag: MediaItem(
          id: 'moshaf-${moshaf.id}-$surah',
          title: reciter,
          artist: moshaf.label,
          album: 'إذاعة أذكار المسلم',
        ),
      ));
    } else {
      final sources = [
        for (final s in moshaf.surahs)
          AudioSource.uri(
            _api.url(moshaf.audioPath(s)),
            tag: MediaItem(
              id: 'moshaf-${moshaf.id}-$s',
              title: 'سورة ${catalog?.surahName(s) ?? s}',
              artist: reciter,
              album: moshaf.label,
            ),
          ),
      ];
      final index = moshaf.surahs.indexOf(surah);
      await _load(null, sources: sources, initialIndex: index < 0 ? 0 : index);
    }
  }

  Future<void> _load(AudioSource? source,
      {List<AudioSource>? sources, int initialIndex = 0}) async {
    _reconnect?.cancel();
    error = null;
    notifyListeners();
    try {
      if (source != null) {
        await player.setAudioSource(source);
      } else {
        await player.setAudioSources(sources!, initialIndex: initialIndex);
      }
      unawaited(player.play());
    } on PlayerException catch (e) {
      error = 'مش قادر يشغّل: ${e.message ?? e.code}';
      _scheduleReconnect();
    } catch (e) {
      error = 'مش قادر يشغّل: $e';
      _scheduleReconnect();
    }
    notifyListeners();
  }

  void _onState(PlayerState state) {
    // البث اللايف مش المفروض يخلص، لو وقف (النت فصل) نرجّعه
    if (isLive && state.processingState == ProcessingState.completed) {
      _scheduleReconnect();
    }
    notifyListeners();
  }

  void _scheduleReconnect() {
    final p = playback;
    if (p is! LivePlayback) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 5), () {
      if (playback == p) playLive(p.channel);
    });
  }

  void _updateSurah() {
    final p = playback;
    if (p is! MoshafPlayback) return;
    int? surah;
    if (continuousStream) {
      // بنحسب السورة الحالية من الوقت ومدد السور
      final start = p.moshaf.surahs.indexOf(p.startSurah);
      var remaining = player.position.inMilliseconds / 1000.0;
      surah = p.startSurah;
      for (var i = start; i >= 0 && i < p.moshaf.surahs.length; i++) {
        surah = p.moshaf.surahs[i];
        final d = p.moshaf.durations[i];
        if (d <= 0 || remaining < d) break;
        remaining -= d;
      }
    } else {
      final i = player.currentIndex;
      if (i != null && i < p.moshaf.surahs.length) surah = p.moshaf.surahs[i];
    }
    if (surah != currentSurah) {
      currentSurah = surah;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else if (isLive) {
      // اللايف بعد إيقاف لازم يرجع للحظة الحالية مش من مكان ما وقف
      await playLive((playback as LivePlayback).channel);
    } else {
      await player.play();
    }
  }

  Future<void> next() => _skip(1);
  Future<void> previous() => _skip(-1);

  Future<void> _skip(int delta) async {
    final p = playback;
    if (p is! MoshafPlayback || currentSurah == null) return;
    final i = p.moshaf.surahs.indexOf(currentSurah!) + delta;
    if (i < 0 || i >= p.moshaf.surahs.length) return;
    if (continuousStream) {
      await playMoshaf(p.moshaf, p.moshaf.surahs[i]);
    } else {
      await player.seek(Duration.zero, index: i);
    }
  }

  Future<void> stop() async {
    _reconnect?.cancel();
    playback = null;
    currentSurah = null;
    await player.stop();
    notifyListeners();
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    if (duration == null) {
      sleepAt = null;
    } else {
      sleepAt = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () {
        sleepAt = null;
        stop();
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _sleepTimer?.cancel();
    _reconnect?.cancel();
    player.dispose();
    super.dispose();
  }
}
