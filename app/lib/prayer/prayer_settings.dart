import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../third_party/adhan/adhan.dart';
import 'cities.dart';

/// الصلوات الخمسة (والشروق للعرض بس)
enum PrayerName {
  fajr('الفجر'),
  sunrise('الشروق'),
  dhuhr('الظهر'),
  asr('العصر'),
  maghrib('المغرب'),
  isha('العشاء');

  const PrayerName(this.label);
  final String label;

  bool get isPrayer => this != PrayerName.sunrise;
}

/// إعدادات المواقيت والتنبيهات، محفوظة على الجهاز
class PrayerSettings {
  PrayerSettings({
    this.countryCode,
    this.cityName,
    this.lat,
    this.lng,
    this.method = CalculationMethod.egyptian,
    this.hanafi = false,
    Map<PrayerName, int>? offsets,
    Set<PrayerName>? adhan,
    this.prayerAlerts = true,
    this.morningAdhkar = true,
    this.morningTime = const TimeOfDay(hour: 7, minute: 0),
    this.eveningAdhkar = true,
    this.eveningTime = const TimeOfDay(hour: 17, minute: 0),
    this.middayReminder = true,
    this.middayTime = const TimeOfDay(hour: 13, minute: 30),
    this.wird = true,
    this.wirdTime = const TimeOfDay(hour: 21, minute: 0),
    DateTime? wirdStart,
    this.wirdDoneOn,
  })  : offsets = offsets ?? {},
        adhan = adhan ?? PrayerName.values.where((p) => p.isPrayer).toSet(),
        wirdStart = wirdStart ?? _today();

  String? countryCode;
  String? cityName;
  double? lat;
  double? lng;
  CalculationMethod method;
  bool hanafi;

  /// تعديل يدوي بالدقايق لكل صلاة (علشان تطابق تقويم بلدك بالظبط)
  final Map<PrayerName, int> offsets;

  /// الصلوات اللي بيتشغّل فيها الأذان
  final Set<PrayerName> adhan;
  bool prayerAlerts;

  bool morningAdhkar;
  TimeOfDay morningTime;
  bool eveningAdhkar;
  TimeOfDay eveningTime;
  bool middayReminder;
  TimeOfDay middayTime;
  bool wird;
  TimeOfDay wirdTime;

  /// أول يوم في الختمة (جزء كل يوم)
  DateTime wirdStart;

  /// آخر يوم المستمع علّم فيه إن الورد خلص
  DateTime? wirdDoneOn;

  bool get hasLocation => lat != null && lng != null;

  String get placeName => cityName ?? (hasLocation ? 'موقعي الحالي' : 'اختار مدينتك');

  Coordinates get coordinates => Coordinates(lat!, lng!);

  CalculationParameters get parameters {
    final p = method.getParameters();
    p.madhab = hanafi ? Madhab.hanafi : Madhab.shafi;
    p.adjustments.fajr = offsets[PrayerName.fajr] ?? 0;
    p.adjustments.sunrise = offsets[PrayerName.sunrise] ?? 0;
    p.adjustments.dhuhr = offsets[PrayerName.dhuhr] ?? 0;
    p.adjustments.asr = offsets[PrayerName.asr] ?? 0;
    p.adjustments.maghrib = offsets[PrayerName.maghrib] ?? 0;
    p.adjustments.isha = offsets[PrayerName.isha] ?? 0;
    return p;
  }

  void useCountry(Country c, City city) {
    countryCode = c.code;
    cityName = city.name;
    lat = city.lat;
    lng = city.lng;
    method = c.method;
    hanafi = c.hanafi;
  }

  static const _key = 'prayer_settings';

  static PrayerSettings load(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_key);
      if (raw != null) return PrayerSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // إعدادات قديمة أو بايظة: نبدأ من الافتراضي
    }
    return PrayerSettings();
  }

  Future<void> save(SharedPreferences prefs) => prefs.setString(_key, jsonEncode(toJson()));

  Map<String, dynamic> toJson() => {
        'country': countryCode,
        'city': cityName,
        'lat': lat,
        'lng': lng,
        'method': method.name,
        'hanafi': hanafi,
        'offsets': {for (final e in offsets.entries) e.key.name: e.value},
        'adhan': [for (final p in adhan) p.name],
        'prayerAlerts': prayerAlerts,
        'morning': [morningAdhkar, _t(morningTime)],
        'evening': [eveningAdhkar, _t(eveningTime)],
        'midday': [middayReminder, _t(middayTime)],
        'wird': [wird, _t(wirdTime)],
        'wirdStart': wirdStart.toIso8601String(),
        'wirdDoneOn': wirdDoneOn?.toIso8601String(),
      };

  factory PrayerSettings.fromJson(Map<String, dynamic> j) {
    (bool, TimeOfDay)? pair(String k) {
      final v = j[k];
      if (v is List && v.length == 2 && v[0] is bool && v[1] is int) return (v[0] as bool, _fromT(v[1] as int));
      return null;
    }

    final d = PrayerSettings();
    final morning = pair('morning'), evening = pair('evening'), midday = pair('midday'), wird = pair('wird');
    return PrayerSettings(
      countryCode: j['country'] as String?,
      cityName: j['city'] as String?,
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      method: CalculationMethod.values.firstWhere((m) => m.name == j['method'], orElse: () => d.method),
      hanafi: j['hanafi'] == true,
      offsets: {
        for (final e in ((j['offsets'] as Map?) ?? const {}).entries)
          for (final p in PrayerName.values)
            if (p.name == e.key && e.value is int) p: e.value as int,
      },
      adhan: j['adhan'] is List
          ? {for (final n in j['adhan'] as List) ...PrayerName.values.where((p) => p.name == n)}
          : null,
      prayerAlerts: j['prayerAlerts'] != false,
      morningAdhkar: morning?.$1 ?? d.morningAdhkar,
      morningTime: morning?.$2 ?? d.morningTime,
      eveningAdhkar: evening?.$1 ?? d.eveningAdhkar,
      eveningTime: evening?.$2 ?? d.eveningTime,
      middayReminder: midday?.$1 ?? d.middayReminder,
      middayTime: midday?.$2 ?? d.middayTime,
      wird: wird?.$1 ?? d.wird,
      wirdTime: wird?.$2 ?? d.wirdTime,
      wirdStart: DateTime.tryParse(j['wirdStart'] as String? ?? ''),
      wirdDoneOn: DateTime.tryParse(j['wirdDoneOn'] as String? ?? ''),
    );
  }

  static int _t(TimeOfDay t) => t.hour * 60 + t.minute;
  static TimeOfDay _fromT(int m) => TimeOfDay(hour: (m ~/ 60) % 24, minute: m % 60);
  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
}
