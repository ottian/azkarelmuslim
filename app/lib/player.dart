import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'api.dart';
import 'media_session.dart';
import 'models.dart';
import 'offline/offline_store.dart';

sealed class Playback {
  const Playback();
}

class LivePlayback extends Playback {
  const LivePlayback(this.channel);
  final LiveChannel channel;
}

class MoshafPlayback extends Playback {
  const MoshafPlayback(this.moshaf, this.startSurah, this.surahs);
  final Moshaf moshaf;
  final int startSurah;

  /// السور اللي بتتشغّل ورا بعض: المصحف كله، أو المحفوظ على الجهاز بس
  final List<int> surahs;
}

/// بيشغّل اللايف أو مصحف شيخ معين، وبيكمل في الخلفية.
///
/// على الويب (الآيفون) المصحف بيتشغّل كبث واحد متصل من /api/play علشان
/// Safari ميوقفش بين السور والشاشة مقفولة. على الأندرويد والويندوز
/// بيتشغّل كقائمة ملفات علشان التقديم والترجيع.
class PlayerController extends ChangeNotifier {
  PlayerController(this._api, this.offline) {
    autoNext = _api.prefs.getBool(_autoNextKey) ?? true;
    _subs.add(player.playerStateStream.listen(_onState));
    _subs.add(player.currentIndexStream.listen((_) => _updateSurah()));
    _subs.add(player.positionStream.listen((pos) {
      if (kIsWeb) _updateSurah();
      if (pos > _lastPos) _lastProgress = DateTime.now();
      _lastPos = pos;
      _updateWaiting();
    }));
    _waitCheck = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (player.playing || waiting.value) _updateWaiting();
    });
  }

  /// الصوت مستني يحمّل فعلا. المشغل ساعات بيفضل يقول "بيحمّل" في البث
  /// اللايف والصوت شغال عادي، فبنعتمد كمان على إن مكان التشغيل بيتحرك.
  final ValueNotifier<bool> waiting = ValueNotifier(false);
  Duration _lastPos = Duration.zero;
  DateTime _lastProgress = DateTime(2000);
  Timer? _waitCheck;

  void _updateWaiting() {
    final s = player.playerState;
    final pending = s.playing &&
        (s.processingState == ProcessingState.loading || s.processingState == ProcessingState.buffering);
    final moving = DateTime.now().difference(_lastProgress) < const Duration(milliseconds: 1500);
    waiting.value = pending && !moving;
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
  Playback? _advancedFrom;
  bool _loading = false;

  /// السور المحفوظة على الجهاز (بتشتغل من غير نت)
  final OfflineStore offline;

  static const _autoNextKey = 'auto_next';

  /// لما السورة تخلص تشتغل اللي بعدها لوحدها
  late bool autoNext;

  /// المستخدم داس التالي/السابق، فده مش انتقال لوحده
  bool _manualSkip = false;

  /// تكرار نفس السورة (للحفظ)
  bool repeatSurah = false;
  double speed = 1.0;

  /// مؤقت النوم: يقف لما السورة الحالية تخلص
  bool stopAtSurahEnd = false;

  bool get isLive => playback is LivePlayback;
  /// على الويب مع سيرفرنا بنشغّل المصحف كبث واحد متصل (للآيفون).
  /// في نسخة GitHub Pages مفيش سيرفر يوصّل الملفات، فبنشغّلها كقائمة.
  bool get continuousStream => kIsWeb && catalog?.isStatic != true;

  /// على الويب من غير سيرفرنا: ملف واحد في المرة، ولما يخلص نشغّل اللي بعده
  /// (القوائم في just_audio على الويب مش شغالة مع التشغيل في الخلفية)
  bool get _chainFiles => kIsWeb && !continuousStream;

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

  /// [startAt] للرجوع لنفس المكان اللي المستمع وقف عنده
  ///
  /// [savedOnly]: يشغّل السور المحفوظة على الجهاز بس (من مكتبتي، من غير نت)
  Future<void> playMoshaf(Moshaf moshaf, int surah, {Duration? startAt, bool savedOnly = false}) async {
    // البث اللايف مالوش نهاية، لازم نقفله الأول وإلا المتصفح بيفضل مستني عليه
    if (isLive && !kIsWeb) await player.stop();
    final queue = savedOnly ? [for (final s in moshaf.surahs) if (offline.isSaved(moshaf.id, s)) s] : moshaf.surahs;
    playback = MoshafPlayback(moshaf, surah, queue.contains(surah) ? queue : moshaf.surahs);
    currentSurah = surah;
    final reciter = moshaf.reciter.name;
    final p = playback as MoshafPlayback;
    if (continuousStream && !offline.isSaved(moshaf.id, surah)) {
      await _load(AudioSource.uri(
        _api.url('/api/play/${moshaf.id}?from=$surah'),
        tag: MediaItem(
          id: 'moshaf-${moshaf.id}-$surah',
          title: reciter,
          artist: moshaf.label,
          album: 'إذاعة أذكار المسلم',
        ),
      ));
    } else if (_chainFiles) {
      await _load(_surahSource(moshaf, surah), startAt: startAt);
    } else {
      final sources = [
        for (final s in p.surahs)
          _surahSource(moshaf, s),
      ];
      final index = p.surahs.indexOf(surah);
      await _load(null, sources: sources, initialIndex: index < 0 ? 0 : index, startAt: startAt);
    }
  }

  AudioSource _surahSource(Moshaf moshaf, int surah) {
    final tag = MediaItem(
      id: 'moshaf-${moshaf.id}-$surah',
      title: 'سورة ${catalog?.surahName(surah) ?? surah}',
      artist: moshaf.reciter.name,
      album: moshaf.label,
    );
    // على أندرويد وويندوز المحفوظ بيشتغل من الملف، وعلى الويب الـ service worker
    // بيرد على نفس الرابط من المحفوظ
    final file = offline.localFile(moshaf.id, surah);
    if (file != null) return AudioSource.file(file, tag: tag);
    return AudioSource.uri(_api.url(moshaf.audioUrl(surah)), tag: tag);
  }

  Future<void> _load(AudioSource? source,
      {List<AudioSource>? sources, int initialIndex = 0, Duration? startAt}) async {
    _reconnect?.cancel();
    error = null;
    notifyListeners();
    final requested = playback;
    _loading = true;
    try {
      if (kIsWeb) {
        // على الويب لازم نقفل الصوت اللي شغال خالص قبل ما نحمّل الجديد،
        // وإلا Safari ممكن يكمّل الملف أو البث القديم
        await player.stop();
        if (playback != requested) return; // المستخدم اختار حاجة تانية في الوقت ده
        _updateWebMediaSession(source);
      }
      if (source != null) {
        await player.setAudioSource(source, initialPosition: startAt);
      } else {
        await player.setAudioSources(sources!, initialIndex: initialIndex, initialPosition: startAt);
      }
      // اللايف دايمًا بسرعته الطبيعية
      await player.setSpeed(isLive ? 1.0 : speed);
      await player.setLoopMode(repeatSurah && !isLive && !_chainFiles ? LoopMode.one : LoopMode.off);
      _loading = false;
      unawaited(player.play());
    } on PlayerException catch (e) {
      error = 'مش قادر يشغّل: ${e.message ?? e.code}';
      _scheduleReconnect();
    } catch (e, st) {
      debugPrint('play failed: $e\n$st');
      error = 'مش قادر يشغّل: $e';
      _scheduleReconnect();
    } finally {
      if (playback == requested) _loading = false;
    }
    notifyListeners();
  }

  void _updateWebMediaSession(AudioSource? source) {
    final item = source is UriAudioSource ? source.tag as MediaItem? : null;
    if (item == null) return;
    final moshaf = playback is MoshafPlayback;
    setMediaSession(
      title: item.title,
      artist: item.artist ?? '',
      album: item.album ?? '',
      onNext: moshaf ? next : null,
      onPrevious: moshaf ? previous : null,
    );
  }

  void _onState(PlayerState state) {
    _updateWaiting();
    // البث اللايف مش المفروض يخلص، لو وقف (النت فصل) نرجّعه
    if (isLive && state.processingState == ProcessingState.completed) {
      _scheduleReconnect();
    }
    final p = playback;
    // "خلص" ممكن توصل أكتر من مرة لنفس الملف، فبننتقل مرة واحدة بس
    if (_chainFiles && p is MoshafPlayback && state.processingState == ProcessingState.completed &&
        !_loading && _advancedFrom != p) {
      _advancedFrom = p;
      final current = currentSurah ?? p.startSurah;
      final i = p.surahs.indexOf(current) + 1;
      final savedOnly = !identical(p.surahs, p.moshaf.surahs);
      if (stopAtSurahEnd) {
        stopAtSurahEnd = false;
        stop();
      } else if (repeatSurah) {
        playMoshaf(p.moshaf, current, savedOnly: savedOnly);
      } else if (autoNext && i > 0 && i < p.surahs.length) {
        playMoshaf(p.moshaf, p.surahs[i], savedOnly: savedOnly);
      }
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
    if (_chainFiles) {
      surah = p.startSurah;
    } else if (continuousStream) {
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
      if (i != null && i < p.surahs.length) surah = p.surahs[i];
    }
    if (surah != currentSurah) {
      // على أندرويد وويندوز: السورة خلصت ودخلنا في اللي بعدها
      final natural = currentSurah != null && !_chainFiles && !continuousStream && !_manualSkip && !_loading;
      _manualSkip = false;
      if (stopAtSurahEnd && natural) {
        stopAtSurahEnd = false;
        stop();
        return;
      }
      if (!autoNext && natural) {
        // يقف على أول السورة الجاية، ولو داس تشغيل تكمّل منها
        player.pause();
      }
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
    final i = p.surahs.indexOf(currentSurah!) + delta;
    if (i < 0 || i >= p.surahs.length) return;
    if (kIsWeb) {
      await playMoshaf(p.moshaf, p.surahs[i], savedOnly: !identical(p.surahs, p.moshaf.surahs));
    } else {
      _manualSkip = true;
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

  Future<void> setSpeed(double value) async {
    speed = value;
    if (!isLive) await player.setSpeed(value);
    notifyListeners();
  }

  Future<void> setAutoNext(bool value) async {
    autoNext = value;
    await _api.prefs.setBool(_autoNextKey, value);
    notifyListeners();
  }

  Future<void> setRepeatSurah(bool value) async {
    repeatSurah = value;
    if (!_chainFiles) await player.setLoopMode(value ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  void setStopAtSurahEnd(bool value) {
    stopAtSurahEnd = value;
    if (value) {
      _sleepTimer?.cancel();
      sleepAt = null;
    }
    notifyListeners();
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    if (duration != null) stopAtSurahEnd = false;
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
    _waitCheck?.cancel();
    waiting.dispose();
    player.dispose();
    super.dispose();
  }
}
