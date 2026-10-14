import 'package:azkar_radio/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog parses reciters, moshafs and durations', () {
    final catalog = Catalog.fromJson({
      'station_name': 'إذاعة أذكار المسلم',
      'riwayat': [
        {'id': 1, 'name': 'حفص عن عاصم'},
      ],
      'suwar': [
        {'id': 1, 'name': 'الفاتحة', 'makkia': 1},
        {'id': 2, 'name': 'البقرة', 'makkia': 0},
      ],
      'reciters': [
        {
          'id': 5,
          'name': 'الحصري',
          'moshafs': [
            {
              'id': 9,
              'name': 'حفص عن عاصم - مرتل',
              'rewaya_id': 1,
              'rewaya_name': 'حفص عن عاصم',
              'surahs': [1, 2],
              'durations': [60, 7200.5],
            },
          ],
        },
      ],
    });
    final m = catalog.moshaf(9)!;
    expect(m.reciter.name, 'الحصري');
    expect(m.audioPath(2), '/media/audio/9/002.mp3');
    expect(m.durations, [60.0, 7200.5]);
    expect(catalog.surahName(2), 'البقرة');
    expect(catalog.suwar.first.makkia, isTrue);
  });

  test('missing durations fall back to zeros', () {
    final r = Reciter.fromJson({
      'id': 1,
      'name': 'x',
      'moshafs': [
        {'id': 2, 'name': 'y', 'rewaya_id': 1, 'surahs': [1, 2, 3]},
      ],
    });
    expect(r.moshafs.single.durations, [0, 0, 0]);
  });
}
