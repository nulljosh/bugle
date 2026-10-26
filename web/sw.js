// ponytail: network-first for pages, cache-first for the hashed assets they name.
// Bump CACHE to evict everything a previous version stored.
const CACHE = "bugle-v79";
const FILES = ["/", "/index.html","/privacy.html","/read.html","/support.html", "/manifest.webmanifest"];

// Pages redirects /read.html to /read; a cached redirect cannot answer a navigation (ERR_FAILED offline), so keep
// a plain copy of the final page instead.
const plain = r => r.redirected ? r.blob().then(b => new Response(b, { status: r.status, headers: r.headers })) : r;

self.addEventListener("install", e => {
  // A single missing file fails the whole addAll, so tolerate misses.
  e.waitUntil(caches.open(CACHE)
    .then(c => Promise.all(FILES.map(f => fetch(f).then(plain).then(r => r.ok && c.put(f, r)).catch(() => {}))))
    .then(() => self.skipWaiting()));
});

// Saved stories' pictures live in their own cache (library.js fills it on Save), kept across versions.
const IMAGES = "bugle-images";

// library.js on Save or unsave: keep or drop a story's pictures. Opaque responses, all a cross-site image gives.
self.addEventListener("message", e => {
  const { images, keep } = e.data || {};
  if (!Array.isArray(images)) return;
  e.waitUntil(caches.open(IMAGES).then(c => Promise.all(images.map(u =>
    keep ? fetch(u, { mode: "no-cors" }).then(r => c.put(u, r)).catch(() => {}) : c.delete(u)))));
});

self.addEventListener("activate", e => {
  e.waitUntil(caches.keys()
    .then(ks => Promise.all(ks.filter(k => k !== CACHE && k !== IMAGES).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

const save = (req, res) => {
  if (res.ok && res.type === "basic") {
    const copy = res.clone();
    Promise.resolve(plain(copy)).then(r => caches.open(CACHE).then(c => c.put(req, r)));
  }
  return res;
};

self.addEventListener("fetch", e => {
  // A picture a saved story kept: from the cache, so it shows offline. Anything else goes to the network.
  if (e.request.method === "GET" && e.request.destination === "image" && new URL(e.request.url).origin !== location.origin) {
    e.respondWith(caches.open(IMAGES).then(c => c.match(e.request.url)).then(hit => hit || fetch(e.request)));
    return;
  }
  // Same-origin GETs only; APIs are cross-origin and stay network-only.
  if (e.request.method !== "GET" || new URL(e.request.url).origin !== location.origin) return;

  // /feed?url=... is a dynamic proxy, not a hashed asset: ignoreSearch below would match
  // it to whichever feed URL got cached first and serve that for every other feed.
  if (new URL(e.request.url).pathname === "/feed") return;

  // HTML must never come from cache first: it names the hashed bundles, so one
  // stale page pins a whole stale build and the site stops shipping updates to
  // anyone who has already visited. Network first, cache only as an offline fallback.
  if (e.request.mode === "navigate") {
    e.respondWith(
      fetch(e.request)
        .then(res => save(e.request, res))
        .catch(() => caches.match(e.request, { ignoreSearch: true })
          .then(hit => hit || caches.match(FILES[0])).then(hit => hit && plain(hit)))
    );
    return;
  }

  // Everything else is content-hashed, so a cache hit is always the right file.
  e.respondWith(
    caches.match(e.request, { ignoreSearch: true }).then(hit => hit ||
      fetch(e.request).then(res => save(e.request, res)))
  );
});
