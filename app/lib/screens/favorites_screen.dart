import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'reciter_screen.dart';
import 'home_screen.dart';
import 'reciters_screen.dart';
import 'settings_screen.dart';
import 'ui.dart';

/// مكتبتي: كمّل من حيث وقفت، وآخر اللي سمعته، والمفضلة
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final catalog = state.catalog;
    if (catalog == null) return Scaffold(body: SafeArea(child: CatalogStatus(state: state)));
    final favorites = state.favorites.map(catalog.moshaf).whereType<Moshaf>().toList();
    final history = state.history.where((e) => catalog.moshaf(e.moshafId) != null).toList();
    final last = history.isEmpty ? null : history.first;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            PageHeader(
              title: 'مكتبتي',
              subtitle: 'اللي سمعته واللي بتحبه',
              trailing: MediaQuery.sizeOf(context).width >= wideLayoutWidth
                  ? null
                  : IconButton(
                      tooltip: 'الإعدادات',
                      icon: const Icon(Icons.settings_outlined, color: Retro.brass),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SettingsScreen(standalone: true),
                      )),
                    ),
            ),
            if (last != null) ResumeCard(entry: last, large: true),
            if (history.length > 1) ...[
              SectionTitle(
                'سمعت مؤخرًا',
                action: TextButton(onPressed: state.clearHistory, child: const Text('امسح السجل')),
              ),
              for (final e in history.skip(1).take(10)) _HistoryTile(entry: e, catalog: catalog),
            ],
            const SectionTitle('المفضلة'),
            if (favorites.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  Icon(Icons.favorite_border_rounded, size: 48, color: Retro.line),
                  SizedBox(height: 10),
                  Text('اضغط على زرار القلب في صفحة أي شيخ علشان يظهر هنا',
                      textAlign: TextAlign.center, style: TextStyle(color: Retro.muted)),
                ]),
              ),
            for (final m in favorites)
              GlowCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ReciterScreen(reciter: m.reciter, initialRewaya: m.rewayaId),
                )),
                child: Row(
                  children: [
                    Monogram(photo: m.reciter.photo, name: m.reciter.name),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.reciter.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                          Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Retro.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      iconSize: 36,
                      color: Retro.amber,
                      tooltip: 'تشغيل',
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      onPressed: () => state.player.playMoshaf(m, m.surahs.first),
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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.catalog});

  final ListenEntry entry;
  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final m = catalog.moshaf(entry.moshafId)!;
    return GlowCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => state.resume(entry),
      child: Row(
        children: [
          Monogram(photo: m.reciter.photo, name: m.reciter.name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سورة ${catalog.surahName(entry.surah)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${m.reciter.name} • ${timeAgo(entry.at)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Retro.muted, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.play_arrow_rounded, color: Retro.cream),
        ],
      ),
    );
  }
}

/// كارت "كمّل من حيث وقفت"
class ResumeCard extends StatelessWidget {
  const ResumeCard({super.key, required this.entry, this.large = false});

  final ListenEntry entry;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final catalog = state.catalog!;
    final m = catalog.moshaf(entry.moshafId)!;
    final i = m.surahs.indexOf(entry.surah);
    final total = i >= 0 && i < m.durations.length ? m.durations[i] : 0.0;
    final progress = total > 0 ? (entry.position.inSeconds / total).clamp(0.0, 1.0) : 0.0;
    final at = entry.position.inSeconds > 5 ? ' • من ${formatDuration(entry.position.inSeconds.toDouble())}' : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFF5A3A1E), Color(0xFF2A1A0E)]),
        border: Border.all(color: Retro.brass.withValues(alpha: 0.45)),
        boxShadow: [BoxShadow(color: Retro.amber.withValues(alpha: 0.12), blurRadius: 24)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => state.resume(entry),
          child: Padding(
            padding: EdgeInsets.all(large ? 16 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Monogram(photo: m.reciter.photo, name: m.reciter.name, size: large ? 52 : 42),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('كمّل من حيث وقفت',
                              style: TextStyle(color: Retro.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('سورة ${catalog.surahName(entry.surah)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: large ? 18 : 15.5)),
                          Text('${m.reciter.name}$at',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Retro.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      width: large ? 48 : 40,
                      height: large ? 48 : 40,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Retro.amberGlow),
                      child: Icon(Icons.play_arrow_rounded, color: const Color(0xFF2A1A05), size: large ? 30 : 26),
                    ),
                  ],
                ),
                if (progress > 0) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: Colors.black26),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'دلوقتي';
  if (d.inMinutes < 60) return 'من ${d.inMinutes} دقيقة';
  if (d.inHours < 24) return 'من ${d.inHours} ساعة';
  if (d.inDays == 1) return 'امبارح';
  return 'من ${d.inDays} يوم';
}
