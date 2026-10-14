import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../app_state.dart';
import '../player.dart';
import '../theme.dart';
import 'retro_radio.dart';

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
        final visible = player.playback != null;
        final info = describe(state);
        return AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          child: !visible
              ? const SizedBox(width: double.infinity)
              : SafeArea(
                  top: false,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    child: Material(
                      color: Colors.transparent,
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4A2F1B), Retro.walnutDark],
                          ),
                          border: Border.all(
                            color: Retro.brass.withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => showPlayerSheet(context),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              14,
                              8,
                              6,
                              8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: const Color(0xFF15100B),
                                    border: Border.all(color: Colors.black),
                                  ),
                                  child: const EqualizerBars(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        info.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Retro.cream,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      Text(
                                        player.error ?? info.subtitle,
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
                                const PlayPauseButton(size: 40),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Retro.muted,
                                  ),
                                  tooltip: 'إيقاف',
                                  onPressed: player.stop,
                                ),
                              ],
                            ),
                          ),
                        ),
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
        final loading =
            s?.processingState == ProcessingState.loading ||
            s?.processingState == ProcessingState.buffering;
        if (loading && s?.playing == true) {
          return SizedBox(
            width: size + 16,
            height: size + 16,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        }
        final playing = s?.playing ?? false;
        return IconButton(
          iconSize: size,
          tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل',
          color: Retro.amber,
          icon: Icon(
            playing
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_fill_rounded,
          ),
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
    LivePlayback(:final channel) => PlaybackInfo(
      cleanName(channel.name),
      'بث مباشر 24 ساعة',
    ),
    MoshafPlayback(:final moshaf) => PlaybackInfo(
      state.player.currentSurah == null
          ? moshaf.reciter.name
          : 'سورة ${catalog?.surahName(state.player.currentSurah!) ?? state.player.currentSurah}',
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
    backgroundColor: Retro.night,
    builder: (_) => const _PlayerSheet(),
  );
}

class _PlayerSheet extends StatelessWidget {
  const _PlayerSheet();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final player = state.player;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RetroRadio(),
                    const SizedBox(height: 16),
                    if (player.playback != null &&
                        !player.isLive &&
                        !player.continuousStream)
                      const _SeekBar(),
                    TextButton.icon(
                      icon: const Icon(
                        Icons.bedtime_outlined,
                        color: Retro.brass,
                      ),
                      label: Text(
                        player.sleepAt == null
                            ? 'مؤقت النوم'
                            : 'هيقف الساعة ${TimeOfDay.fromDateTime(player.sleepAt!).format(context)}',
                        style: const TextStyle(color: Retro.brass),
                      ),
                      onPressed: () => showSleepTimerSheet(context, player),
                    ),
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
        return Column(
          children: [
            Slider(
              value: max <= 0 ? 0 : pos.inMilliseconds.clamp(0, max).toDouble(),
              max: max <= 0 ? 1 : max,
              onChanged: max <= 0
                  ? null
                  : (v) => player.seek(Duration(milliseconds: v.round())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(pos),
                    style: const TextStyle(
                      color: Retro.muted,
                      fontFamily: 'NotoSans',
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _fmt(dur),
                    style: const TextStyle(
                      color: Retro.muted,
                      fontFamily: 'NotoSans',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
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
              title: Text(
                m < 60
                    ? '$m دقيقة'
                    : (m == 60 ? 'ساعة' : (m == 120 ? 'ساعتين' : 'ساعة ونص')),
              ),
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
