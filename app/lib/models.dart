class Rewaya {
  const Rewaya({required this.id, required this.name});

  final int id;
  final String name;

  factory Rewaya.fromJson(Map<String, dynamic> j) =>
      Rewaya(id: j['id'] as int, name: j['name'] as String);
}

class Surah {
  const Surah({required this.id, required this.name, required this.makkia});

  final int id;
  final String name;
  final bool makkia;

  factory Surah.fromJson(Map<String, dynamic> j) => Surah(
        id: j['id'] as int,
        name: j['name'] as String,
        makkia: (j['makkia'] ?? 0) == 1,
      );
}

class Moshaf {
  const Moshaf({
    required this.id,
    required this.name,
    required this.rewayaId,
    required this.rewayaName,
    required this.surahs,
    required this.durations,
    required this.reciter,
  });

  final int id;
  final String name;
  final int rewayaId;
  final String rewayaName;
  final List<int> surahs;

  /// مدة كل سورة بالثواني (بنفس ترتيب [surahs])، 0 لو مش معروفة
  final List<double> durations;
  final Reciter reciter;

  String get label => rewayaName.isNotEmpty ? rewayaName : name;

  String audioPath(int surah) =>
      '/media/audio/$id/${surah.toString().padLeft(3, '0')}.mp3';
}

class Reciter {
  Reciter({required this.id, required this.name});

  final int id;
  final String name;
  final List<Moshaf> moshafs = [];

  factory Reciter.fromJson(Map<String, dynamic> j) {
    final r = Reciter(id: j['id'] as int, name: j['name'] as String);
    for (final m in (j['moshafs'] as List).cast<Map<String, dynamic>>()) {
      final surahs = (m['surahs'] as List).cast<int>();
      final durations = ((m['durations'] as List?) ?? const [])
          .map((d) => (d as num).toDouble())
          .toList();
      r.moshafs.add(Moshaf(
        id: m['id'] as int,
        name: m['name'] as String,
        rewayaId: m['rewaya_id'] as int,
        rewayaName: (m['rewaya_name'] as String?) ?? '',
        surahs: surahs,
        durations: durations.length == surahs.length
            ? durations
            : List.filled(surahs.length, 0),
        reciter: r,
      ));
    }
    return r;
  }
}

class NowPlaying {
  const NowPlaying({this.title, this.artist, this.album, this.surah});

  final String? title;
  final String? artist;
  final String? album;
  final int? surah;

  factory NowPlaying.fromJson(Map<String, dynamic> j) => NowPlaying(
        title: j['title'] as String?,
        artist: j['artist'] as String?,
        album: j['album'] as String?,
        surah: int.tryParse('${j['surah'] ?? ''}'),
      );
}

class LiveChannel {
  const LiveChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.streamUrl,
    required this.listeners,
    this.now,
  });

  final String id;
  final String name;
  final String description;
  final String streamUrl;
  final int listeners;
  final NowPlaying? now;

  factory LiveChannel.fromJson(Map<String, dynamic> j) => LiveChannel(
        id: j['id'] as String,
        name: j['name'] as String,
        description: (j['description'] as String?) ?? '',
        streamUrl: j['stream_url'] as String,
        listeners: (j['listeners'] as int?) ?? 0,
        now: j['now'] is Map<String, dynamic>
            ? NowPlaying.fromJson(j['now'] as Map<String, dynamic>)
            : null,
      );
}

class Catalog {
  Catalog({
    required this.stationName,
    required this.riwayat,
    required this.suwar,
    required this.reciters,
  });

  final String stationName;
  final List<Rewaya> riwayat;
  final List<Surah> suwar;
  final List<Reciter> reciters;

  late final Map<int, Surah> _surahById = {for (final s in suwar) s.id: s};
  late final Map<int, Moshaf> _moshafById = {
    for (final r in reciters)
      for (final m in r.moshafs) m.id: m
  };

  String surahName(int id) => _surahById[id]?.name ?? '$id';
  Moshaf? moshaf(int id) => _moshafById[id];

  factory Catalog.fromJson(Map<String, dynamic> j) => Catalog(
        stationName: (j['station_name'] as String?) ?? '',
        riwayat: (j['riwayat'] as List)
            .cast<Map<String, dynamic>>()
            .map(Rewaya.fromJson)
            .toList(),
        suwar: (j['suwar'] as List)
            .cast<Map<String, dynamic>>()
            .map(Surah.fromJson)
            .toList(),
        reciters: (j['reciters'] as List)
            .cast<Map<String, dynamic>>()
            .map(Reciter.fromJson)
            .toList(),
      );
}
