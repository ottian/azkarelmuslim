import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../player.dart';
import '../theme.dart';
import 'player_widgets.dart';
import 'retro_radio.dart';
import 'offline_widgets.dart';
import 'ui.dart';

class ReciterScreen extends StatefulWidget {
  const ReciterScreen({super.key, required this.reciter, this.initialRewaya});

  final Reciter reciter;
  final int? initialRewaya;

  @override
  State<ReciterScreen> createState() => _ReciterScreenState();
}

class _ReciterScreenState extends State<ReciterScreen> {
  late Moshaf _moshaf;

  @override
  void initState() {
    super.initState();
    final moshafs = widget.reciter.moshafs;
    _moshaf = moshafs.firstWhere(
      (m) => m.rewayaId == widget.initialRewaya,
      orElse: () => moshafs.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final catalog = state.catalog!;
    final player = state.player;
    final fav = state.isFavorite(_moshaf.id);
    final moshafs = widget.reciter.moshafs;
    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            backgroundColor: Retro.night,
            title: Text(widget.reciter.name),
            actions: [
              IconButton(
                tooltip: fav ? 'شيل من المفضلة' : 'ضيف للمفضلة',
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: Icon(
                    fav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey(fav),
                    color: fav ? Retro.red : Retro.cream,
                  ),
                ),
                onPressed: () => state.toggleFavorite(_moshaf.id),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF4A2F1B), Retro.night],
                  ),
                ),
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(
                      tag: 'reciter-${widget.reciter.id}',
                      child: Monogram(photo: widget.reciter.photo, name: widget.reciter.name, size: 76),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${moshafs.length} ${moshafs.length == 1 ? 'مصحف' : 'مصاحف'} • ${_moshaf.surahs.length} سورة',
                      style: const TextStyle(color: Retro.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (moshafs.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  children: [
                    for (final m in moshafs)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          showCheckmark: false,
                          label: Text(m.name),
                          selected: m.id == _moshaf.id,
                          onSelected: (_) => setState(() => _moshaf = m),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('شغّل المصحف كله'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () =>
                    player.playMoshaf(_moshaf, _moshaf.surahs.first),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: player,
            builder: (context, _) {
              final p = player.playback;
              final current = p is MoshafPlayback && p.moshaf.id == _moshaf.id
                  ? player.currentSurah
                  : null;
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount: _moshaf.surahs.length,
                  itemBuilder: (context, i) {
                    final s = _moshaf.surahs[i];
                    final isCurrent = s == current;
                    return GlowCard(
                      active: isCurrent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      onTap: () => isCurrent
                          ? player.toggle()
                          : player.playMoshaf(_moshaf, s),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isCurrent ? Retro.amberGlow : null,
                              border: isCurrent
                                  ? null
                                  : Border.all(
                                      color: Retro.brass.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                            ),
                            child: isCurrent
                                ? const EqualizerBars(
                                    color: Color(0xFF2A1A05),
                                    height: 16,
                                    bars: 3,
                                  )
                                : Text(
                                    '$s',
                                    style: const TextStyle(
                                      fontFamily: 'NotoSans',
                                      color: Retro.brass,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'سورة ${catalog.surahName(s)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isCurrent ? Retro.amber : Retro.cream,
                              ),
                            ),
                          ),
                          Text(
                            formatDuration(_moshaf.durations[i]),
                            style: const TextStyle(
                              color: Retro.muted,
                              fontFamily: 'NotoSans',
                              fontSize: 12,
                            ),
                          ),
                          SaveSurahButton(moshaf: _moshaf, surah: s),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

String formatDuration(double seconds) {
  if (seconds <= 0) return '';
  final d = Duration(seconds: seconds.round());
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
