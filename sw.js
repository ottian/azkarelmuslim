// بيخلّي التطبيق يفتح من غير نت، وبيشغّل السور اللي المستخدم حفظها في مكتبتي.
//
// - ملفات الموقع: من النت الأول (علشان التحديثات توصل)، ولو مفيش نت من المحفوظ.
// - السور المحفوظة: التطبيق بيحطها في cache اسمه quran-audio بنفس رابطها على
//   mp3quran، وهنا بنرد منها، ومعاها طلبات الأجزاء (Range) اللي Safari بيطلبها.
const SHELL = 'shell-v1';
const AUDIO = 'quran-audio';
const CORE = ['./', 'index.html', 'main.dart.js', 'flutter_bootstrap.js', 'flutter.js', 'manifest.json',
  'catalog.json', 'favicon.png', 'icons/Icon-192.png', 'canvaskit/canvaskit.js', 'canvaskit/canvaskit.wasm',
  'assets/FontManifest.json', 'assets/AssetManifest.bin.json', 'assets/AssetManifest.json'];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(caches.open(SHELL).then((cache) =>
    Promise.all(CORE.map((path) => cache.add(path).catch(() => {})))));
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith('shell-') && key !== SHELL) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.pathname.endsWith('.mp3') && url.origin !== self.location.origin) {
    event.respondWith(audio(req));
  } else if (url.origin === self.location.origin) {
    event.respondWith(shell(req));
  } else if (url.hostname === 'fonts.gstatic.com') {
    event.respondWith(cacheFirst(req));
  }
});

async function audio(req) {
  const hit = await (await caches.open(AUDIO)).match(req.url);
  if (!hit) return fetch(req);
  const blob = await hit.blob();
  const size = blob.size;
  const range = /bytes=(\d*)-(\d*)/.exec(req.headers.get('range') || '');
  if (!range) {
    return new Response(blob, { status: 200, headers: {
      'Content-Type': 'audio/mpeg', 'Content-Length': String(size), 'Accept-Ranges': 'bytes' } });
  }
  let start, end;
  if (range[1] === '') { // آخر N بايت
    start = Math.max(0, size - Number(range[2]));
    end = size - 1;
  } else {
    start = Number(range[1]);
    end = range[2] === '' ? size - 1 : Math.min(Number(range[2]), size - 1);
  }
  if (start >= size || start > end) {
    return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${size}` } });
  }
  return new Response(blob.slice(start, end + 1), { status: 206, headers: {
    'Content-Type': 'audio/mpeg', 'Content-Length': String(end - start + 1), 'Accept-Ranges': 'bytes',
    'Content-Range': `bytes ${start}-${end}/${size}` } });
}

async function shell(req) {
  const cache = await caches.open(SHELL);
  try {
    const res = await fetch(req);
    if (res.ok && res.status === 200) cache.put(req, res.clone());
    return res;
  } catch (e) {
    const hit = await cache.match(req, { ignoreSearch: true }) ||
      (req.mode === 'navigate' ? await cache.match('./') : undefined);
    if (hit) return hit;
    throw e;
  }
}

async function cacheFirst(req) {
  const cache = await caches.open(SHELL);
  const hit = await cache.match(req);
  if (hit) return hit;
  const res = await fetch(req);
  if (res.ok) cache.put(req, res.clone());
  return res;
}
