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
    expect(m.audioUrl(2), '/media/audio/9/002.mp3');
    expect(catalog.isStatic, isFalse);
    expect(m.durations, [60.0, 7200.5]);
    expect(catalog.surahName(2), 'البقرة');
    expect(catalog.suwar.first.makkia, isTrue);
  });

  test('static catalog plays from the moshaf server and lists radios', () {
    final catalog = Catalog.fromJson({
      'mode': 'static',
      'riwayat': [],
      'suwar': [],
      'reciters': [
        {
          'id': 1,
          'name': 'x',
          'moshafs': [
            {'id': 2, 'name': 'y', 'rewaya_id': 1, 'server': 'https://cdn.example/r1/', 'surahs': [1]},
          ],
        },
      ],
      'channels': [
        {'id': 'radio-1', 'name': 'r', 'stream_url': 'https://radio.example/a'},
      ],
    });
    expect(catalog.isStatic, isTrue);
    expect(catalog.moshaf(2)!.audioUrl(1), 'https://cdn.example/r1/001.mp3');
    expect(catalog.channels.single.streamUrl, 'https://radio.example/a');
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
