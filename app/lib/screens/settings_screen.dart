import 'package:flutter/material.dart';

import '../app_state.dart';
import 'player_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController? _controller;

  TextEditingController get _server =>
      _controller ??= TextEditingController(text: AppScope.of(context).api.baseUrl);

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                builder: (context, _) => Text(state.player.sleepAt == null
                    ? 'مقفول'
                    : 'هيقف الساعة ${TimeOfDay.fromDateTime(state.player.sleepAt!).format(context)}'),
              ),
              onTap: () => showSleepTimerSheet(context, state.player),
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.catalogError!)));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
          if (!widget.firstRun) ...[
            const Divider(height: 32),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline),
              title: Text('إذاعة أذكار المسلم'),
              subtitle: Text('مصدر التلاوات: mp3quran.net'),
            ),
          ],
        ],
      ),
    );
  }
}
