import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    // ويندوز: التشغيل عن طريق media_kit، وبيكمل لو التطبيق متصغّر
    JustAudioMediaKit.ensureInitialized(windows: true, linux: true);
  } else {
    // أندرويد وويب (الآيفون): تشغيل في الخلفية وأزرار في شاشة القفل
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.azkarelmuslim.radio.playback',
      androidNotificationChannelName: 'إذاعة أذكار المسلم',
      androidNotificationOngoing: true,
    );
  }

  final prefs = await SharedPreferences.getInstance();
  final state = AppState(prefs);
  state.loadCatalog();
  runApp(AzkarApp(state: state));
}

class AzkarApp extends StatelessWidget {
  const AzkarApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'إذاعة أذكار المسلم',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const HomeScreen(),
      ),
    );
  }
}
