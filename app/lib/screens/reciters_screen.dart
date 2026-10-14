import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'reciter_screen.dart';
import 'ui.dart';

class RecitersScreen extends StatefulWidget {
  const RecitersScreen({super.key});

  @override
  State<RecitersScreen> createState() => _RecitersScreenState();
}

class _RecitersScreenState extends State<RecitersScreen> {
  String _query = '';
  int? _rewaya;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final catalog = state.catalog;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: catalog == null
            ? CatalogStatus(state: state)
            : Column(
                children: [
                  PageHeader(
                    title: 'القراء',
                    subtitle:
                        'أشهر ${catalog.reciters.length} قارئ بكل رواياتهم',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'ابحث باسم الشيخ',
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                  SizedBox(
                    height: 58,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      children: [
                        _chip('كل الروايات', null),
                        for (final r in catalog.riwayat) _chip(r.name, r.id),
                      ],
                    ),
                  ),
                  Expanded(child: _list(catalog)),
                ],
              ),
      ),
    );
  }

  Widget _chip(String label, int? id) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: ChoiceChip(
      label: Text(label),
      showCheckmark: false,
      selected: _rewaya == id,
      onSelected: (_) => setState(() => _rewaya = id),
    ),
  );

  Widget _list(Catalog catalog) {
    final reciters = catalog.reciters.where((r) {
      if (_query.isNotEmpty && !r.name.contains(_query)) return false;
      if (_rewaya != null && !r.moshafs.any((m) => m.rewayaId == _rewaya)) {
        return false;
      }
      return true;
    }).toList();
    if (reciters.isEmpty) {
      return const Center(
        child: Text('مفيش نتايج', style: TextStyle(color: Retro.muted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: reciters.length,
      itemBuilder: (context, i) {
        final r = reciters[i];
        final riwayat = r.moshafs.map((m) => m.label).toSet();
        return TweenAnimationBuilder<double>(
          key: ValueKey(r.id),
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + 40 * i.clamp(0, 10)),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - v)),
              child: child,
            ),
          ),
          child: GlowCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ReciterScreen(reciter: r, initialRewaya: _rewaya),
              ),
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'reciter-${r.id}',
                  child: Monogram(name: r.name),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        riwayat.join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Retro.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (r.moshafs.length > 1)
                  Container(
                    margin: const EdgeInsetsDirectional.only(start: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Retro.brass.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '${r.moshafs.length} مصاحف',
                      style: const TextStyle(color: Retro.brass, fontSize: 11),
                    ),
                  ),
                const Icon(Icons.chevron_right_rounded, color: Retro.muted),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CatalogStatus extends StatelessWidget {
  const CatalogStatus({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.catalogError ?? 'لسه مفيش تلاوات',
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: state.loadCatalog,
              child: const Text('حاول تاني'),
            ),
          ],
        ),
      ),
    );
  }
}
