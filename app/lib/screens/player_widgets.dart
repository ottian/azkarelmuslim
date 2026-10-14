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
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: const NowPlayingPanel()),
          ),
        ),
      );
}

/// الراديو الكبير ومعاه شريط الوقت والتكرار والسرعة ومؤقت النوم
class NowPlayingPanel extends StatelessWidget {
  const NowPlayingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RetroRadio(),
          const SizedBox(height: 16),
          if (player.playback != null && !player.isLive && !player.continuousStream) const _SeekBar(),
          const SizedBox(height: 8),
          const PlayerExtras(),
        ],
      ),
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

/// تكرار السورة، والسرعة، ومؤقت النوم
class PlayerExtras extends StatelessWidget {
  const PlayerExtras({super.key});

  static const speeds = [0.75, 1.0, 1.25, 1.5];

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final moshaf = player.playback is MoshafPlayback && !player.continuousStream;
        final sleeping = player.sleepAt != null || player.stopAtSurahEnd;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (moshaf)
              _Pill(
                icon: Icons.repeat_one_rounded,
                label: 'تكرار السورة',
                active: player.repeatSurah,
                onTap: () => player.setRepeatSurah(!player.repeatSurah),
              ),
            if (moshaf)
              PopupMenuButton<double>(
                tooltip: 'سرعة التلاوة',
                color: Retro.panelHigh,
                initialValue: player.speed,
                onSelected: player.setSpeed,
                itemBuilder: (_) => [
                  for (final v in speeds) PopupMenuItem(value: v, child: Text(_speedLabel(v))),
                ],
                child: _Pill(icon: Icons.speed_rounded, label: _speedLabel(player.speed), active: player.speed != 1.0),
              ),
            _Pill(
              icon: Icons.bedtime_outlined,
              label: player.stopAtSurahEnd
                  ? 'هيقف آخر السورة'
                  : player.sleepAt == null
                      ? 'مؤقت النوم'
                      : 'هيقف ${TimeOfDay.fromDateTime(player.sleepAt!).format(context)}',
              active: sleeping,
              onTap: () => showSleepTimerSheet(context, player),
            ),
          ],
        );
      },
    );
  }

  static String _speedLabel(double v) => v == 1.0 ? 'السرعة العادية' : '${v}x';
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.active = false, this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? const Color(0xFF2A1A05) : Retro.brass;
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: active ? Retro.amberGlow : null,
        color: active ? null : Retro.panel,
        border: Border.all(color: active ? Colors.transparent : Retro.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
    if (onTap == null) return body;
    return InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: body);
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
          if (player.playback is MoshafPlayback)
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: const Text('لما السورة دي تخلص'),
              onTap: () {
                player.setStopAtSurahEnd(true);
                Navigator.pop(ctx);
              },
            ),
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
          if (player.sleepAt != null || player.stopAtSurahEnd)
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: const Text('إلغاء المؤقت'),
              onTap: () {
                player.setStopAtSurahEnd(false);
                player.setSleepTimer(null);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    ),
  );
}
