import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'player.dart';

const _favoritesKey = 'favorite_moshafs';

/// الفهرس والمفضلة. بيتوصل للشاشات عن طريق [AppScope].
class AppState extends ChangeNotifier {
  AppState(this.prefs) : api = Api(prefs) {
    player = PlayerController(api);
    favorites = (prefs.getStringList(_favoritesKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  final SharedPreferences prefs;
  final Api api;
  late final PlayerController player;
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
