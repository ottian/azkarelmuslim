import 'dart:convert';

import 'package:flutter/services.dart';

class Dhikr {
  const Dhikr({required this.text, required this.count, required this.note, required this.ref});
  final String text;
  final int count;
  final String note;
  final String ref;
}

class AdhkarSection {
  const AdhkarSection(this.title, this.items);
  final String title;
  final List<Dhikr> items;
}

/// الأذكار من assets/data/adhkar.json (المصدر مكتوب جوه الملف)
Future<List<AdhkarSection>> loadAdhkar() async {
  final raw = jsonDecode(await rootBundle.loadString('assets/data/adhkar.json')) as Map<String, dynamic>;
  return [
    for (final s in (raw['sections'] as List).cast<Map<String, dynamic>>())
      AdhkarSection(s['title'] as String, [
        for (final i in (s['items'] as List).cast<Map<String, dynamic>>())
          Dhikr(
            text: i['text'] as String,
            count: (i['count'] as num?)?.toInt() ?? 1,
            note: (i['note'] as String?) ?? '',
            ref: (i['ref'] as String?) ?? '',
          ),
      ]),
  ];
}
