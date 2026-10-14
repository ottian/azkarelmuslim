import 'package:flutter/material.dart';

import '../app_state.dart';
import 'favorites_screen.dart';
import 'live_screen.dart';
import 'player_widgets.dart';
import 'reciters_screen.dart';
import 'settings_screen.dart';
import 'prayer_screen.dart';
import 'surahs_screen.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _destinations = [
    (Icons.radio_outlined, Icons.radio, 'مباشر'),
    (Icons.menu_book_outlined, Icons.menu_book_rounded, 'السور'),
    (Icons.mic_none_rounded, Icons.mic_rounded, 'القراء'),
    (Icons.mosque_outlined, Icons.mosque_rounded, 'الصلاة'),
    (Icons.library_music_outlined, Icons.library_music_rounded, 'مكتبتي'),
    (Icons.tune_outlined, Icons.tune_rounded, 'الإعدادات'),
  ];

  /// على الموبايل الإعدادات من زرار في "مكتبتي"، فالشريط اللي تحت فيه 5 بس
  static const _mobileTabs = 5;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.api.isConfigured) return const SettingsScreen(firstRun: true);

    const pages = [LiveScreen(), SurahsScreen(), RecitersScreen(), PrayerScreen(), FavoritesScreen(), SettingsScreen()];
    final body = IndexedStack(index: _tab, children: pages);
    final width = MediaQuery.sizeOf(context).width;

    // الكمبيوتر والتابلت: قايمة جانبية، والراديو ثابت على الجنب
    if (width >= wideLayoutWidth) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NavigationRail(
                backgroundColor: Retro.surface,
                extended: width >= 1280,
                minExtendedWidth: 200,
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                indicatorColor: Retro.amber.withValues(alpha: 0.16),
                selectedIconTheme: const IconThemeData(color: Retro.amber),
                unselectedIconTheme: const IconThemeData(color: Retro.muted),
                selectedLabelTextStyle: const TextStyle(color: Retro.amber, fontWeight: FontWeight.bold),
                unselectedLabelTextStyle: const TextStyle(color: Retro.muted),
                labelType: width >= 1280 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Icon(Icons.radio_rounded, color: Retro.brass, size: 32),
                ),
                destinations: [
                  for (final (icon, selected, label) in _destinations)
                    NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: Text(label)),
                ],
              ),
              Expanded(child: body),
              Container(
                width: 420,
                decoration: const BoxDecoration(
                  color: Retro.surface,
                  border: BorderDirectional(start: BorderSide(color: Retro.line)),
                ),
                child: const SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 20),
                  child: NowPlayingPanel(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // في صفحة المباشر الراديو الكبير ظاهر فوق، فمش محتاجين الشريط
          if (_tab != 0) const MiniPlayer(),
          NavigationBar(
            selectedIndex: _tab.clamp(0, _mobileTabs - 1),
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              for (final (icon, selected, label) in _destinations.take(_mobileTabs))
                NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
            ],
          ),
        ],
      ),
    );
  }
}

/// من العرض ده وأكبر بنعرض القايمة الجانبية والراديو على الجنب
const wideLayoutWidth = 1000.0;
