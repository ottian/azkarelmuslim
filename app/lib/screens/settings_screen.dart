import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'player_widgets.dart';
import 'prayer_screen.dart';
import 'ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.firstRun = false, this.standalone = false});

  final bool firstRun;

  /// مفتوحة كصفحة لوحدها (فيها زرار رجوع)
  final bool standalone;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController? _controller;

  TextEditingController get _server => _controller ??= TextEditingController(
    text: AppScope.of(context).api.baseUrl,
  );

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: widget.standalone ? AppBar(title: const Text('الإعدادات')) : null,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (!widget.standalone) const PageHeader(title: 'الإعدادات'),
            if (widget.firstRun)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('اكتب عنوان سيرفر الإذاعة علشان نبدأ'),
              ),
            if (!widget.firstRun)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('مؤقت النوم'),
                subtitle: ListenableBuilder(
                  listenable: state.player,
                  builder: (context, _) => Text(
                    state.player.sleepAt == null
                        ? 'مقفول'
                        : 'هيقف الساعة ${TimeOfDay.fromDateTime(state.player.sleepAt!).format(context)}',
                  ),
                ),
                onTap: () => showSleepTimerSheet(context, state.player),
              ),
            if (!widget.firstRun)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mosque_outlined),
                title: const Text('مواقيت الصلاة والتنبيهات'),
                subtitle: Text(state.prayer.settings.placeName),
                onTap: () => openPrayerSettings(context),
              ),
            if (state.api.canChangeServer) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _server,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'عنوان السيرفر',
                  hintText: 'https://radio.example.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  await state.changeServer(_server.text);
                  if (context.mounted && state.catalogError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.catalogError!)),
                    );
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
            if (!widget.firstRun) ...[
              const Divider(height: 32),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.radio_rounded, color: Retro.amber),
                title: Text('إذاعة أذكار المسلم'),
                subtitle: Text('مصدر التلاوات: mp3quran.net'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('المصادر والحقوق'),
                subtitle: const Text('التلاوات والأذكار والأذان وصور القراء'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreditsScreen()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// مصادر المحتوى ورخصه
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    Widget item(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Retro.brass, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          SelectableText(body, style: const TextStyle(color: Retro.cream, height: 1.7)),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('المصادر والحقوق')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          item('التلاوات والإذاعات', 'موقع mp3quran.net، وإذاعة القرآن الكريم من القاهرة عبر radiojar.'),
          item('الأذكار', 'حصن المسلم، من مشروع azkar-api على GitHub (nawafalqari/azkar-api).'),
          item('مواقيت الصلاة', 'مكتبة adhan لـ Dart من Riajul Islam (رخصة MIT)، مبنية على مشروع Adhan من Batoul Apps.'),
          item('صوت الأذان', '"Beautiful adhan" من ويكيميديا كومنز، ملكية عامة (CC0).'),
          const Text('صور القراء (ويكيميديا كومنز)', style: TextStyle(color: Retro.brass, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FutureBuilder(
            future: state.api.photoCredits(),
            builder: (context, snap) {
              if (snap.hasError) return const Text('مفيش صور', style: TextStyle(color: Retro.muted));
              if (!snap.hasData) return const LinearProgressIndicator();
              String name(String id) {
                for (final r in state.catalog?.reciters ?? const []) {
                  if ('${r.id}' == id) return r.name;
                }
                return id;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in snap.data!.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SelectableText(
                        '${name(e.key)}: ${e.value['artist']} • ${e.value['license']}\n${e.value['page']}',
                        style: const TextStyle(color: Retro.muted, fontSize: 12.5, height: 1.6),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
