import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'reciter_screen.dart';
import 'reciters_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final catalog = state.catalog;
    if (catalog == null) {
      return Scaffold(appBar: AppBar(title: const Text('المفضلة')), body: CatalogStatus(state: state));
    }
    final moshafs = state.favorites.map(catalog.moshaf).whereType<Moshaf>().toList();
    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: moshafs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('اضغط على زرار القلب في صفحة أي شيخ علشان يظهر هنا', textAlign: TextAlign.center),
              ),
            )
          : ListView(
              children: [
                for (final m in moshafs)
                  ListTile(
                    leading: const Icon(Icons.favorite),
                    title: Text(m.reciter.name),
                    subtitle: Text(m.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_fill),
                      onPressed: () => state.player.playMoshaf(m, m.surahs.first),
                    ),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReciterScreen(reciter: m.reciter, initialRewaya: m.rewayaId),
                    )),
                  ),
              ],
            ),
    );
  }
}
