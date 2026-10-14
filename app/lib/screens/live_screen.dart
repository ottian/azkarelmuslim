import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../player.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<LiveChannel>? _channels;
  String? _error;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timer == null) {
      _refresh();
      _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final channels = await AppScope.of(context).api.live();
      if (mounted) {
        setState(() {
          _channels = channels;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'مش قادر يوصل للسيرفر');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final channels = _channels;
    return Scaffold(
      appBar: AppBar(title: Text(state.catalog?.stationName.isNotEmpty == true ? state.catalog!.stationName : 'إذاعة أذكار المسلم')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null && channels == null)
              _Message(text: _error!, onRetry: _refresh)
            else if (channels == null)
              const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
            else if (channels.isEmpty)
              const _Message(text: 'مفيش قنوات شغالة لسه. شغّل استيراد التلاوات على السيرفر.')
            else
              for (final ch in channels) _ChannelCard(channel: ch),
          ],
        ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel});

  final LiveChannel channel;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final player = state.player;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final p = player.playback;
        final active = p is LivePlayback && p.channel.id == channel.id;
        final playing = active && player.player.playing;
        final now = channel.now;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: active ? theme.colorScheme.primaryContainer : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => active ? player.toggle() : player.playLive(channel),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(child: Text(channel.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                          const SizedBox(width: 8),
                          const _LiveBadge(),
                        ]),
                        if (channel.description.isNotEmpty)
                          Text(channel.description, style: theme.textTheme.bodySmall),
                        if (now != null) ...[
                          const SizedBox(height: 6),
                          Text('${now.title ?? ''} • ${now.artist ?? ''}', style: theme.textTheme.bodyMedium),
                          if (now.album != null) Text(now.album!, style: theme.textTheme.bodySmall),
                        ],
                        const SizedBox(height: 4),
                        Text('${channel.listeners} مستمع الآن', style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(4)),
        child: const Text('مباشر', style: TextStyle(color: Colors.white, fontSize: 11)),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('حاول تاني')),
        ]),
      );
}
