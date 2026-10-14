import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'reciter_screen.dart';

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
      appBar: AppBar(title: const Text('القراء')),
      body: catalog == null
          ? CatalogStatus(state: state)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'ابحث باسم الشيخ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      _chip('كل الروايات', null),
                      for (final r in catalog.riwayat) _chip(r.name, r.id),
                    ],
                  ),
                ),
                Expanded(child: _list(catalog)),
              ],
            ),
    );
  }

  Widget _chip(String label, int? id) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: _rewaya == id,
          onSelected: (_) => setState(() => _rewaya = id),
        ),
      );

  Widget _list(Catalog catalog) {
    final reciters = catalog.reciters.where((r) {
      if (_query.isNotEmpty && !r.name.contains(_query)) return false;
      if (_rewaya != null && !r.moshafs.any((m) => m.rewayaId == _rewaya)) return false;
      return true;
    }).toList();
    if (reciters.isEmpty) return const Center(child: Text('مفيش نتايج'));
    return ListView.builder(
      itemCount: reciters.length,
      itemBuilder: (context, i) {
        final r = reciters[i];
        return ListTile(
          leading: CircleAvatar(child: Text(r.name.characters.first)),
          title: Text(r.name),
          subtitle: Text(r.moshafs.map((m) => m.label).toSet().join(' • ')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ReciterScreen(reciter: r, initialRewaya: _rewaya),
          )),
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(state.catalogError ?? 'لسه مفيش تلاوات', textAlign: TextAlign.center),
          TextButton(onPressed: state.loadCatalog, child: const Text('حاول تاني')),
        ]),
      ),
    );
  }
}
