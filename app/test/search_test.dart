import 'package:azkar_radio/screens/search_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search ignores tashkeel and alef/ya/ta forms', () {
    expect(matchesQuery('محمود خليل الحُصري', 'الحصري'), isTrue);
    expect(matchesQuery('أحمد العجمي', 'احمد'), isTrue);
    expect(matchesQuery('سورة البقرة', 'البقره'), isTrue);
    expect(matchesQuery('مشاري راشد العفاسي', 'العفاسى مشاري'), isTrue);
    expect(matchesQuery('ماهر المعيقلي', 'الحصري'), isFalse);
  });
}
