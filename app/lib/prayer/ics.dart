import 'notifier.dart';

/// ملف تقويم (.ics) بمواعيد الصلاة والأذكار. على الآيفون الموقع مش بيقدر يطلّع
/// تنبيهات وهو مقفول، فبنضيف المواعيد لتقويم الموبايل وهو اللي بينبّه.
String buildIcs(List<Alert> alerts) {
  String stamp(DateTime t) {
    final u = t.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  String esc(String s) => s.replaceAll(r'\', r'\\').replaceAll(';', r'\;').replaceAll(',', r'\,').replaceAll('\n', r'\n');
  final now = stamp(DateTime.now());
  final b = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//Azkar El Muslim//Radio//AR')
    ..writeln('CALSCALE:GREGORIAN')
    ..writeln('X-WR-CALNAME:أذكار المسلم');
  for (final a in alerts) {
    b
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:azkar-${a.id}-${stamp(a.at)}@azkarelmuslim')
      ..writeln('DTSTAMP:$now')
      ..writeln('DTSTART:${stamp(a.at)}')
      ..writeln('DTEND:${stamp(a.at.add(const Duration(minutes: 10)))}')
      ..writeln('SUMMARY:${esc(a.title)}')
      ..writeln('DESCRIPTION:${esc(a.body)}')
      ..writeln('BEGIN:VALARM')
      ..writeln('ACTION:DISPLAY')
      ..writeln('DESCRIPTION:${esc(a.title)}')
      ..writeln('TRIGGER:PT0M')
      ..writeln('END:VALARM')
      ..writeln('END:VEVENT');
  }
  b.writeln('END:VCALENDAR');
  return b.toString().replaceAll('\n', '\r\n');
}
