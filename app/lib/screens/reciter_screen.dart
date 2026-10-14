import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../player.dart';
import 'player_widgets.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reciter.name),
        actions: [
          IconButton(
            tooltip: fav ? 'شيل من المفضلة' : 'ضيف للمفضلة',
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
            onPressed: () => state.toggleFavorite(_moshaf.id),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: Column(
        children: [
          if (widget.reciter.moshafs.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DropdownButtonFormField<int>(
                initialValue: _moshaf.id,
                decoration: const InputDecoration(labelText: 'الرواية', border: OutlineInputBorder(), isDense: true),
                items: [
                  for (final m in widget.reciter.moshafs)
                    DropdownMenuItem(value: m.id, child: Text(m.name)),
                ],
                onChanged: (id) => setState(() => _moshaf = widget.reciter.moshafs.firstWhere((m) => m.id == id)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('شغّل المصحف كله'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => player.playMoshaf(_moshaf, _moshaf.surahs.first),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: player,
              builder: (context, _) {
                final p = player.playback;
                final current = p is MoshafPlayback && p.moshaf.id == _moshaf.id ? player.currentSurah : null;
                return ListView.builder(
                  itemCount: _moshaf.surahs.length,
                  itemBuilder: (context, i) {
                    final s = _moshaf.surahs[i];
                    final isCurrent = s == current;
                    return ListTile(
                      selected: isCurrent,
                      leading: CircleAvatar(
                        radius: 18,
                        child: isCurrent ? const Icon(Icons.graphic_eq, size: 18) : Text('$s', style: const TextStyle(fontSize: 13)),
                      ),
                      title: Text('سورة ${catalog.surahName(s)}'),
                      subtitle: Text(formatDuration(_moshaf.durations[i])),
                      onTap: () => player.playMoshaf(_moshaf, s),
                    );
                  },
                );
              },
            ),
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
