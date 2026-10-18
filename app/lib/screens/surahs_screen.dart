import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../player.dart';
import '../theme.dart';
import 'player_widgets.dart';
import 'reciter_screen.dart';
import 'reciters_screen.dart';
import 'retro_radio.dart';
import 'offline_widgets.dart';
import 'search_screen.dart';
import 'ui.dart';

/// تختار السورة الأول، وبعدين الشيخ اللي يقرأها
class SurahsScreen extends StatefulWidget {
  const SurahsScreen({super.key});

  @override
  State<SurahsScreen> createState() => _SurahsScreenState();
}

class _SurahsScreenState extends State<SurahsScreen> {
  String _query = '';

  /// null = الكل، true = مكية، false = مدنية
  bool? _makkia;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final catalog = state.catalog;
    if (catalog == null) return Scaffold(body: SafeArea(child: CatalogStatus(state: state)));
    final q = _query.replaceAll('سورة', '').trim();
    final suwar = catalog.suwar.where((s) {
      if (_makkia != null && s.makkia != _makkia) return false;
      if (q.isEmpty) return true;
      return matchesQuery(s.name, q) || '${s.id}' == q;
    }).toList();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(title: 'السور', subtitle: '${catalog.suwar.length} سورة بأصوات أشهر القراء', trailing: const SearchButton()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'اسم السورة أو رقمها'),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            SizedBox(
              height: 58,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: [
                  for (final (label, value) in const [('الكل', null), ('مكية', true), ('مدنية', false)])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Text(label),
                        selected: _makkia == value,
                        onSelected: (_) => setState(() => _makkia = value),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: suwar.isEmpty
                  ? const Center(child: Text('مفيش نتايج', style: TextStyle(color: Retro.muted)))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 480,
                        mainAxisExtent: 78,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: suwar.length,
                      itemBuilder: (context, i) => _SurahTile(surah: suwar[i], catalog: catalog),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({required this.surah, required this.catalog});

  final Surah surah;
  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final count = catalog.moshafsWithSurah(surah.id).map((m) => m.reciter.id).toSet().length;
    return GlowCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SurahScreen(surah: surah))),
      child: Row(
        children: [
          SurahNumber(number: surah.id),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سورة ${surah.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                Text('${surah.makkia ? 'مكية' : 'مدنية'} • $count قارئ',
                    style: const TextStyle(color: Retro.muted, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Retro.muted),
        ],
      ),
    );
  }
}

/// رقم السورة في نجمة ثمانية نحاسية
class SurahNumber extends StatelessWidget {
  const SurahNumber({super.key, required this.number, this.size = 42, this.active = false});

  final int number;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final turn in const [0.0, 0.125])
              RotationTransition(
                turns: AlwaysStoppedAnimation(turn),
                child: Container(
                  width: size * 0.74,
                  height: size * 0.74,
                  decoration: BoxDecoration(
                    gradient: active ? Retro.amberGlow : null,
                    color: active ? null : Retro.night,
                    border: Border.all(color: Retro.brass.withValues(alpha: active ? 0 : 0.6), width: 1.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            Text('$number',
                style: TextStyle(
                  fontFamily: 'NotoSans',
                  fontWeight: FontWeight.bold,
                  fontSize: size * (number > 99 ? 0.26 : 0.31),
                  color: active ? const Color(0xFF2A1A05) : Retro.brass,
                )),
          ],
        ),
      );
}

/// القراء اللي عندهم السورة دي
class SurahScreen extends StatelessWidget {
  const SurahScreen({super.key, required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final catalog = state.catalog!;
    final player = state.player;
    final moshafs = catalog.moshafsWithSurah(surah.id);
    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 190,
            backgroundColor: Retro.night,
            title: Text('سورة ${surah.name}'),
            flexibleSpace: FlexibleSpaceBar(
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
                    SurahNumber(number: surah.id, size: 64),
                    const SizedBox(height: 8),
                    Text('${surah.makkia ? 'مكية' : 'مدنية'} • ${moshafs.length} تلاوة',
                        style: const TextStyle(color: Retro.muted, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: player,
            builder: (context, _) {
              final p = player.playback;
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.builder(
                  itemCount: moshafs.length,
                  itemBuilder: (context, i) {
                    final m = moshafs[i];
                    final active = p is MoshafPlayback && p.moshaf.id == m.id && player.currentSurah == surah.id;
                    final d = m.durations.length > m.surahs.indexOf(surah.id) ? m.durations[m.surahs.indexOf(surah.id)] : 0.0;
                    return GlowCard(
                      active: active,
                      onTap: () => active ? player.toggle() : player.playMoshaf(m, surah.id),
                      child: Row(
                        children: [
                          Monogram(photo: m.reciter.photo, name: m.reciter.name, size: 44),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.reciter.name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 15, color: active ? Retro.amber : Retro.cream)),
                                Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Retro.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (d > 0)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(start: 8),
                              child: Text(formatDuration(d),
                                  style: const TextStyle(color: Retro.muted, fontFamily: 'NotoSans', fontSize: 12)),
                            ),
                          SaveSurahButton(moshaf: m, surah: surah.id),
                          SizedBox(
                            width: 32,
                            child: active
                                ? const Center(child: EqualizerBars(height: 18))
                                : const Icon(Icons.play_arrow_rounded, color: Retro.cream),
                          ),
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
