import json, urllib.request, urllib.parse, time
UA = {'User-Agent': 'azkarelmuslim-probe/1.0 (https://github.com/ottian/azkarelmuslim)'}
def get(url, raw=False, tries=5):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
                b = r.read()
                return b if raw else json.loads(b)
        except urllib.error.HTTPError as e:
            if e.code == 429 and i < tries - 1:
                time.sleep(5 * (i + 1)); continue
            raise

print('=== egypt stream headers')
for u in ['https://stream.radiojar.com/8s5u5tpdtwzuv']:
    req = urllib.request.Request(u, headers={**UA, 'Icy-MetaData': '1'})
    with urllib.request.urlopen(req, timeout=15) as r:
        print({k: v for k, v in r.headers.items() if k.lower().startswith(('icy', 'content'))})

print('=== mp3quran radios, egyptian reciters')
radios = get('https://mp3quran.net/api/v3/radios?language=ar')['radios']
for r in radios:
    if any(k in r['name'] for k in ['رفعت', 'شعيشع', 'الشعشاعي', 'طوبار', 'نعينع', 'عبدالباسط', 'عبد الباسط', 'الحصري', 'المنشاوي', 'مصطفى إسماعيل', 'البنا', 'الطبلاوي', 'الطوخي', 'محمد عمران', 'النقشبندي', 'الشحات', 'كامل يوسف', 'أحمد عامر', 'الفشني', 'أبو العينين', 'عبدالعزيز علي', 'محمود حسين منصور', 'مصر']):
        print(r['id'], r['name'], r['url'])
print('--- all radio names'); print(' | '.join(r['name'] for r in radios))

print('=== wikidata reciters')
feat = json.load(open('.github/probe/featured.json'))
for rec in feat['reciters']:
    name = rec['name']
    time.sleep(1.5)
    try:
        res = get('https://www.wikidata.org/w/api.php?' + urllib.parse.urlencode(
            {'action': 'wbsearchentities', 'search': name, 'language': 'ar', 'uselang': 'ar', 'format': 'json', 'limit': 5}))
        ids = [x['id'] for x in res.get('search', [])]
        if not ids:
            print(rec['id'], name, '-> NONE'); continue
        time.sleep(1)
        ents = get('https://www.wikidata.org/w/api.php?' + urllib.parse.urlencode(
            {'action': 'wbgetentities', 'ids': '|'.join(ids), 'props': 'claims|descriptions|labels', 'languages': 'ar|en', 'format': 'json'}))['entities']
        for q in ids:
            e = ents[q]
            p18 = [c['mainsnak'].get('datavalue', {}).get('value') for c in e.get('claims', {}).get('P18', [])]
            occ = [c['mainsnak'].get('datavalue', {}).get('value', {}).get('id') for c in e.get('claims', {}).get('P106', [])]
            d = e.get('descriptions', {}).get('en', {}).get('value')
            print(rec['id'], name, '->', q, e.get('labels', {}).get('ar', {}).get('value'), '|', d, '| P18', p18, '| occ', occ)
    except Exception as ex:
        print(rec['id'], name, 'ERR', ex)

print('=== azkar repo')
for u in ['https://api.github.com/repos/nawafalqari/azkar-api', 'https://api.github.com/repos/osamayy/azkar-db']:
    try:
        d = get(u); print(u, d.get('license'), d.get('description'))
    except Exception as e:
        print(u, 'ERR', e)
az = get('https://raw.githubusercontent.com/nawafalqari/azkar-api/56df51279ab6eb86dc2f6202c7de26c8948331c1/azkar.json')
for k, v in az.items():
    items = [x for g in v for x in (g if isinstance(g, list) else [g])]
    print(k, len(items))

print('=== commons adhan audio')
time.sleep(3)
for q in ['adhan filetype:audio', 'azan filetype:audio', 'call to prayer filetype:audio']:
    try:
        res = get('https://commons.wikimedia.org/w/api.php?' + urllib.parse.urlencode(
            {'action': 'query', 'list': 'search', 'srsearch': q, 'srnamespace': 6, 'srlimit': 25, 'format': 'json'}))
        titles = [x['title'] for x in res['query']['search']]
        time.sleep(2)
        info = get('https://commons.wikimedia.org/w/api.php?' + urllib.parse.urlencode(
            {'action': 'query', 'titles': '|'.join(titles), 'prop': 'imageinfo', 'iiprop': 'url|size|extmetadata|mime', 'format': 'json'}))
        for p in info['query']['pages'].values():
            ii = (p.get('imageinfo') or [{}])[0]
            md = ii.get('extmetadata', {})
            print(p['title'], ii.get('mime'), ii.get('size'), md.get('LicenseShortName', {}).get('value'), '|', md.get('Artist', {}).get('value', '')[:80], '|', md.get('ImageDescription', {}).get('value', '')[:120].replace('\n', ' '))
    except Exception as e:
        print('ERR', e)
    time.sleep(3)
