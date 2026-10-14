import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../download.dart';
import '../models.dart';
import '../prayer/adhkar.dart';
import '../prayer/ics.dart';
import '../prayer/prayer_controller.dart';
import '../prayer/prayer_settings.dart';
import '../prayer/wird.dart';
import '../theme.dart';
import 'adhkar_screen.dart';
import 'prayer_settings_screen.dart';
import 'ui.dart';

/// مواقيت الصلاة، والقبلة، والورد اليومي، والأذكار
class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final prayer = state.prayer;
    return ListenableBuilder(
      listenable: prayer,
      builder: (context, _) {
        final s = prayer.settings;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                PageHeader(
                  title: 'الصلاة',
                  subtitle: s.hasLocation ? s.placeName : 'المواقيت والأذكار والورد',
                  trailing: IconButton(
                    tooltip: 'إعدادات المواقيت والتنبيهات',
                    icon: const Icon(Icons.tune_rounded, color: Retro.brass),
                    onPressed: () => openPrayerSettings(context),
                  ),
                ),
                if (prayer.adhanPlaying) _AdhanBanner(onStop: prayer.stopAdhan),
                if (!s.hasLocation) const _SetupCard() else ...[
                  const _NextPrayerHero(),
                  const SizedBox(height: 14),
                  const _TodayTimes(),
                ],
                const SectionTitle('الورد اليومي'),
                const _WirdCard(),
                const SectionTitle('الأذكار'),
                _AdhkarGrid(sections: prayer.adhkar),
                if (s.hasLocation) ...[
                  const SectionTitle('اتجاه القبلة'),
                  _QiblaCard(degrees: prayer.qibla!),
                ],
                if (kIsWeb) ...[
                  const SectionTitle('التنبيهات على الموبايل'),
                  const _WebAlertsCard(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

void openPrayerSettings(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrayerSettingsScreen()));

class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xFF5A3A1E), Color(0xFF2A1A0E)]),
        border: Border.all(color: Retro.brass.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mosque_rounded, color: Retro.amber, size: 40),
          const SizedBox(height: 10),
          const Text('حدد مدينتك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('علشان نحسب مواقيت الصلاة ونشغّل الأذان في وقته حسب بلدك.',
              style: TextStyle(color: Retro.muted, height: 1.5)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
              icon: const Icon(Icons.location_city_rounded),
              label: const Text('اختار البلد والمدينة'),
              onPressed: () => pickCity(context),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('حدد موقعي'),
              style: OutlinedButton.styleFrom(foregroundColor: Retro.cream, side: const BorderSide(color: Retro.brass)),
              onPressed: () => useMyLocation(context),
            ),
          ]),
        ],
      ),
    );
  }
}

class _AdhanBanner extends StatelessWidget {
  const _AdhanBanner({required this.onStop});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: Retro.amberGlow),
        child: Row(children: [
          const Icon(Icons.volume_up_rounded, color: Color(0xFF2A1A05)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('الأذان شغال', style: TextStyle(color: Color(0xFF2A1A05), fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: onStop,
            child: const Text('إيقاف', style: TextStyle(color: Color(0xFF2A1A05), fontWeight: FontWeight.bold)),
          ),
        ]),
      );
}

/// الصلاة الجاية والعد التنازلي عليها، جوه حلقة نحاسية
class _NextPrayerHero extends StatelessWidget {
  const _NextPrayerHero();

  @override
  Widget build(BuildContext context) {
    final prayer = AppScope.of(context).prayer;
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) {
        final now = DateTime.now();
        final n = prayer.next(now);
        if (n == null) return const SizedBox.shrink();
        final total = n.at.difference(n.previous).inSeconds;
        final left = n.at.difference(now);
        final progress = total <= 0 ? 0.0 : (1 - left.inSeconds / total).clamp(0.0, 1.0);
        String two(int v) => v.toString().padLeft(2, '0');
        final countdown = '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const RadialGradient(center: Alignment(0, -0.4), radius: 1.2, colors: [Color(0xFF4A2F18), Retro.walnutDark]),
            border: Border.all(color: Retro.brass.withValues(alpha: 0.4)),
            boxShadow: [BoxShadow(color: Retro.amber.withValues(alpha: 0.12), blurRadius: 30)],
          ),
          child: Center(
            child: SizedBox.square(
              dimension: 230,
              child: CustomPaint(
                painter: _RingPainter(progress),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('الصلاة الجاية', style: TextStyle(color: Retro.muted, fontSize: 13)),
                    Text(n.name.label,
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Retro.amber, height: 1.4)),
                    Text(countdown,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontFamily: 'NotoSans', fontSize: 30, fontWeight: FontWeight.bold, color: Retro.cream)),
                    const SizedBox(height: 4),
                    Text('الساعة ${formatTime(n.at)}', style: const TextStyle(color: Retro.muted, fontSize: 13)),
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

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    // علامات زي الساعة
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi * 2 / 60 - math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r + 2), c + d * (r + (i % 5 == 0 ? 8 : 5)), Paint()
        ..color = Retro.brass.withValues(alpha: i % 5 == 0 ? 0.7 : 0.3)
        ..strokeWidth = i % 5 == 0 ? 2 : 1);
    }
    final rect = Rect.fromCircle(center: c, radius: r - 6);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.black.withValues(alpha: 0.35));
    final sweep = math.pi * 2 * progress;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(colors: [Retro.amberDeep, Retro.amber, Color(0xFFFFE0A3)], transform: GradientRotation(-math.pi / 2))
          .createShader(rect));
    final end = c + Offset(math.cos(-math.pi / 2 + sweep), math.sin(-math.pi / 2 + sweep)) * (r - 6);
    canvas.drawCircle(end, 9, Paint()
      ..color = Retro.amber.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(end, 5, Paint()..color = const Color(0xFFFFF1CF));
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _TodayTimes extends StatelessWidget {
  const _TodayTimes();

  @override
  Widget build(BuildContext context) {
    final prayer = AppScope.of(context).prayer;
    final now = DateTime.now();
    final today = prayer.timesFor(now)!;
    final next = prayer.next(now);
    return Column(
      children: [
        for (final e in today.times.entries)
          GlowCard(
            active: next != null && next.name == e.key && next.at == e.value,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                Icon(_icon(e.key), color: Retro.brass, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(e.key.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5))),
                Text(formatTime(e.value), style: const TextStyle(fontFamily: 'NotoSans', fontSize: 15, color: Retro.cream)),
                if (e.key.isPrayer)
                  IconButton(
                    tooltip: prayer.settings.adhan.contains(e.key) ? 'الأذان شغال' : 'الأذان مقفول',
                    icon: Icon(
                      prayer.settings.adhan.contains(e.key) ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      color: prayer.settings.adhan.contains(e.key) ? Retro.amber : Retro.muted,
                    ),
                    onPressed: () => prayer.update((s) {
                      if (!s.adhan.remove(e.key)) s.adhan.add(e.key);
                    }),
                  )
                else
                  const SizedBox(width: 48, height: 48),
              ],
            ),
          ),
      ],
    );
  }

  static IconData _icon(PrayerName p) => switch (p) {
        PrayerName.fajr => Icons.nights_stay_outlined,
        PrayerName.sunrise => Icons.wb_twilight_rounded,
        PrayerName.dhuhr => Icons.wb_sunny_rounded,
        PrayerName.asr => Icons.wb_sunny_outlined,
        PrayerName.maghrib => Icons.wb_twilight_outlined,
        PrayerName.isha => Icons.bedtime_outlined,
      };
}

class _WirdCard extends StatelessWidget {
  const _WirdCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final prayer = state.prayer;
    final catalog = state.catalog;
    final juz = prayer.todayJuz;
    final surah = juzStartSurah[juz - 1];
    final done = prayer.wirdDoneToday;
    final moshaf = _wirdMoshaf(state, surah);
    return GlowCard(
      active: !done,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: done ? null : Retro.amberGlow,
              color: done ? Retro.green.withValues(alpha: 0.2) : null,
            ),
            child: done
                ? const Icon(Icons.check_rounded, color: Retro.green, size: 30)
                : Text('$juz',
                    style: const TextStyle(fontFamily: 'NotoSans', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2A1A05))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الجزء ${juzNames[juz - 1]}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  done
                      ? 'خلصت ورد النهارده، تقبّل الله'
                      : 'جزء كل يوم • يبدأ من سورة ${catalog?.surahName(surah) ?? surah}${moshaf != null ? ' بصوت ${moshaf.reciter.name}' : ''}',
                  style: const TextStyle(color: Retro.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (moshaf != null && !done)
            IconButton(
              tooltip: 'شغّل الورد',
              iconSize: 34,
              color: Retro.amber,
              icon: const Icon(Icons.play_circle_fill_rounded),
              onPressed: () => state.player.playMoshaf(moshaf, surah),
            ),
          IconButton(
            tooltip: done ? 'لسه مخلصتوش' : 'خلصته',
            icon: Icon(done ? Icons.undo_rounded : Icons.task_alt_rounded, color: done ? Retro.muted : Retro.green),
            onPressed: () => prayer.markWirdDone(!done),
          ),
        ],
      ),
    );
  }

  /// الورد بصوت آخر شيخ اتسمع، أو أول شيخ في القايمة
  static Moshaf? _wirdMoshaf(AppState state, int surah) {
    final c = state.catalog;
    if (c == null) return null;
    final last = state.lastListen;
    final m = last == null ? null : c.moshaf(last.moshafId);
    if (m != null && m.surahs.contains(surah)) return m;
    final all = c.moshafsWithSurah(surah);
    return all.isEmpty ? null : all.first;
  }
}

class _AdhkarGrid extends StatelessWidget {
  const _AdhkarGrid({required this.sections});

  final List<AdhkarSection> sections;

  static const _icons = {
    'أذكار الصباح': Icons.wb_sunny_rounded,
    'أذكار المساء': Icons.nights_stay_rounded,
    'أذكار بعد السلام من الصلاة المفروضة': Icons.mosque_rounded,
    'تسابيح': Icons.all_inclusive_rounded,
    'أذكار النوم': Icons.bedtime_rounded,
    'أذكار الاستيقاظ': Icons.alarm_rounded,
    'أدعية قرآنية': Icons.menu_book_rounded,
    'أدعية الأنبياء': Icons.auto_awesome_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 92,
        crossAxisSpacing: 10,
      ),
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final s = sections[i];
        final title = s.title == 'أذكار بعد السلام من الصلاة المفروضة' ? 'بعد الصلاة' : s.title;
        return GlowCard(
          padding: const EdgeInsets.all(12),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdhkarScreen(section: s))),
          child: Row(
            children: [
              Icon(_icons[s.title] ?? Icons.auto_stories_rounded, color: Retro.amber, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${s.items.length} ذكر', style: const TextStyle(color: Retro.muted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QiblaCard extends StatelessWidget {
  const _QiblaCard({required this.degrees});

  final double degrees;

  @override
  Widget build(BuildContext context) => GlowCard(
        child: Row(
          children: [
            SizedBox.square(dimension: 86, child: CustomPaint(painter: _CompassPainter(degrees))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${degrees.round()}°',
                      style: const TextStyle(fontFamily: 'NotoSans', fontSize: 26, fontWeight: FontWeight.bold, color: Retro.amber)),
                  const Text('من الشمال في اتجاه عقارب الساعة', style: TextStyle(color: Retro.muted, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  const Text('وجّه أعلى الموبايل للشمال، والسهم بيشاور على الكعبة',
                      style: TextStyle(color: Retro.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CompassPainter extends CustomPainter {
  _CompassPainter(this.degrees);

  final double degrees;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()
      ..shader = const RadialGradient(colors: [Color(0xFFF7E7C4), Color(0xFFD9BC85)]).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Retro.brassDark);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 - math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * r * 0.72, c + d * r * 0.9, Paint()
        ..color = const Color(0xFF3B2A16)
        ..strokeWidth = 2);
    }
    final tp = TextPainter(
      text: const TextSpan(text: 'N', style: TextStyle(fontFamily: 'NotoSans', fontWeight: FontWeight.bold, fontSize: 11, color: Retro.red)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c + Offset(-tp.width / 2, -r * 0.68));
    final a = degrees * math.pi / 180 - math.pi / 2;
    final d = Offset(math.cos(a), math.sin(a));
    final tip = c + d * r * 0.78;
    final side = Offset(-d.dy, d.dx) * 5;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((c + side).dx, (c + side).dy)
        ..lineTo((c - side).dx, (c - side).dy)
        ..close(),
      Paint()..color = const Color(0xFF1E6B50),
    );
    canvas.drawCircle(tip, 5, Paint()..color = const Color(0xFF1C140C));
    canvas.drawCircle(c, 4, Paint()..color = Retro.brassDark);
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.degrees != degrees;
}

/// على الويب (الآيفون): التنبيهات بتشتغل والموقع مفتوح بس، وللتنبيه والموقع
/// مقفول بنضيف المواعيد لتقويم الموبايل
class _WebAlertsCard extends StatelessWidget {
  const _WebAlertsCard();

  @override
  Widget build(BuildContext context) {
    final prayer = AppScope.of(context).prayer;
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الموقع بيطلّع التنبيهات ويشغّل الأذان طول ما هو مفتوح. علشان توصلك التنبيهات والموبايل مقفول، ضيف المواعيد لتقويم الموبايل (على الآيفون بيفتح "إضافة الكل").',
            style: TextStyle(color: Retro.muted, height: 1.6, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
              icon: const Icon(Icons.notifications_active_rounded),
              label: const Text('فعّل التنبيهات'),
              onPressed: () async {
                final ok = await prayer.notifier.requestPermission();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? 'تمام، التنبيهات اشتغلت' : 'المتصفح مرضيش يسمح بالتنبيهات'),
                  ));
                }
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_rounded),
              label: const Text('ضيف لتقويم الموبايل (30 يوم)'),
              style: OutlinedButton.styleFrom(foregroundColor: Retro.cream, side: const BorderSide(color: Retro.brass)),
              onPressed: prayer.settings.hasLocation || prayer.settings.morningAdhkar
                  ? () => downloadText('azkar-elmuslim.ics', buildIcs(prayer.buildAlerts(days: 30)), 'text/calendar')
                  : null,
            ),
          ]),
        ],
      ),
    );
  }
}
