import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app_state.dart';
import '../prayer/cities.dart';
import '../prayer/prayer_settings.dart';
import '../theme.dart';
import '../third_party/adhan/adhan.dart';
import 'ui.dart';

/// إعدادات المواقيت (البلد، طريقة الحساب، تعديل الدقايق) والتنبيهات
class PrayerSettingsScreen extends StatelessWidget {
  const PrayerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prayer = AppScope.of(context).prayer;
    return ListenableBuilder(
      listenable: prayer,
      builder: (context, _) {
        final s = prayer.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('المواقيت والتنبيهات')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              const SectionTitle('المكان'),
              GlowCard(
                onTap: () => pickCity(context),
                child: Row(children: [
                  const Icon(Icons.location_on_rounded, color: Retro.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.placeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                      Text(countryByCode(s.countryCode)?.name ?? 'اضغط علشان تختار البلد والمدينة',
                          style: const TextStyle(color: Retro.muted, fontSize: 12)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Retro.muted),
                ]),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('حدد موقعي بالـ GPS'),
                  onPressed: () => useMyLocation(context),
                ),
              ),
              const SectionTitle('طريقة الحساب'),
              DropdownButtonFormField<CalculationMethod>(
                initialValue: methodNames.containsKey(s.method) ? s.method : CalculationMethod.egyptian,
                isExpanded: true,
                dropdownColor: Retro.panelHigh,
                items: [
                  for (final e in methodNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (m) => prayer.update((s) => s.method = m!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('العصر على المذهب الحنفي'),
                subtitle: const Text('بيأخّر العصر شوية، ومعتمد في تركيا وباكستان والهند'),
                value: s.hanafi,
                onChanged: (v) => prayer.update((s) => s.hanafi = v),
              ),
              const SectionTitle('تعديل المواقيت بالدقيقة'),
              const Text('لو فيه فرق دقيقة أو اتنين عن تقويم مسجدك، ظبطه من هنا.',
                  style: TextStyle(color: Retro.muted, fontSize: 12.5)),
              const SizedBox(height: 8),
              for (final p in PrayerName.values)
                _OffsetRow(
                  label: p.label,
                  value: s.offsets[p] ?? 0,
                  onChanged: (v) => prayer.update((s) => v == 0 ? s.offsets.remove(p) : s.offsets[p] = v),
                ),
              const SectionTitle('التنبيهات'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تنبيه بمواقيت الصلاة'),
                subtitle: const Text('والأذان في الصلوات اللي صوتها شغال في صفحة الصلاة'),
                value: s.prayerAlerts,
                onChanged: (v) => _enable(context, () => prayer.update((s) => s.prayerAlerts = v), v),
              ),
              _TimedSwitch(
                title: 'أذكار الصباح',
                value: s.morningAdhkar,
                time: s.morningTime,
                onChanged: (v) => _enable(context, () => prayer.update((s) => s.morningAdhkar = v), v),
                onTime: (t) => prayer.update((s) => s.morningTime = t),
              ),
              _TimedSwitch(
                title: 'ذكر في نص اليوم',
                value: s.middayReminder,
                time: s.middayTime,
                onChanged: (v) => _enable(context, () => prayer.update((s) => s.middayReminder = v), v),
                onTime: (t) => prayer.update((s) => s.middayTime = t),
              ),
              _TimedSwitch(
                title: 'أذكار المساء',
                value: s.eveningAdhkar,
                time: s.eveningTime,
                onChanged: (v) => _enable(context, () => prayer.update((s) => s.eveningAdhkar = v), v),
                onTime: (t) => prayer.update((s) => s.eveningTime = t),
              ),
              _TimedSwitch(
                title: 'الورد اليومي (جزء كل يوم)',
                value: s.wird,
                time: s.wirdTime,
                onChanged: (v) => _enable(context, () => prayer.update((s) => s.wird = v), v),
                onTime: (t) => prayer.update((s) => s.wirdTime = t),
              ),
              TextButton.icon(
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('ابدأ الختمة من الجزء الأول النهارده'),
                onPressed: () => prayer.update((s) {
                  final n = DateTime.now();
                  s.wirdStart = DateTime(n.year, n.month, n.day);
                  s.wirdDoneOn = null;
                }),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.notifications_active_rounded),
                label: const Text('اسمح بالتنبيهات'),
                onPressed: () => _enable(context, () async {}, true),
              ),
              const SizedBox(height: 8),
              Text(
                kIsWeb
                    ? 'على الموقع التنبيهات والأذان بيشتغلوا طول ما الصفحة مفتوحة.'
                    : defaultTargetPlatform == TargetPlatform.android
                        ? 'على أندرويد التنبيهات بتوصل حتى والتطبيق مقفول، والأذان بيشتغل كصوت التنبيه.'
                        : 'على الكمبيوتر التنبيهات والأذان بيشتغلوا طول ما التطبيق مفتوح (ولو متصغّر).',
                style: const TextStyle(color: Retro.muted, fontSize: 12.5),
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('جرّب صوت الأذان'),
                  style: OutlinedButton.styleFrom(foregroundColor: Retro.cream, side: const BorderSide(color: Retro.brass)),
                  onPressed: prayer.playAdhan,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// أول ما يفعّل تنبيه بنطلب الإذن (من ضغطة الزرار نفسها)
  static Future<void> _enable(BuildContext context, Future<void> Function() apply, bool on) async {
    final prayer = AppScope.of(context).prayer;
    final messenger = ScaffoldMessenger.of(context);
    // الإذن لازم يتطلب أول حاجة في الضغطة نفسها، وإلا Safari بيرفضه
    final ok = on ? await prayer.notifier.requestPermission() : true;
    await apply();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('التنبيهات مش مسموحة، فعّلها من إعدادات الجهاز أو المتصفح')),
      );
    }
  }
}

class _OffsetRow extends StatelessWidget {
  const _OffsetRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => onChanged(value - 1)),
          SizedBox(
            width: 64,
            child: Text(
              value == 0 ? 'بدون' : '${value > 0 ? '+' : ''}$value د',
              textAlign: TextAlign.center,
              style: TextStyle(color: value == 0 ? Retro.muted : Retro.amber, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => onChanged(value + 1)),
        ],
      );
}

class _TimedSwitch extends StatelessWidget {
  const _TimedSwitch({required this.title, required this.value, required this.time, required this.onChanged, required this.onTime});

  final String title;
  final bool value;
  final TimeOfDay time;
  final ValueChanged<bool> onChanged;
  final ValueChanged<TimeOfDay> onTime;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              value: value,
              onChanged: onChanged,
            ),
          ),
          TextButton(
            onPressed: value
                ? () async {
                    final t = await showTimePicker(context: context, initialTime: time);
                    if (t != null) onTime(t);
                  }
                : null,
            child: Text(time.format(context)),
          ),
        ],
      );
}

/// اختيار البلد وبعدين المدينة
Future<void> pickCity(BuildContext context) async {
  final prayer = AppScope.of(context).prayer;
  final country = await showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _PickerSheet<Country>(
      title: 'اختار البلد',
      items: countries,
      label: (c) => c.name,
    ),
  );
  if (country == null || !context.mounted) return;
  final city = country.cities.length == 1
      ? country.cities.first
      : await showModalBottomSheet<City>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (ctx) => _PickerSheet<City>(title: 'اختار المدينة', items: country.cities, label: (c) => c.name),
        );
  if (city == null) return;
  await prayer.update((s) => s.useCountry(country, city));
}

/// الموقع من الـ GPS، وأقرب مدينة من القايمة لو قريبة علشان طريقة الحساب
Future<void> useMyLocation(BuildContext context) async {
  final prayer = AppScope.of(context).prayer;
  final messenger = ScaffoldMessenger.of(context);
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      messenger.showSnackBar(const SnackBar(content: Text('مفيش إذن للموقع، اختار مدينتك من القايمة')));
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)),
    );
    Country? bestCountry;
    City? bestCity;
    var best = double.infinity;
    for (final c in countries) {
      for (final city in c.cities) {
        final d = _km(pos.latitude, pos.longitude, city.lat, city.lng);
        if (d < best) {
          best = d;
          bestCountry = c;
          bestCity = city;
        }
      }
    }
    await prayer.update((s) {
      // البلد من أقرب مدينة معروفة (لطريقة الحساب)، والإحداثيات الحقيقية للمواقيت
      if (bestCountry != null && best < 600) s.useCountry(bestCountry, bestCity!);
      s.lat = pos.latitude;
      s.lng = pos.longitude;
      s.cityName = best < 40 ? bestCity!.name : 'موقعي الحالي';
    });
  } catch (e) {
    messenger.showSnackBar(const SnackBar(content: Text('مش قادر يحدد الموقع، اختار مدينتك من القايمة')));
  }
}

double _km(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({required this.title, required this.items, required this.label});

  final String title;
  final List<T> items;
  final String Function(T) label;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final items = widget.items.where((e) => widget.label(e).contains(_q)).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث'),
                onChanged: (v) => setState(() => _q = v.trim()),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(widget.label(items[i])),
                  onTap: () => Navigator.pop(context, items[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
