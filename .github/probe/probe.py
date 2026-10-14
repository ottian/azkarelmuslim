import json, urllib.request, urllib.parse, time, hashlib, subprocess
UA = {'User-Agent': 'azkarelmuslim-probe/1.0 (https://github.com/ottian/azkarelmuslim)'}
def get(url, raw=False, headers=None):
    with urllib.request.urlopen(urllib.request.Request(url, headers={**UA, **(headers or {})}), timeout=60) as r:
        b = r.read()
        return b if raw else json.loads(b)

print('=== radiojar station info')
for sid in ['8s5u5tpdtwzuv', '0tpy1h0kxtzuv']:
    for u in [f'https://www.radiojar.com/api/stations/{sid}', f'https://www.radiojar.com/api/stations/{sid}/now_playing/']:
        try:
            print(u, get(u, raw=True)[:600])
        except Exception as e:
            print(u, 'ERR', e)
    # ICY metadata
    try:
        req = urllib.request.Request(f'https://stream.radiojar.com/{sid}', headers={**UA, 'Icy-MetaData': '1'})
        with urllib.request.urlopen(req, timeout=20) as r:
            mi = int(r.headers.get('icy-metaint', 0))
            if mi:
                r.read(mi); n = r.read(1)[0] * 16; print(sid, 'META', r.read(n))
    except Exception as e:
        print(sid, 'ICY ERR', e)

print('=== adhan candidates')
files = ['Beautiful adhan.ogg', '33937 ejaz215 call-to-prayer-from-the-prophet-s-mo.ogg', 'Call to prayer by Sabah Fakhry.mp3', 'Adhan.ogg']
for f in files:
    time.sleep(3)
    try:
        info = get('https://commons.wikimedia.org/w/api.php?' + urllib.parse.urlencode(
            {'action': 'query', 'titles': 'File:' + f, 'prop': 'imageinfo', 'iiprop': 'url|extmetadata|sha1', 'format': 'json'}))
        p = list(info['query']['pages'].values())[0]; ii = p['imageinfo'][0]; md = ii['extmetadata']
        url = ii['url']
        time.sleep(2)
        b = get(url, raw=True)
        open('/tmp/a', 'wb').write(b)
        dur = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', '/tmp/a'], capture_output=True, text=True).stdout.strip()
        print(f, '|', url, '| sha256', hashlib.sha256(b).hexdigest(), '| dur', dur, '|', md.get('LicenseShortName', {}).get('value'), '|', md.get('Artist', {}).get('value'), '|', md.get('Credit', {}).get('value'), '|', md.get('ImageDescription', {}).get('value'))
    except Exception as e:
        print(f, 'ERR', e)

print('=== photos')
photos = {118: 'Hussary.jpg', 112: 'Elminshwey.jpg', 123: 'Мишари Рашид.jpg', 54: 'Abdul-Rahman Al-Sudais (Cropped, 2011).jpg',
          31: 'Saud Shuraim doing the Khutbah.png', 102: 'Maher Al Mueaqly.png', 30: 'Saad al Ghamdi.jpg', 92: 'Yasser Al-Dosari.png',
          74: 'Huthaify.jpg', 125: 'Mostafa Ismaeel.jpg', 111: 'Qari Muhammad Jebril, Ramadan 2019.png', 86: 'صورة شخصية الشيخ ناصر القطامي.jpg',
          231: 'هزاع البلوشي.jpg'}
time.sleep(3)
info = get('https://commons.wikimedia.org/w/api.php?' + urllib.parse.urlencode(
    {'action': 'query', 'titles': '|'.join('File:' + f for f in photos.values()), 'prop': 'imageinfo', 'iiprop': 'url|size|extmetadata', 'iiurlwidth': 300, 'format': 'json'}))
for p in info['query']['pages'].values():
    ii = p['imageinfo'][0]; md = ii['extmetadata']
    print(p['title'], '|', ii.get('width'), 'x', ii.get('height'), '|', ii.get('thumburl'), '|', md.get('LicenseShortName', {}).get('value'), '|', (md.get('Artist', {}).get('value') or '')[:120])
