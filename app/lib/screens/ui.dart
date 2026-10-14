import 'package:flutter/material.dart';

import '../theme.dart';

/// عنوان الصفحة الكبير اللي فوق
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Retro.cream,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Retro.muted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// كارت داكن بحرف نحاسي، وبينوّر لما يكون نشط
class GlowCard extends StatelessWidget {
  const GlowCard({
    super.key,
    required this.child,
    this.active = false,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final bool active;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: active
              ? const [Color(0xFF3E2A15), Color(0xFF241A10)]
              : const [Retro.panelHigh, Retro.panel],
        ),
        border: Border.all(
          color: active
              ? Retro.amber.withValues(alpha: 0.7)
              : Retro.line.withValues(alpha: 0.7),
        ),
        boxShadow: [
          if (active)
            BoxShadow(
              color: Retro.amber.withValues(alpha: 0.18),
              blurRadius: 22,
              spreadRadius: -2,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          splashColor: Retro.amber.withValues(alpha: 0.12),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// أول حرف من اسم الشيخ في دايرة نحاسية
class Monogram extends StatelessWidget {
  const Monogram({super.key, required this.name, this.size = 48});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? '' : name.characters.first;
    final hue = (name.hashCode % 40).toDouble();
    final inner = HSLColor.fromAHSL(1, 20 + hue, 0.45, 0.22).toColor();
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFFF1DDB0),
            Retro.brassDark,
            Retro.brass,
            Color(0xFFF1DDB0),
          ],
        ),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [Color.lerp(inner, Colors.white, 0.12)!, inner],
          ),
        ),
        child: Text(
          letter,
          style: TextStyle(
            color: Retro.cream,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.42,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// نقطة حمرا بتنبض جنب كلمة مباشر
class LiveDot extends StatefulWidget {
  const LiveDot({super.key});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Retro.red,
            boxShadow: [
              BoxShadow(color: Retro.red.withValues(alpha: 0.7), blurRadius: 6),
            ],
          ),
        ),
      ),
      const SizedBox(width: 5),
      const Text(
        'مباشر',
        style: TextStyle(
          color: Retro.red,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}
