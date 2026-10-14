import 'package:azkar_radio/prayer/prayer_settings.dart';
import 'package:azkar_radio/prayer/wird.dart';
import 'package:azkar_radio/third_party/adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('مواقيت القاهرة بطريقة الهيئة المصرية', () {
    final params = CalculationMethod.egyptian.getParameters()..madhab = Madhab.shafi;
    final t = PrayerTimes.utcOffset(
        Coordinates(30.0444, 31.2357), DateComponents(2026, 10, 14), params, const Duration(hours: 3));
    String f(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    expect([t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha].map(f).toList(),
        ['5:30', '6:56', '12:42', '15:57', '18:26', '19:43']);
    expect(Qibla(Coordinates(30.0444, 31.2357)).direction, closeTo(136.1, 0.5));
  });

  test('الإعدادات بتتحفظ وترجع زي ما هي', () {
    final s = PrayerSettings(countryCode: 'EG', cityName: 'القاهرة', lat: 30.0, lng: 31.2, hanafi: true)
      ..offsets[PrayerName.isha] = 2
      ..adhan.remove(PrayerName.fajr)
      ..morningTime = const TimeOfDay(hour: 6, minute: 15);
    final back = PrayerSettings.fromJson(s.toJson());
    expect(back.cityName, 'القاهرة');
    expect(back.hanafi, isTrue);
    expect(back.offsets[PrayerName.isha], 2);
    expect(back.adhan.contains(PrayerName.fajr), isFalse);
    expect(back.morningTime, const TimeOfDay(hour: 6, minute: 15));
  });

  test('جزء كل يوم بيلف كل 30 يوم', () {
    final start = DateTime(2026, 1, 1);
    expect(juzForDay(start, DateTime(2026, 1, 1)), 1);
    expect(juzForDay(start, DateTime(2026, 1, 30)), 30);
    expect(juzForDay(start, DateTime(2026, 1, 31)), 1);
    expect(juzStartSurah.length, 30);
  });
}
