import json, urllib.request, urllib.parse, time, hashlib, subprocess
UA = {'User-Agent': 'azkarelmuslim-probe/1.0 (https://github.com/ottian/azkarelmuslim)'}
def get(url, raw=False):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
        b = r.read()
        return b if raw else json.loads(b)
files = ['Beautiful adhan.ogg', '33937 ejaz215 call-to-prayer-from-the-prophet-s-mo.ogg', 'Call to prayer by Sabah Fakhry.mp3', 'Adhan.ogg', 'Azan.ogg', 'The Adhan - Muslim Call to Prayer - Aaqib Azeez.mp3']
for f in files:
    time.sleep(3)
    try:
        info = get('https://commons.wikimedia.org/w/api.php?' + urllib.parse.urlencode(
            {'action': 'query', 'titles': 'File:' + f, 'prop': 'imageinfo', 'iiprop': 'url|extmetadata', 'format': 'json'}))
        p = list(info['query']['pages'].values())[0]; ii = p['imageinfo'][0]; md = ii['extmetadata']
        time.sleep(2)
        b = get(ii['url'], raw=True)
        open('/tmp/a', 'wb').write(b)
        dur = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration:stream=codec_name,sample_rate,channels,bit_rate', '-of', 'compact', '/tmp/a'], capture_output=True, text=True).stdout.strip().replace('\n', ' ')
        vol = subprocess.run(['ffmpeg', '-i', '/tmp/a', '-af', 'volumedetect', '-f', 'null', '-'], capture_output=True, text=True).stderr
        vol = ' '.join(l.split('] ')[-1] for l in vol.splitlines() if 'mean_volume' in l or 'max_volume' in l)
        print(f, '|', ii['url'], '| sha256', hashlib.sha256(b).hexdigest(), '|', dur, '|', vol, '|', md.get('LicenseShortName', {}).get('value'))
    except Exception as e:
        print(f, 'ERR', e)
