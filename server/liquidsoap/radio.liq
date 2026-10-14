# إذاعة أذكار المسلم: بث لايف 24 ساعة
# كل قناة بتقرا الـ playlist بتاعتها من /media/playlists/<id>.m3u
# (بيعملها سكريبت الاستيراد) وبتبثها على Icecast في /<id>

settings.log.stdout := true
settings.log.file := false
settings.log.level := 3

icecast_host = environment.get(default="icecast", "ICECAST_HOST")
icecast_port = int_of_string(environment.get(default="8000", "ICECAST_PORT"))
icecast_password = environment.get("ICECAST_SOURCE_PASSWORD")
station_name = environment.get(default="إذاعة أذكار المسلم", "STATION_NAME")
playlists_dir = environment.get(default="/media/playlists", "PLAYLISTS_DIR")
state_dir = environment.get(default="/state", "STATE_DIR")

# القنوات من channels.txt (بيكتبها سكريبت الاستيراد)، ولو مش موجود نستخدم CHANNELS
channels_file = "#{playlists_dir}/channels.txt"
channels =
  if file.exists(channels_file) and string.trim(file.contents(channels_file)) != "" then
    string.split(separator="\n", file.contents(channels_file))
  else
    string.split(separator=",", environment.get(default="main", "CHANNELS"))
  end

# بنكتب "بيتقري إيه دلوقتي" في ملف JSON علشان الـ API يقراه
def now_playing_writer(channel) =
  fun (m) -> begin
    j = json()
    list.iter(fun (k) -> j.add(k, m[k]), ["title", "artist", "album", "surah", "moshaf", "reciter"])
    j.add("started_at", time())
    file.write(data=json.stringify(j), "#{state_dir}/nowplaying-#{channel}.json")
  end
end

def start_channel(channel) =
  channel = string.trim(channel)
  if channel != "" then
    path = "#{playlists_dir}/#{channel}.m3u"
    if not file.exists(path) then
      log.important("Playlist #{path} missing, channel #{channel} will be silent until it exists")
      file.write(data="", path)
    end

    pl = playlist(
      id="playlist_#{channel}",
      mode="normal",
      reload_mode="watch",
      path
    )

    pl.on_track(now_playing_writer(channel))

    # لو الملفات وقعت أو الـ playlist فاضية نبث صمت بدل ما البث يقف
    radio = fallback(id="fallback_#{channel}", track_sensitive=false, [pl, blank(id="silence_#{channel}")])

    output.icecast(
      id="icecast_#{channel}",
      %mp3(mono, bitrate=64, samplerate=44100),
      host=icecast_host,
      port=icecast_port,
      password=icecast_password,
      mount="/#{channel}",
      name="#{station_name}",
      description="بث مباشر للقرآن الكريم 24 ساعة",
      genre="Quran",
      public=false,
      radio
    )
  end
end

list.iter(start_channel, channels)
