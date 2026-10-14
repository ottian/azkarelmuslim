import '../third_party/adhan/adhan.dart';

class City {
  const City(this.name, this.lat, this.lng);
  final String name;
  final double lat;
  final double lng;
}

/// كل بلد بطريقة الحساب والمذهب المعتمدين فيها، وأشهر مدنها
class Country {
  const Country(this.code, this.name, this.method, this.cities, {this.hanafi = false});
  final String code;
  final String name;
  final CalculationMethod method;
  final bool hanafi;
  final List<City> cities;
}

const countries = [
  Country('EG', 'مصر', CalculationMethod.egyptian, [
    City('القاهرة', 30.0444, 31.2357),
    City('الجيزة', 30.0131, 31.2089),
    City('الإسكندرية', 31.2001, 29.9187),
    City('بورسعيد', 31.2653, 32.3019),
    City('السويس', 29.9668, 32.5498),
    City('الإسماعيلية', 30.5965, 32.2715),
    City('المنصورة', 31.0409, 31.3785),
    City('طنطا', 30.7865, 31.0004),
    City('الزقازيق', 30.5877, 31.5020),
    City('دمياط', 31.4175, 31.8144),
    City('شبين الكوم', 30.5503, 31.0106),
    City('بنها', 30.4659, 31.1848),
    City('كفر الشيخ', 31.1107, 30.9388),
    City('دمنهور', 31.0341, 30.4682),
    City('الفيوم', 29.3084, 30.8428),
    City('بني سويف', 29.0661, 31.0994),
    City('المنيا', 28.1099, 30.7503),
    City('أسيوط', 27.1809, 31.1837),
    City('سوهاج', 26.5591, 31.6957),
    City('قنا', 26.1551, 32.7160),
    City('الأقصر', 25.6872, 32.6396),
    City('أسوان', 24.0889, 32.8998),
    City('الغردقة', 27.2579, 33.8116),
    City('شرم الشيخ', 27.9158, 34.3300),
    City('العريش', 31.1313, 33.7984),
    City('مرسى مطروح', 31.3543, 27.2373),
  ]),
  Country('SA', 'السعودية', CalculationMethod.umm_al_qura, [
    City('مكة المكرمة', 21.4225, 39.8262),
    City('المدينة المنورة', 24.4672, 39.6111),
    City('الرياض', 24.7136, 46.6753),
    City('جدة', 21.4858, 39.1925),
    City('الدمام', 26.4207, 50.0888),
    City('الطائف', 21.2703, 40.4158),
    City('تبوك', 28.3835, 36.5662),
    City('أبها', 18.2164, 42.5053),
    City('بريدة', 26.3592, 43.9818),
    City('حائل', 27.5114, 41.7208),
  ]),
  Country('AE', 'الإمارات', CalculationMethod.dubai, [
    City('أبوظبي', 24.4539, 54.3773),
    City('دبي', 25.2048, 55.2708),
    City('الشارقة', 25.3463, 55.4209),
    City('العين', 24.2075, 55.7447),
  ]),
  Country('KW', 'الكويت', CalculationMethod.kuwait, [City('الكويت', 29.3759, 47.9774)]),
  Country('QA', 'قطر', CalculationMethod.qatar, [City('الدوحة', 25.2854, 51.5310)]),
  Country('BH', 'البحرين', CalculationMethod.dubai, [City('المنامة', 26.2285, 50.5860)]),
  Country('OM', 'عمان', CalculationMethod.muslim_world_league, [
    City('مسقط', 23.5880, 58.3829),
    City('صلالة', 17.0151, 54.0924),
  ]),
  Country('JO', 'الأردن', CalculationMethod.muslim_world_league, [
    City('عمّان', 31.9454, 35.9284),
    City('إربد', 32.5556, 35.8500),
  ]),
  Country('PS', 'فلسطين', CalculationMethod.muslim_world_league, [
    City('القدس', 31.7683, 35.2137),
    City('غزة', 31.5017, 34.4668),
    City('نابلس', 32.2211, 35.2544),
  ]),
  Country('LB', 'لبنان', CalculationMethod.muslim_world_league, [City('بيروت', 33.8938, 35.5018)]),
  Country('SY', 'سوريا', CalculationMethod.muslim_world_league, [
    City('دمشق', 33.5138, 36.2765),
    City('حلب', 36.2021, 37.1343),
  ]),
  Country('IQ', 'العراق', CalculationMethod.muslim_world_league, [
    City('بغداد', 33.3152, 44.3661),
    City('البصرة', 30.5085, 47.7804),
    City('أربيل', 36.1911, 44.0092),
  ]),
  Country('YE', 'اليمن', CalculationMethod.umm_al_qura, [
    City('صنعاء', 15.3694, 44.1910),
    City('عدن', 12.7855, 45.0187),
  ]),
  Country('SD', 'السودان', CalculationMethod.egyptian, [City('الخرطوم', 15.5007, 32.5599)]),
  Country('LY', 'ليبيا', CalculationMethod.egyptian, [
    City('طرابلس', 32.8872, 13.1913),
    City('بنغازي', 32.1167, 20.0667),
  ]),
  Country('TN', 'تونس', CalculationMethod.muslim_world_league, [City('تونس', 36.8065, 10.1815)]),
  Country('DZ', 'الجزائر', CalculationMethod.muslim_world_league, [
    City('الجزائر', 36.7538, 3.0588),
    City('وهران', 35.6971, -0.6308),
  ]),
  Country('MA', 'المغرب', CalculationMethod.muslim_world_league, [
    City('الرباط', 34.0209, -6.8416),
    City('الدار البيضاء', 33.5731, -7.5898),
    City('فاس', 34.0181, -5.0078),
    City('مراكش', 31.6295, -7.9811),
  ]),
  Country('MR', 'موريتانيا', CalculationMethod.muslim_world_league, [City('نواكشوط', 18.0735, -15.9582)]),
  Country('SO', 'الصومال', CalculationMethod.muslim_world_league, [City('مقديشو', 2.0469, 45.3182)]),
  Country('TR', 'تركيا', CalculationMethod.turkey, hanafi: true, [
    City('إسطنبول', 41.0082, 28.9784),
    City('أنقرة', 39.9334, 32.8597),
  ]),
  Country('PK', 'باكستان', CalculationMethod.karachi, hanafi: true, [
    City('كراتشي', 24.8607, 67.0011),
    City('لاهور', 31.5204, 74.3587),
    City('إسلام آباد', 33.6844, 73.0479),
  ]),
  Country('IN', 'الهند', CalculationMethod.karachi, hanafi: true, [City('دلهي', 28.6139, 77.2090)]),
  Country('BD', 'بنجلاديش', CalculationMethod.karachi, hanafi: true, [City('دكا', 23.8103, 90.4125)]),
  Country('ID', 'إندونيسيا', CalculationMethod.singapore, [City('جاكرتا', -6.2088, 106.8456)]),
  Country('MY', 'ماليزيا', CalculationMethod.singapore, [City('كوالالمبور', 3.1390, 101.6869)]),
  Country('NG', 'نيجيريا', CalculationMethod.muslim_world_league, [City('لاغوس', 6.5244, 3.3792)]),
  Country('GB', 'بريطانيا', CalculationMethod.muslim_world_league, [
    City('لندن', 51.5074, -0.1278),
    City('مانشستر', 53.4808, -2.2426),
  ]),
  Country('FR', 'فرنسا', CalculationMethod.muslim_world_league, [City('باريس', 48.8566, 2.3522)]),
  Country('DE', 'ألمانيا', CalculationMethod.muslim_world_league, [City('برلين', 52.5200, 13.4050)]),
  Country('US', 'أمريكا', CalculationMethod.north_america, [
    City('نيويورك', 40.7128, -74.0060),
    City('شيكاغو', 41.8781, -87.6298),
    City('هيوستن', 29.7604, -95.3698),
    City('لوس أنجلوس', 34.0522, -118.2437),
  ]),
  Country('CA', 'كندا', CalculationMethod.north_america, [City('تورنتو', 43.6532, -79.3832)]),
];

Country? countryByCode(String? code) {
  for (final c in countries) {
    if (c.code == code) return c;
  }
  return null;
}

/// أسماء طرق الحساب للعرض
const methodNames = {
  CalculationMethod.egyptian: 'الهيئة المصرية العامة للمساحة',
  CalculationMethod.umm_al_qura: 'أم القرى (مكة)',
  CalculationMethod.muslim_world_league: 'رابطة العالم الإسلامي',
  CalculationMethod.dubai: 'الخليج (دبي)',
  CalculationMethod.kuwait: 'الكويت',
  CalculationMethod.qatar: 'قطر',
  CalculationMethod.karachi: 'جامعة العلوم الإسلامية بكراتشي',
  CalculationMethod.turkey: 'رئاسة الشؤون الدينية التركية',
  CalculationMethod.singapore: 'سنغافورة وماليزيا وإندونيسيا',
  CalculationMethod.north_america: 'أمريكا الشمالية (ISNA)',
  CalculationMethod.moon_sighting_committee: 'لجنة رؤية الهلال',
  CalculationMethod.tehran: 'جامعة طهران',
};
