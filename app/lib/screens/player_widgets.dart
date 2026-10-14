import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../app_state.dart';
import '../player.dart';

/// شريط صغير تحت الشاشة بيظهر اللي شغال دلوقتي
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final player = state.player;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        if (player.playback == null) return const SizedBox.shrink();
        final info = describe(state);
        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.secondaryContainer,
          child: InkWell(
            onTap: () => showPlayerSheet(context),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Icon(player.isLive ? Icons.radio : Icons.menu_book, color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(info.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                          Text(player.error ?? info.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const PlayPauseButton(),
                    IconButton(icon: const Icon(Icons.close), tooltip: 'إيقاف', onPressed: player.stop),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    return StreamBuilder<PlayerState>(
      stream: player.player.playerStateStream,
      builder: (context, snap) {
        final s = snap.data;
        final loading = s?.processingState == ProcessingState.loading || s?.processingState == ProcessingState.buffering;
        if (loading && s?.playing == true) {
          return SizedBox(width: size + 16, height: size + 16, child: const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final playing = s?.playing ?? false;
        return IconButton(
          iconSize: size,
          tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل',
          icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
          onPressed: player.toggle,
        );
      },
    );
  }
}

class PlaybackInfo {
  const PlaybackInfo(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

PlaybackInfo describe(AppState state) {
  final p = state.player.playback;
  final catalog = state.catalog;
  return switch (p) {
    LivePlayback(:final channel) => PlaybackInfo(channel.name, 'بث مباشر'),
    MoshafPlayback(:final moshaf) => PlaybackInfo(
        state.player.currentSurah == null ? moshaf.reciter.name : 'سورة ${catalog?.surahName(state.player.currentSurah!) ?? state.player.currentSurah}',
        '${moshaf.reciter.name} • ${moshaf.label}',
      ),
    null => const PlaybackInfo('', ''),
  };
}

void showPlayerSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _PlayerSheet(),
  );
}

class _PlayerSheet extends StatelessWidget {
  const _PlayerSheet();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final player = state.player;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final info = describe(state);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(player.isLive ? Icons.radio : Icons.menu_book, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(info.title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(info.subtitle, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                if (player.error != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(player.error!, style: TextStyle(color: theme.colorScheme.error))),
                const SizedBox(height: 16),
                if (!player.isLive && !player.continuousStream) const _SeekBar(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!player.isLive)
                      IconButton(iconSize: 36, tooltip: 'السورة اللي قبلها', icon: const Icon(Icons.skip_next), onPressed: player.previous),
                    const PlayPauseButton(size: 64),
                    if (!player.isLive)
                      IconButton(iconSize: 36, tooltip: 'السورة اللي بعدها', icon: const Icon(Icons.skip_previous), onPressed: player.next),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.bedtime_outlined),
                  label: Text(player.sleepAt == null ? 'مؤقت النوم' : 'هيقف الساعة ${TimeOfDay.fromDateTime(player.sleepAt!).format(context)}'),
                  onPressed: () => showSleepTimerSheet(context, player),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar();

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player.player;
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = player.duration ?? Duration.zero;
        final max = dur.inMilliseconds.toDouble();
        return Column(children: [
          Slider(
            value: max <= 0 ? 0 : pos.inMilliseconds.clamp(0, max).toDouble(),
            max: max <= 0 ? 1 : max,
            onChanged: max <= 0 ? null : (v) => player.seek(Duration(milliseconds: v.round())),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_fmt(pos)), Text(_fmt(dur))]),
          ),
        ]);
      },
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}

void showSleepTimerSheet(BuildContext context, PlayerController player) {
  const options = [15, 30, 45, 60, 90, 120];
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in options)
            ListTile(
              title: Text(m < 60 ? '$m دقيقة' : (m == 60 ? 'ساعة' : (m == 120 ? 'ساعتين' : 'ساعة ونص'))),
              onTap: () {
                player.setSleepTimer(Duration(minutes: m));
                Navigator.pop(ctx);
              },
            ),
          if (player.sleepAt != null)
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: const Text('إلغاء المؤقت'),
              onTap: () {
                player.setSleepTimer(null);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    ),
  );
}
