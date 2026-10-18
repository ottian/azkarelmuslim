import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'offline/offline_store.dart';
import 'player.dart';
import 'prayer/prayer_controller.dart';

const _favoritesKey = 'favorite_moshafs';
const _historyKey = 'listen_history';

/// آخر مكان وصله المستمع في مصحف شيخ
class ListenEntry {
  const ListenEntry({required this.moshafId, required this.surah, required this.position, required this.at});

  final int moshafId;
  final int surah;
  final Duration position;
  final DateTime at;

  Map<String, dynamic> toJson() =>
      {'m': moshafId, 's': surah, 'p': position.inSeconds, 't': at.millisecondsSinceEpoch};

  static ListenEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final m = j['m'], s = j['s'], p = j['p'], t = j['t'];
    if (m is! int || s is! int) return null;
    return ListenEntry(
      moshafId: m,
      surah: s,
      position: Duration(seconds: p is int ? p : 0),
      at: DateTime.fromMillisecondsSinceEpoch(t is int ? t : 0),
    );
  }
}

/// الفهرس والمفضلة. بيتوصل للشاشات عن طريق [AppScope].
class AppState extends ChangeNotifier {
  AppState(this.prefs) : api = Api(prefs) {
    offline = OfflineStore(prefs);
    offline.addListener(notifyListeners);
    offline.ready.then((_) => notifyListeners());
    player = PlayerController(api, offline);
    prayer = PrayerController(prefs, player);
    // الشاشات بتقرا المواقيت من AppScope، فأي تغيير فيها لازم يوصلها
    prayer.addListener(notifyListeners);
    prayer.start();
    favorites = (prefs.getStringList(_favoritesKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    history = _readHistory();
    player.addListener(_record);
    _recordTimer = Timer.periodic(const Duration(seconds: 15), (_) => _record());
  }

  late List<ListenEntry> history;
  Timer? _recordTimer;

  List<ListenEntry> _readHistory() {
    try {
      final raw = prefs.getString(_historyKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map(ListenEntry.fromJson).whereType<ListenEntry>().toList();
    } catch (_) {
      return [];
    }
  }

  /// بنسجّل السورة والوقت كل شوية، علشان "كمّل من حيث وقفت"
  void _record() {
    final p = player.playback;
    final surah = player.currentSurah;
    if (p is! MoshafPlayback || surah == null) return;
    // في البث المتصل الوقت محسوب من أول المصحف مش من أول السورة
    final pos = player.continuousStream ? Duration.zero : player.player.position;
    final last = history.isEmpty ? null : history.first;
    if (last != null && last.moshafId == p.moshaf.id && last.surah == surah &&
        (last.position - pos).inSeconds.abs() < 10) {
      return;
    }
    history = [
      ListenEntry(moshafId: p.moshaf.id, surah: surah, position: pos, at: DateTime.now()),
      ...history.where((e) => e.moshafId != p.moshaf.id),
    ].take(30).toList();
    prefs.setString(_historyKey, jsonEncode(history.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  /// آخر حاجة اتسمعت وموجودة في الفهرس
  ListenEntry? get lastListen {
    final c = catalog;
    if (c == null) return null;
    for (final e in history) {
      if (c.moshaf(e.moshafId) != null) return e;
    }
    return null;
  }

  Future<void> resume(ListenEntry e) async {
    final m = catalog?.moshaf(e.moshafId);
    if (m == null) return;
    await player.playMoshaf(m, e.surah, startAt: e.position > const Duration(seconds: 5) ? e.position : null);
  }

  Future<void> clearHistory() async {
    history = [];
    await prefs.remove(_historyKey);
    notifyListeners();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    player.removeListener(_record);
    super.dispose();
  }

  final SharedPreferences prefs;
  final Api api;
  late final PlayerController player;
  late final OfflineStore offline;
  late final PrayerController prayer;
  late Set<int> favorites;

  Catalog? catalog;
  String? catalogError;
  bool loading = false;

  Future<void> loadCatalog() async {
    if (!api.isConfigured) return;
    loading = true;
    catalogError = null;
    notifyListeners();
    try {
      catalog = await api.catalog();
      player.catalog = catalog;
      final c = catalog!;
      prayer.surahName = c.surahName;
      prayer.reschedule();
    } catch (e) {
      catalogError = 'مش قادر يوصل للسيرفر ($e)';
    }
    loading = false;
    notifyListeners();
  }

  bool isFavorite(int moshafId) => favorites.contains(moshafId);

  Future<void> toggleFavorite(int moshafId) async {
    if (!favorites.remove(moshafId)) favorites.add(moshafId);
    await prefs.setStringList(_favoritesKey, favorites.map((e) => '$e').toList());
    notifyListeners();
  }

  Future<void> changeServer(String url) async {
    await api.setBaseUrl(url);
    await player.stop();
    catalog = null;
    await loadCatalog();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
