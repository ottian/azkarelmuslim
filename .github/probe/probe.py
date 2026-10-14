import json, urllib.request, urllib.parse, sys
UA = {'User-Agent': 'azkarelmuslim-probe/1.0 (github actions)'}
def get(url, raw=False):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
        b = r.read()
        return b if raw else json.loads(b)

print('=== mp3quran radios (egypt-ish)')
radios = get('https://mp3quran.net/api/v3/radios?language=ar')['radios']
print('total', len(radios))
for r in radios:
    if any(k in r['name'] for k in ['مصر', 'القاهرة', 'المصري', 'إذاعة']):
        print(r['id'], r['name'], r['url'])

print('=== stream checks')
for u in ['https://stream.radiojar.com/8s5u5tpdtwzuv', 'https://n0e.radiojar.com/8s5u5tpdtwzuv',
          'https://stream.radiojar.com/0tpy1h0kxtzuv']:
    try:
        req = urllib.request.Request(u, headers=UA)
        with urllib.request.urlopen(req, timeout=15) as r:
            print(u, r.status, r.headers.get('content-type'), r.geturl(), len(r.read(20000)))
    except Exception as e:
        print(u, 'ERR', e)

print('=== wikidata reciters')
feat = json.load(open('.github/probe/featured.json'))
for rec in feat['reciters']:
    name = rec['name']
    try:
        res = get('https://www.wikidata.org/w/api.php?' + urllib.parse.urlencode(
            {'action': 'wbsearchentities', 'search': name, 'language': 'ar', 'uselang': 'ar', 'format': 'json', 'limit': 5}))
        ids = [x['id'] for x in res.get('search', [])]
        if not ids:
            print(rec['id'], name, '-> NONE'); continue
        ents = get('https://www.wikidata.org/w/api.php?' + urllib.parse.urlencode(
            {'action': 'wbgetentities', 'ids': '|'.join(ids), 'props': 'claims|descriptions|labels', 'languages': 'ar|en', 'format': 'json'}))['entities']
        for q in ids:
            e = ents[q]
            p18 = [c['mainsnak'].get('datavalue', {}).get('value') for c in e.get('claims', {}).get('P18', [])]
            occ = [c['mainsnak'].get('datavalue', {}).get('value', {}).get('id') for c in e.get('claims', {}).get('P106', [])]
            d = {k: v['value'] for k, v in e.get('descriptions', {}).items()}
            print(rec['id'], name, '->', q, e.get('labels', {}).get('ar', {}).get('value'), '|', d, '| P18', p18, '| occ', occ)
    except Exception as ex:
        print(rec['id'], name, 'ERR', ex)

print('=== adhkar sources')
for u in ['https://raw.githubusercontent.com/nawafalqari/azkar-api/56df51279ab6eb86dc2f6202c7de26c8948331c1/azkar.json',
          'https://raw.githubusercontent.com/nawafalqari/azkar-api/main/azkar.json',
          'https://www.hisnmuslim.com/api/ar/husn_ar.json',
          'https://raw.githubusercontent.com/osamayy/azkar-db/master/azkar.json']:
    try:
        b = get(u, raw=True)
        print(u, 'OK', len(b)); print(b[:1500].decode('utf-8-sig', 'replace'))
    except Exception as e:
        print(u, 'ERR', e)

print('=== commons adhan audio')
try:
    res = get('https://commons.wikimedia.org/w/api.php?' + urllib.parse.urlencode(
        {'action': 'query', 'list': 'search', 'srsearch': 'adhan filetype:audio', 'srnamespace': 6, 'srlimit': 30, 'format': 'json'}))
    titles = [x['title'] for x in res['query']['search']]
    info = get('https://commons.wikimedia.org/w/api.php?' + urllib.parse.urlencode(
        {'action': 'query', 'titles': '|'.join(titles[:30]), 'prop': 'imageinfo', 'iiprop': 'url|size|extmetadata|mime', 'format': 'json'}))
    for p in info['query']['pages'].values():
        ii = (p.get('imageinfo') or [{}])[0]
        md = ii.get('extmetadata', {})
        print(p['title'], ii.get('mime'), ii.get('size'), md.get('LicenseShortName', {}).get('value'), md.get('Artist', {}).get('value', '')[:80], ii.get('url'))
except Exception as e:
    print('ERR', e)
