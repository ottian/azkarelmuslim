import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../offline/offline_store.dart';
import '../player.dart';
import '../theme.dart';
import 'retro_radio.dart';
import 'ui.dart';

/// قلب جنب السورة: يحفظها في مكتبتي وينزّلها علشان تشتغل من غير نت
class SaveSurahButton extends StatelessWidget {
  const SaveSurahButton({super.key, required this.moshaf, required this.surah});

  final Moshaf moshaf;
  final int surah;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final offline = state.offline;
    return ListenableBuilder(
      listenable: offline,
      builder: (context, _) {
        if (offline.isDownloading(moshaf.id, surah)) {
          final p = offline.progressOf(moshaf.id, surah);
          return Tooltip(
            message: p == null ? 'بيتحفظ…' : 'بيتحفظ… ${(p * 100).round()}%',
            child: SizedBox.square(
              dimension: 40,
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: CircularProgressIndicator(value: p, strokeWidth: 2.5, color: Retro.amber),
              ),
            ),
          );
        }
        final saved = offline.isSaved(moshaf.id, surah);
        final name = state.catalog?.surahName(surah) ?? '$surah';
        return IconButton(
          tooltip: saved ? 'محفوظة في مكتبتي، اضغط تشيلها' : 'احفظها في مكتبتي واسمعها من غير نت',
          icon: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: saved ? Retro.amber : Retro.muted),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            if (saved) {
              await offline.remove(moshaf.id, surah);
              messenger.showSnackBar(SnackBar(content: Text('شلت سورة $name من مكتبتي')));
              return;
            }
            final url = state.api.url(moshaf.audioUrl(surah)).toString();
            final error = await offline.save(moshaf.id, surah, url);
            messenger.showSnackBar(SnackBar(
              content: Text(error ?? 'سورة $name اتحفظت في مكتبتي، تقدر تسمعها من غير نت'),
            ));
          },
        );
      },
    );
  }
}

/// سورة محفوظة في مكتبتي
class SavedSurahTile extends StatelessWidget {
  const SavedSurahTile({super.key, required this.item, required this.moshaf});

  final SavedSurah item;
  final Moshaf moshaf;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final player = state.player;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final p = player.playback;
        final active = p is MoshafPlayback && p.moshaf.id == moshaf.id && player.currentSurah == item.surah;
        return GlowCard(
          active: active,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          onTap: () => active ? player.toggle() : player.playMoshaf(moshaf, item.surah, savedOnly: true),
          child: Row(
            children: [
              Monogram(photo: moshaf.reciter.photo, name: moshaf.reciter.name, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سورة ${state.catalog?.surahName(item.surah) ?? item.surah}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: active ? Retro.amber : Retro.cream)),
                    Text('${moshaf.reciter.name} • ${moshaf.label}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Retro.muted, fontSize: 12)),
                  ],
                ),
              ),
              if (active) const Padding(padding: EdgeInsets.all(8), child: EqualizerBars(height: 16, bars: 3)),
              IconButton(
                tooltip: 'شيلها من مكتبتي',
                icon: const Icon(Icons.delete_outline_rounded, color: Retro.muted),
                onPressed: () => state.offline.remove(moshaf.id, item.surah),
              ),
            ],
          ),
        );
      },
    );
  }
}
