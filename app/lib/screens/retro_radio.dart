import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../app_state.dart';
import '../models.dart';
import '../player.dart';
import '../theme.dart';
import 'player_widgets.dart';

/// أسماء بعض الإذاعات جاية بشرط في الآخر ("تلاوات خاشعة-")
String cleanName(String name) =>
    name.replaceAll(RegExp(r'[\s\-–]+$'), '').trim();

/// تردد شكلي لكل إذاعة على المؤشر، من 88 لـ 108 زي الراديو
String frequencyOf(int index, int count) {
  if (count <= 0 || index < 0) return '--.-';
  final f = 88.0 + (index + 0.5) * 20.0 / count;
  return f.toStringAsFixed(1);
}

/// مكان إبرة المؤشر من 0 لـ 1
double dialValue(AppState state) {
  final p = state.player.playback;
  switch (p) {
    case LivePlayback(:final channel):
      final list = state.catalog?.channels ?? const <LiveChannel>[];
      final i = list.indexWhere((c) => c.id == channel.id);
      return i < 0 ? 0.5 : (i + 0.5) / list.length;
    case MoshafPlayback():
      final s = state.player.currentSurah ?? p.startSurah;
      return ((s - 1) / 113).clamp(0.0, 1.0);
    case null:
      return 0.04;
  }
}

/// بيشغّل عدّاد أنيميشن طول ما الصوت شغال، ويهدّيه بالراحة لما يقف
class PlayingAnimator extends StatefulWidget {
  const PlayingAnimator({super.key, required this.builder});

  /// [t] بيلف من 0 لـ 1 كل 4 ثواني، و[energy] من 0 (واقف) لـ 1 (شغال)
  final Widget Function(BuildContext context, double t, double energy) builder;

  @override
  State<PlayingAnimator> createState() => _PlayingAnimatorState();
}

class _PlayingAnimatorState extends State<PlayingAnimator>
    with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  late final AnimationController _energy = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  StreamSubscription<PlayerState>? _sub;

  @override
  void initState() {
    super.initState();
    _energy.addStatusListener((s) {
      if (s == AnimationStatus.dismissed) _clock.stop();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub == null) {
      _controller = AppScope.of(context).player;
      _sub = _controller!.player.playerStateStream.listen((_) => _onState());
      _controller!.waiting.addListener(_onState);
    }
  }

  PlayerController? _controller;

  void _onState() {
    final c = _controller!;
    final s = c.player.playerState;
    final active = s.playing &&
        s.processingState != ProcessingState.idle &&
        s.processingState != ProcessingState.completed &&
        !c.waiting.value;
    if (active) {
      if (!_clock.isAnimating) _clock.repeat();
      _energy.forward();
    } else {
      _energy.reverse();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller?.waiting.removeListener(_onState);
    _clock.dispose();
    _energy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_clock, _energy]),
    builder: (context, _) => widget.builder(
      context,
      _clock.value,
      Curves.easeOut.transform(_energy.value),
    ),
  );
}

/// مستوى صوت "شكلي" بيتحرك بنعومة. الترددات أعداد صحيحة علشان اللفة تكمّل من غير قفزة
double signalLevel(double t, double seed) {
  const tau = math.pi * 2;
  final v =
      0.52 +
      0.2 * math.sin(tau * (3 * t + seed)) +
      0.14 * math.sin(tau * (7 * t + seed * 1.7)) +
      0.09 * math.sin(tau * (13 * t + seed * 2.3)) +
      0.05 * math.sin(tau * (29 * t + seed * 3.1));
  return v.clamp(0.0, 1.0);
}

/// الراديو القديم: صندوق خشب، مؤشر كهرمان، عدّاد VU، سماعة، وزراير دوّارة
class RetroRadio extends StatelessWidget {
  const RetroRadio({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final player = state.player;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final info = describe(state);
        final idle = player.playback == null;
        return PlayingAnimator(
          builder: (context, t, energy) => Container(
            constraints: const BoxConstraints(maxWidth: 560),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: Retro.amber.withValues(alpha: 0.10 + 0.12 * energy),
                  blurRadius: 60,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: CustomPaint(
                painter: _WoodPainter(),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Retro.brass.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Header(
                        onAir: energy > 0.5,
                        isLive: player.isLive,
                        idle: idle,
                      ),
                      const SizedBox(height: 12),
                      _DialWindow(
                        value: dialValue(state),
                        energy: energy,
                        t: t,
                        isLive: player.isLive,
                        idle: idle,
                      ),
                      const SizedBox(height: 12),
                      _Faceplate(
                        title: idle ? 'اختار إذاعة أو شيخ' : info.title,
                        subtitle: idle
                            ? 'اضغط تشغيل وابدأ بإذاعة القرآن الكريم'
                            : (player.error ?? info.subtitle),
                        t: t,
                        energy: energy,
                      ),
                      const SizedBox(height: 14),
                      _Controls(t: t, energy: energy),
                    ],
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

class _Header extends StatelessWidget {
  const _Header({
    required this.onAir,
    required this.isLive,
    required this.idle,
  });

  final bool onAir;
  final bool isLive;
  final bool idle;

  @override
  Widget build(BuildContext context) {
    final label = idle ? 'جاهز' : (isLive ? 'على الهواء' : 'تلاوة');
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onAir ? Retro.red : const Color(0xFF4A2A22),
            boxShadow: onAir
                ? [
                    BoxShadow(
                      color: Retro.red.withValues(alpha: 0.8),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Retro.brass,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFFE9D3A4), Retro.brass, Color(0xFF9C7A45)],
          ).createShader(r),
          child: const Text(
            'أذكار المسلم',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.radio, color: Retro.brass, size: 18),
      ],
    );
  }
}

class _DialWindow extends StatelessWidget {
  const _DialWindow({
    required this.value,
    required this.energy,
    required this.t,
    required this.isLive,
    required this.idle,
  });

  final double value;
  final double energy;
  final double t;
  final bool isLive;
  final bool idle;

  @override
  Widget build(BuildContext context) {
    final glow = idle ? 0.45 : 0.6 + 0.4 * energy;
    return Container(
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A110A), width: 3),
        boxShadow: [
          BoxShadow(
            color: Retro.amber.withValues(alpha: 0.25 * glow),
            blurRadius: 24,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOutBack,
          builder: (context, v, _) => CustomPaint(
            painter: _DialPainter(
              value: v,
              glow: glow,
              wobble: energy * 0.004 * math.sin(t * math.pi * 2 * 5),
              surahs: !isLive && !idle,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.value,
    required this.glow,
    required this.wobble,
    required this.surahs,
  });

  final double value;
  final double glow;
  final double wobble;
  final bool surahs;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // الزجاج المنوّر من ورا
    final bg = Color.lerp(
      const Color(0xFF3A2410),
      const Color(0xFFF6C46E),
      glow,
    )!;
    final edge = Color.lerp(
      const Color(0xFF1E1208),
      const Color(0xFFB9661E),
      glow,
    )!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [bg, edge],
          radius: 1.1,
        ).createShader(rect),
    );

    const pad = 18.0;
    final w = size.width - pad * 2;
    final ink = Color.lerp(
      const Color(0xFF7A5530),
      const Color(0xFF3B2008),
      glow,
    )!;
    final tick = Paint()
      ..color = ink
      ..strokeWidth = 1.2;

    // المقياس اللي فوق: 88 لـ 108 (أو أرقام السور)
    for (var i = 0; i <= 40; i++) {
      final x = pad + w * i / 40;
      final major = i % 8 == 0;
      canvas.drawLine(
        Offset(x, 26),
        Offset(x, major ? 40 : 34),
        tick..strokeWidth = major ? 1.6 : 1,
      );
      if (major) {
        final label = surahs
            ? '${1 + (113 * i / 40).round()}'
            : '${88 + i ~/ 2}';
        _text(canvas, label, Offset(x, 14), ink, 11, bold: true);
      }
    }
    // المقياس اللي تحت
    for (var i = 0; i <= 20; i++) {
      final x = pad + w * i / 20;
      canvas.drawCircle(
        Offset(x, 62),
        i % 5 == 0 ? 2.2 : 1.2,
        Paint()..color = ink.withValues(alpha: 0.8),
      );
    }
    canvas.drawLine(
      Offset(pad, 62),
      Offset(pad + w, 62),
      Paint()
        ..color = ink.withValues(alpha: 0.35)
        ..strokeWidth = 0.8,
    );
    _text(
      canvas,
      surahs ? 'السور' : 'FM',
      Offset(pad + 22, 80),
      ink.withValues(alpha: 0.9),
      10,
      bold: true,
    );
    _text(
      canvas,
      surahs ? '114' : 'MHz',
      Offset(size.width - pad - 22, 80),
      ink.withValues(alpha: 0.9),
      10,
      bold: true,
    );
    _text(
      canvas,
      'إذاعة القرآن الكريم',
      Offset(size.width / 2, 80),
      ink.withValues(alpha: 0.75),
      10,
    );

    // الإبرة
    final nx = pad + w * (value + wobble).clamp(0.0, 1.0);
    canvas.drawLine(
      Offset(nx, 4),
      Offset(nx, size.height - 4),
      Paint()
        ..color = Retro.red.withValues(alpha: 0.45)
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawLine(
      Offset(nx, 4),
      Offset(nx, size.height - 4),
      Paint()
        ..color = const Color(0xFFD62F1E)
        ..strokeWidth = 2.4,
    );

    // انعكاس الزجاج
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    // تظليل الحواف
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.35),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.35),
          ],
          stops: const [0, 0.08, 0.92, 1],
        ).createShader(rect),
    );
  }

  void _text(
    Canvas canvas,
    String s,
    Offset center,
    Color color,
    double size, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: 'NotoSans',
          fontFamilyFallback: const ['NotoSansArabic'],
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.value != value ||
      old.glow != glow ||
      old.wobble != wobble ||
      old.surahs != surahs;
}

class _Faceplate extends StatelessWidget {
  const _Faceplate({
    required this.title,
    required this.subtitle,
    required this.t,
    required this.energy,
  });

  final String title;
  final String subtitle;
  final double t;
  final double energy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14100C), Color(0xFF221A12)],
        ),
        border: Border.all(color: Colors.black.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 58,
            child: CustomPaint(
              painter: _VuPainter(level: energy * signalLevel(t, 0.13)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(title + subtitle),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Retro.cream,
                      fontSize: 17,
                      height: 1.3,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Retro.amber.withValues(alpha: 0.5 * energy),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Retro.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VuPainter extends CustomPainter {
  _VuPainter({required this.level});

  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7E7C4), Color(0xFFE3C893)],
        ).createShader(rect),
    );

    final pivot = Offset(size.width / 2, size.height * 1.15);
    final radius = size.height * 0.95;
    const start = -math.pi * 0.78, end = -math.pi * 0.22;
    final arc = Rect.fromCircle(center: pivot, radius: radius * 0.82);
    canvas.drawArc(
      arc,
      start,
      (end - start) * 0.72,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF3B2A16),
    );
    canvas.drawArc(
      arc,
      start + (end - start) * 0.72,
      (end - start) * 0.28,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFC6382A),
    );
    for (var i = 0; i <= 10; i++) {
      final a = start + (end - start) * i / 10;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        pivot + dir * radius * 0.82,
        pivot + dir * radius * (i.isEven ? 0.94 : 0.89),
        Paint()
          ..color = i >= 8 ? const Color(0xFFC6382A) : const Color(0xFF3B2A16)
          ..strokeWidth = 1.1,
      );
    }
    final tp = TextPainter(
      text: const TextSpan(
        text: 'VU',
        style: TextStyle(
          color: Color(0xFF3B2A16),
          fontSize: 9,
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.width / 2 - tp.width / 2, size.height - tp.height - 4),
    );

    final a = start + (end - start) * level;
    final tip = pivot + Offset(math.cos(a), math.sin(a)) * radius;
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawLine(
      pivot,
      tip,
      Paint()
        ..color = const Color(0xFF1C140C)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    canvas.drawRRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.15),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_VuPainter old) => old.level != level;
}

class _Controls extends StatelessWidget {
  const _Controls({required this.t, required this.energy});

  final double t;
  final double energy;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final player = state.player;
    final live = player.isLive;
    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RotaryKnob(
            label: live ? 'المحطة التالية' : 'السورة التالية',
            onTap: () => _step(state, 1),
            direction: 1,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CustomPaint(
                      painter: _GrillePainter(
                        level: energy * signalLevel(t, 0.61),
                        energy: energy,
                      ),
                    ),
                  ),
                ),
                _PlayButton(onIdleTap: () => _startDefault(state)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          RotaryKnob(
            label: live ? 'المحطة السابقة' : 'السورة السابقة',
            onTap: () => _step(state, -1),
            direction: -1,
          ),
        ],
      ),
    );
  }

  static void _startDefault(AppState state) {
    final channels = state.catalog?.channels ?? const <LiveChannel>[];
    if (channels.isNotEmpty) state.player.playLive(channels.first);
  }

  /// الزرار الدوّار: في اللايف بيقلّب بين المحطات، وفي المصحف بين السور
  static void _step(AppState state, int delta) {
    final player = state.player;
    final p = player.playback;
    if (p is LivePlayback) {
      final list = state.catalog?.channels ?? const <LiveChannel>[];
      if (list.isEmpty) return;
      final i = list.indexWhere((c) => c.id == p.channel.id);
      player.playLive(list[((i < 0 ? 0 : i) + delta) % list.length]);
    } else if (p is MoshafPlayback) {
      delta > 0 ? player.next() : player.previous();
    } else {
      _startDefault(state);
    }
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onIdleTap});

  final VoidCallback onIdleTap;

  @override
  Widget build(BuildContext context) {
    final player = AppScope.of(context).player;
    return StreamBuilder<PlayerState>(
      stream: player.player.playerStateStream,
      builder: (context, snap) {
        final s = snap.data;
        final playing = s?.playing ?? false;
        return ValueListenableBuilder<bool>(
          valueListenable: player.waiting,
          builder: (context, loading, _) => Tooltip(
          message: playing ? 'إيقاف مؤقت' : 'تشغيل',
          child: GestureDetector(
            onTap: player.playback == null ? onIdleTap : player.toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  colors: [Color(0xFFFFE3A8), Retro.amber, Color(0xFFB0661C)],
                  stops: [0, 0.45, 1],
                ),
                border: Border.all(color: const Color(0xFF2A1A0B), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Retro.amber.withValues(alpha: playing ? 0.65 : 0.25),
                    blurRadius: playing ? 28 : 12,
                    spreadRadius: playing ? 2 : 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFF2A1A05),
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (c, a) =>
                          ScaleTransition(scale: a, child: c),
                      child: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey(playing),
                        size: 44,
                        color: const Color(0xFF2A1A05),
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

/// زرار دوّار نحاسي، بيلف شوية مع كل ضغطة
class RotaryKnob extends StatefulWidget {
  const RotaryKnob({
    super.key,
    required this.label,
    required this.onTap,
    required this.direction,
    this.size = 64,
  });

  final String label;
  final VoidCallback onTap;
  final int direction;
  final double size;

  @override
  State<RotaryKnob> createState() => _RotaryKnobState();
}

class _RotaryKnobState extends State<RotaryKnob> {
  double _turns = 0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTap: () {
            setState(() => _turns += widget.direction * 0.12);
            widget.onTap();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedRotation(
                turns: _turns,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutBack,
                child: SizedBox.square(
                  dimension: widget.size,
                  child: CustomPaint(painter: _KnobPainter()),
                ),
              ),
              const SizedBox(height: 6),
              // الأسهم بتشاور ناحية حركة الإبرة على المؤشر (من الشمال لليمين)
              Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(
                  widget.direction > 0
                      ? Icons.skip_next_rounded
                      : Icons.skip_previous_rounded,
                  size: 18,
                  color: Retro.brass,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c + const Offset(0, 4),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // الحزوز اللي على الحرف
    final ridge = Paint()
      ..color = const Color(0xFF1B140D)
      ..strokeWidth = 1.4;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF3A2C1E));
    for (var i = 0; i < 36; i++) {
      final a = i * math.pi * 2 / 36;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * r * 0.86, c + d * r, ridge);
    }
    canvas.drawCircle(
      c,
      r * 0.82,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          colors: [Color(0xFFF1DDB0), Retro.brass, Retro.brassDark],
          stops: [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.82)),
    );
    // لمعة معدن مصقول
    canvas.drawCircle(
      c,
      r * 0.62,
      Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.62)),
    );
    // علامة الاتجاه
    canvas.drawLine(
      c - Offset(0, r * 0.68),
      c - Offset(0, r * 0.38),
      Paint()
        ..color = const Color(0xFF2A1A0B)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) => false;
}

class _GrillePainter extends CustomPainter {
  _GrillePainter({required this.level, required this.energy});

  final double level;
  final double energy;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B2016), Color(0xFF17110B)],
        ).createShader(rect),
    );
    final c = rect.center;
    final maxD = size.longestSide / 2;
    const step = 9.0;
    var row = 0;
    for (var y = step / 2; y < size.height; y += step * 0.87, row++) {
      for (var x = (row.isOdd ? step : step / 2); x < size.width; x += step) {
        final p = Offset(x, y);
        final d = ((p - c).distance / maxD).clamp(0.0, 1.0);
        // الإضاءة بتنبض من النص مع الصوت
        final glow = energy * (1 - d) * (0.35 + 0.65 * level);
        final color = Color.lerp(
          const Color(0xFF080503),
          Retro.amber,
          glow * 0.85,
        )!;
        canvas.drawCircle(p, 2.3, Paint()..color = color);
      }
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
          radius: 0.9,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GrillePainter old) =>
      old.level != level || old.energy != energy;
}

class _WoodPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6B4528),
            Retro.walnut,
            Color(0xFF3B2414),
            Retro.walnutDark,
          ],
          stops: [0, 0.35, 0.75, 1],
        ).createShader(rect),
    );
    // عروق الخشب
    final rnd = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final y0 = size.height * i / 26 + rnd.nextDouble() * 8;
      final amp = 3 + rnd.nextDouble() * 7;
      final freq = 1 + rnd.nextDouble() * 2.5;
      final phase = rnd.nextDouble() * math.pi * 2;
      final path = Path()..moveTo(0, y0);
      for (var x = 0.0; x <= size.width; x += 8) {
        path.lineTo(
          x,
          y0 + amp * math.sin(x / size.width * math.pi * 2 * freq + phase),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6 + rnd.nextDouble() * 1.4
          ..color = (i.isEven ? Colors.black : const Color(0xFFE0B080))
              .withValues(alpha: 0.05 + rnd.nextDouble() * 0.06),
      );
    }
    // لمعة الورنيش
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.25),
          ],
          stops: const [0, 0.4, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_WoodPainter old) => false;
}

/// أعمدة إكولايزر صغيرة بتتحرك مع التشغيل
class EqualizerBars extends StatelessWidget {
  const EqualizerBars({
    super.key,
    this.color = Retro.amber,
    this.height = 18,
    this.bars = 4,
  });

  final Color color;
  final double height;
  final int bars;

  @override
  Widget build(BuildContext context) => PlayingAnimator(
    builder: (context, t, energy) => SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bars; i++)
            Container(
              width: 3.5,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              height:
                  height *
                  (0.18 + 0.82 * energy * signalLevel(t, i * 0.37 + 0.1)),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    ),
  );
}
