import 'package:flutter/material.dart';

import '../app_state.dart';
import 'favorites_screen.dart';
import 'live_screen.dart';
import 'player_widgets.dart';
import 'reciters_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.api.isConfigured) return const SettingsScreen(firstRun: true);

    const pages = [
      LiveScreen(),
      RecitersScreen(),
      FavoritesScreen(),
      SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // في صفحة المباشر الراديو الكبير ظاهر فوق، فمش محتاجين الشريط
          if (_tab != 0) const MiniPlayer(),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.radio_outlined),
                selectedIcon: Icon(Icons.radio),
                label: 'مباشر',
              ),
              NavigationDestination(
                icon: Icon(Icons.mic_none_rounded),
                selectedIcon: Icon(Icons.mic_rounded),
                label: 'القراء',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline_rounded),
                selectedIcon: Icon(Icons.favorite_rounded),
                label: 'المفضلة',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune_rounded),
                label: 'الإعدادات',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
