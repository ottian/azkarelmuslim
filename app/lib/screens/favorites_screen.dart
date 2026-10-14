import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'reciter_screen.dart';
import 'reciters_screen.dart';
import 'ui.dart';
import '../theme.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final catalog = state.catalog;
    if (catalog == null) {
      return Scaffold(
        body: SafeArea(child: CatalogStatus(state: state)),
      );
    }
    final moshafs = state.favorites
        .map(catalog.moshaf)
        .whereType<Moshaf>()
        .toList();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PageHeader(
              title: 'المفضلة',
              subtitle: 'المصاحف اللي بتسمعها على طول',
            ),
            Expanded(
              child: moshafs.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.favorite_border_rounded,
                              size: 56,
                              color: Retro.line,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'اضغط على زرار القلب في صفحة أي شيخ علشان يظهر هنا',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Retro.muted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        for (final m in moshafs)
                          GlowCard(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReciterScreen(
                                  reciter: m.reciter,
                                  initialRewaya: m.rewayaId,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Monogram(name: m.reciter.name),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.reciter.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                      Text(
                                        m.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Retro.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  iconSize: 36,
                                  color: Retro.amber,
                                  tooltip: 'تشغيل',
                                  icon: const Icon(
                                    Icons.play_circle_fill_rounded,
                                  ),
                                  onPressed: () => state.player.playMoshaf(
                                    m,
                                    m.surahs.first,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
