import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../prayer/adhkar.dart';
import '../theme.dart';

/// قراءة الأذكار بعدّاد: كل ضغطة على الذكر بتنقّص واحد لحد ما يخلص
class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({super.key, required this.section});

  final AdhkarSection section;

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  late List<int> _left = [for (final d in widget.section.items) d.count];

  int get _done => [for (var i = 0; i < _left.length; i++) if (_left[i] == 0) i].length;

  void _tap(int i) {
    if (_left[i] == 0) return;
    HapticFeedback.lightImpact();
    setState(() => _left[i]--);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.section.items;
    final progress = items.isEmpty ? 0.0 : _done / items.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.section.title),
        actions: [
          IconButton(
            tooltip: 'ابدأ من الأول',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () => setState(() => _left = [for (final d in items) d.count]),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: Retro.panel),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$_done من ${items.length}', style: const TextStyle(color: Retro.muted, fontSize: 12)),
            ]),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: items.length,
        itemBuilder: (context, i) => _DhikrCard(dhikr: items[i], left: _left[i], onTap: () => _tap(i)),
      ),
    );
  }
}

class _DhikrCard extends StatelessWidget {
  const _DhikrCard({required this.dhikr, required this.left, required this.onTap});

  final Dhikr dhikr;
  final int left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = left == 0;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: done ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Retro.panelHigh, Retro.panel]),
          border: Border.all(color: done ? Retro.green.withValues(alpha: 0.5) : Retro.line),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(dhikr.text, style: const TextStyle(fontSize: 19, height: 1.9, color: Retro.cream)),
                  if (dhikr.note.isNotEmpty || dhikr.ref.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      [dhikr.note, dhikr.ref].where((e) => e.isNotEmpty).join('  '),
                      style: const TextStyle(color: Retro.muted, fontSize: 12.5, height: 1.6),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(dhikr.count > 1 ? 'التكرار: ${dhikr.count}' : 'مرة واحدة',
                          style: const TextStyle(color: Retro.brass, fontSize: 12)),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        constraints: const BoxConstraints(minWidth: 54),
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: done ? null : Retro.amberGlow,
                          color: done ? Retro.green.withValues(alpha: 0.2) : null,
                        ),
                        child: done
                            ? const Icon(Icons.check_rounded, color: Retro.green)
                            : Text('$left',
                                style: const TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: Color(0xFF2A1A05),
                                )),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
