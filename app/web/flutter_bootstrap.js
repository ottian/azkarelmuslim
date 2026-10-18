{{flutter_js}}
{{flutter_build_config}}

// من غير service worker بتاع Flutter: بنسجّل web/sw.js بتاعنا من index.html
// (بيخلّي الموقع يفتح والسور المحفوظة تشتغل من غير نت)
_flutter.loader.load();
