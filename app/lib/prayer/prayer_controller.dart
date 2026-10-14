import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../player.dart';
import '../third_party/adhan/adhan.dart';
import 'adhkar.dart';
import 'notifier.dart';
import 'prayer_settings.dart';
import 'wird.dart';

/// مواقيت يوم واحد
class DayTimes {
  const DayTimes(this.day, this.times);
  final DateTime day;
  final Map<PrayerName, DateTime> times;
}

/// مواقيت الصلاة، والتنبيهات، والأذان، والورد اليومي
class PrayerController extends ChangeNotifier {
  PrayerController(this.prefs, this.player) : settings = PrayerSettings.load(prefs);

  final SharedPreferences prefs;
  final PlayerController player;
  final PrayerSettings settings;
  final notifier = Notifier();

  List<AdhkarSection> adhkar = const [];
  Timer? _tick;
  List<Alert> _pending = const [];
  AudioPlayer? _adhanPlayer;

  /// الأذان شغال دلوقتي (ويندوز والويب)
  bool adhanPlaying = false;

  /// اسم السورة من الفهرس (بيتظبط لما الفهرس يوصل)
  String Function(int surah)? surahName;

  Future<void> start() async {
    try {
      adhkar = await loadAdhkar();
    } catch (e) {
      debugPrint('adhkar load failed: $e');
    }
    notifyListeners();
    await notifier.init();
    await reschedule();
    // بنراجع كل 20 ثانية بدل تايمر طويل، علشان المتصفح والجهاز النايم بيأخّروا التايمرات
    _tick = Timer.periodic(const Duration(seconds: 20), (_) => _check());
    notifyListeners();
  }

  DayTimes? timesFor(DateTime day) {
    if (!settings.hasLocation) return null;
    final t = PrayerTimes(settings.coordinates, DateComponents(day.year, day.month, day.day), settings.parameters);
    return DayTimes(DateTime(day.year, day.month, day.day), {
      PrayerName.fajr: t.fajr.toLocal(),
      PrayerName.sunrise: t.sunrise.toLocal(),
      PrayerName.dhuhr: t.dhuhr.toLocal(),
      PrayerName.asr: t.asr.toLocal(),
      PrayerName.maghrib: t.maghrib.toLocal(),
      PrayerName.isha: t.isha.toLocal(),
    });
  }

  /// الصلاة الجاية (من غير الشروق) والصلاة اللي قبلها
  ({PrayerName name, DateTime at, DateTime previous})? next([DateTime? now]) {
    now ??= DateTime.now();
    final today = timesFor(now);
    if (today == null) return null;
    final yesterday = timesFor(now.subtract(const Duration(days: 1)))!;
    final tomorrow = timesFor(now.add(const Duration(days: 1)))!;
    final list = [
      for (final d in [yesterday, today, tomorrow])
        for (final e in d.times.entries)
          if (e.key.isPrayer) (e.key, e.value),
    ];
    for (var i = 1; i < list.length; i++) {
      if (list[i].$2.isAfter(now)) return (name: list[i].$1, at: list[i].$2, previous: list[i - 1].$2);
    }
    return null;
  }

  double? get qibla => settings.hasLocation ? Qibla(settings.coordinates).direction : null;

  int get todayJuz => juzForDay(settings.wirdStart, DateTime.now());

  bool get wirdDoneToday {
    final d = settings.wirdDoneOn, n = DateTime.now();
    return d != null && d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Future<void> markWirdDone(bool done) async {
    settings.wirdDoneOn = done ? DateTime.now() : null;
    await settings.save(prefs);
    notifyListeners();
  }

  Future<void> update(void Function(PrayerSettings s) change) async {
    change(settings);
    await settings.save(prefs);
    await reschedule();
    notifyListeners();
  }

  /// كل تنبيهات الأيام الجاية
  List<Alert> buildAlerts({int days = 7}) {
    final now = DateTime.now();
    final s = settings;
    final out = <Alert>[];
    final tasabeeh = adhkar.where((a) => a.title == 'تسابيح').expand((a) => a.items).toList();
    DateTime at(DateTime d, int h, int m) => DateTime(d.year, d.month, d.day, h, m);
    for (var i = 0; i < days; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      final base = (d.difference(DateTime(2024)).inDays % 3000) * 16;
      final times = timesFor(d);
      if (times != null && s.prayerAlerts) {
        for (final p in PrayerName.values.where((p) => p.isPrayer)) {
          out.add(Alert(
            id: base + p.index,
            at: times.times[p]!,
            title: 'حان الآن موعد صلاة ${p.label}',
            body: '${s.placeName} • ${formatTime(times.times[p]!)}',
            adhan: s.adhan.contains(p),
          ));
        }
      }
      if (s.morningAdhkar) {
        out.add(Alert(id: base + 8, at: at(d, s.morningTime.hour, s.morningTime.minute), title: 'أذكار الصباح', body: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، افتح التطبيق واقرأ أذكار الصباح'));
      }
      if (s.middayReminder) {
        final z = tasabeeh.isEmpty ? null : tasabeeh[(d.day + d.month) % tasabeeh.length];
        out.add(Alert(id: base + 9, at: at(d, s.middayTime.hour, s.middayTime.minute), title: 'ذكر', body: z?.text ?? 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ'));
      }
      if (s.eveningAdhkar) {
        out.add(Alert(id: base + 10, at: at(d, s.eveningTime.hour, s.eveningTime.minute), title: 'أذكار المساء', body: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، افتح التطبيق واقرأ أذكار المساء'));
      }
      if (s.wird) {
        final juz = juzForDay(s.wirdStart, d);
        out.add(Alert(id: base + 11, at: at(d, s.wirdTime.hour, s.wirdTime.minute), title: 'وردك اليوم: الجزء ${juzNames[juz - 1]}', body: 'يبدأ من سورة ${surahName?.call(juzStartSurah[juz - 1]) ?? juzStartSurah[juz - 1]}، افتح التطبيق واسمعه'));
      }
    }
    out.removeWhere((a) => !a.at.isAfter(now));
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  Future<void> reschedule() async {
    _pending = buildAlerts();
    await notifier.schedule(_pending);
  }

  void _check() {
    final now = DateTime.now();
    var changed = false;
    while (_pending.isNotEmpty && !_pending.first.at.isAfter(now)) {
      final a = _pending.first;
      _pending = _pending.sublist(1);
      // لو الجهاز كان نايم وفات المعاد بكتير منطلعش تنبيه قديم
      if (now.difference(a.at) < const Duration(minutes: 3)) _fire(a);
      changed = true;
    }
    if (_pending.length < 10) _pending = buildAlerts();
    if (changed) notifyListeners();
  }

  Future<void> _fire(Alert a) async {
    if (notifier.osScheduling) return; // أندرويد بيطلّعها بنفسه وبصوت الأذان
    await notifier.showNow(a);
    if (a.adhan) await playAdhan();
  }

  Future<void> playAdhan() async {
    // على أندرويد الأذان بيشتغل كصوت الإشعار
    if (notifier.osScheduling) return;
    try {
      if (player.player.playing) await player.player.pause();
      final p = _adhanPlayer ??= AudioPlayer();
      await p.setAudioSource(AudioSource.asset('assets/audio/adhan.mp3'));
      adhanPlaying = true;
      notifyListeners();
      await p.play();
    } catch (e) {
      debugPrint('adhan failed: $e');
    } finally {
      adhanPlaying = false;
      notifyListeners();
    }
  }

  Future<void> stopAdhan() async {
    await _adhanPlayer?.stop();
    adhanPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _adhanPlayer?.dispose();
    super.dispose();
  }
}

/// 4:29 ص
String formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'ص' : 'م'}';
}
