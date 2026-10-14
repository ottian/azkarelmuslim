import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../player.dart';
import '../theme.dart';
import 'retro_radio.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'ui.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<LiveChannel>? _channels;
  String? _error;
  String _query = '';
  String _group = '';
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // بيتنادى تاني لما الفهرس يوصل
    final catalog = AppScope.of(context).catalog;
    if (_timer == null && catalog != null && !catalog.isStatic) {
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
    final state = AppScope.of(context);
    if (state.catalog == null) return state.loadCatalog();
    try {
      final channels = await state.api.live(state.catalog);
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
    final catalog = state.catalog;
    final isStatic = catalog?.isStatic ?? false;
    final all = isStatic ? catalog!.channels : _channels;
    var channels = all;
    final groups = <String>{
      for (final c in all ?? const <LiveChannel>[])
        if (c.group.isNotEmpty) c.group,
    }.toList()..sort((a, b) => _groupOrder(a).compareTo(_groupOrder(b)));
    if (channels != null && _group.isNotEmpty) {
      channels = channels.where((c) => c.group == _group).toList();
    }
    if (channels != null && _query.isNotEmpty) {
      channels = channels.where((c) => matchesQuery(c.name, _query)).toList();
    }
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    final station = catalog?.stationName.isNotEmpty == true
        ? catalog!.stationName
        : 'إذاعة أذكار المسلم';
    Widget? status;
    if (catalog == null && !state.loading) {
      status = _Message(
        text: state.catalogError ?? 'مش قادر يوصل للسيرفر',
        onRetry: state.loadCatalog,
      );
    } else if (_error != null && channels == null) {
      status = _Message(text: _error!, onRetry: _refresh);
    } else if (channels == null) {
      status = const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (channels.isEmpty) {
      status = _Message(
        text: _query.isNotEmpty ? 'مفيش نتايج' : 'مفيش قنوات شغالة لسه.',
      );
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: station,
                  subtitle: 'قرآن كريم على مدار الساعة',
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [LiveDot(), SizedBox(width: 12), SearchButton()],
                  ),
                ),
              ),
              if (state.player.playback == null && state.lastListen != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: ResumeCard(entry: state.lastListen!),
                  ),
                ),
              // على الشاشات العريضة الراديو ثابت على الجنب
              if (!wide)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Center(child: RetroRadio()),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Row(
                    children: [
                      const Text(
                        'المحطات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (all != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Retro.panelHigh,
                          ),
                          child: Text(
                            '${all.length}',
                            style: const TextStyle(
                              color: Retro.amber,
                              fontSize: 12,
                              fontFamily: 'NotoSans',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (isStatic)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'ابحث عن محطة أو شيخ',
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                ),
              if (groups.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      children: [
                        for (final g in ['', ...groups])
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              label: Text(g.isEmpty ? 'الكل' : g == 'مصر' ? 'إذاعات مصر' : g == 'القراء' ? 'إذاعات القراء' : 'إذاعات عامة'),
                              showCheckmark: false,
                              selected: _group == g,
                              onSelected: (_) => setState(() => _group = g),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (status != null)
                SliverToBoxAdapter(child: status)
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 520,
                          mainAxisExtent: 86,
                          crossAxisSpacing: 10,
                        ),
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final ch = channels![i];
                      return _ChannelCard(
                        channel: ch,
                        frequency: frequencyOf(all!.indexOf(ch), all.length),
                        showListeners: !isStatic,
                      );
                    }, childCount: channels!.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

int _groupOrder(String g) => switch (g) {
  'مصر' => 0,
  'عامة' => 1,
  _ => 2,
};

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.channel,
    required this.frequency,
    required this.showListeners,
  });

  final LiveChannel channel;
  final String frequency;
  final bool showListeners;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final player = state.player;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final p = player.playback;
        final active = p is LivePlayback && p.channel.id == channel.id;
        final now = channel.now;
        final extra = [
          if (channel.description.isNotEmpty) channel.description,
          if (now != null) '${now.title ?? ''} • ${now.artist ?? ''}',
          if (showListeners) '${channel.listeners} مستمع الآن',
        ].join('  ·  ');
        return GlowCard(
          active: active,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: () => active ? player.toggle() : player.playLive(channel),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: active ? Retro.amberGlow : null,
                  color: active ? null : const Color(0xFF15100B),
                  border: Border.all(
                    color: active ? Colors.transparent : Retro.line,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      frequency,
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.1,
                        color: active ? const Color(0xFF2A1A05) : Retro.amber,
                      ),
                    ),
                    Text(
                      'FM',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 9,
                        height: 1.1,
                        color: active ? const Color(0xFF5A3A10) : Retro.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleanName(channel.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: active ? Retro.amber : Retro.cream,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      extra.isEmpty ? 'بث مباشر' : extra,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Retro.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: active
                    ? const SizedBox(
                        key: ValueKey('eq'),
                        width: 36,
                        child: Center(child: EqualizerBars(height: 20)),
                      )
                    : Container(
                        key: const ValueKey('play'),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Retro.line),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Retro.cream,
                          size: 22,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        Text(text, textAlign: TextAlign.center),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('حاول تاني')),
      ],
    ),
  );
}
