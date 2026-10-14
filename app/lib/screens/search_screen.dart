import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'reciter_screen.dart';
import 'reciters_screen.dart';
import 'surahs_screen.dart';
import 'ui.dart';

/// بتشيل التشكيل وبتوحّد الألف والياء والتاء المربوطة علشان "الحصري" تلاقي "الحُصري"
String normalizeArabic(String s) => s
    .replaceAll(RegExp('[ً-ٰٟـ]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

/// كل كلمة في البحث لازم تكون موجودة في النص
bool matchesQuery(String text, String query) {
  final t = normalizeArabic(text);
  return normalizeArabic(query).split(' ').every(t.contains);
}

/// زرار البحث الشامل اللي في أول الصفحات
class SearchButton extends StatelessWidget {
  const SearchButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: 'بحث في القراء والسور والإذاعات',
    icon: const Icon(Icons.search_rounded),
    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
  );
}

/// بحث واحد في القراء والسور والإذاعات
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final catalog = state.catalog;
    final q = _query.replaceAll('سورة', '').trim();
    final reciters = <Reciter>[], suwar = <Surah>[], channels = <LiveChannel>[];
    if (catalog != null && q.isNotEmpty) {
      reciters.addAll(
        catalog.reciters.where((r) => matchesQuery(r.name, q) || r.moshafs.any((m) => matchesQuery(m.label, q))),
      );
      final n = int.tryParse(q);
      suwar.addAll(catalog.suwar.where((s) => n != null ? s.id == n : matchesQuery(s.name, q)));
      channels.addAll(catalog.channels.where((c) => matchesQuery(c.name, q)));
    }
    final empty = q.isNotEmpty && reciters.isEmpty && suwar.isEmpty && channels.isEmpty;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'اسم شيخ أو سورة أو إذاعة',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
      ),
      body: catalog == null
          ? CatalogStatus(state: state)
          : q.isEmpty
          ? const _Hint(icon: Icons.manage_search_rounded, text: 'ابحث في القراء والسور والإذاعات مرة واحدة')
          : empty
          ? const _Hint(icon: Icons.search_off_rounded, text: 'مفيش نتايج')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (reciters.isNotEmpty) ...[
                  _Title('القراء', reciters.length),
                  for (final r in reciters.take(30))
                    _Result(
                      leading: Monogram(photo: r.photo, name: r.name, size: 42),
                      title: r.name,
                      subtitle: r.moshafs.map((m) => m.label).toSet().join(' • '),
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReciterScreen(reciter: r))),
                    ),
                ],
                if (suwar.isNotEmpty) ...[
                  _Title('السور', suwar.length),
                  for (final s in suwar.take(30))
                    _Result(
                      leading: SurahNumber(number: s.id),
                      title: 'سورة ${s.name}',
                      subtitle: '${s.makkia ? 'مكية' : 'مدنية'} • ${catalog.moshafsWithSurah(s.id).length} تلاوة',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SurahScreen(surah: s))),
                    ),
                ],
                if (channels.isNotEmpty) ...[
                  _Title('الإذاعات', channels.length),
                  for (final c in channels.take(30))
                    _Result(
                      leading: const SizedBox(width: 42, child: Icon(Icons.radio_rounded, color: Retro.amber)),
                      title: c.name,
                      subtitle: c.group.isEmpty ? 'بث مباشر' : 'بث مباشر • ${c.group}',
                      onTap: () {
                        state.player.playLive(c);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ],
            ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, this.count);

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
    child: Text(
      '$text ($count)',
      style: const TextStyle(color: Retro.brass, fontWeight: FontWeight.bold, fontSize: 14),
    ),
  );
}

class _Result extends StatelessWidget {
  const _Result({required this.leading, required this.title, required this.subtitle, required this.onTap});

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GlowCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Retro.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Retro.line),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Retro.muted),
          ),
        ],
      ),
    ),
  );
}
