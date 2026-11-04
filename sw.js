// Silkfall offline support.
// The app page is fetched fresh when online (so updates show on the next launch) and served from cache when offline.
// Fonts and icons are cached the first time they load.
const CACHE = "silkfall-v6";
const CORE = ["./", "index.html", "manifest.webmanifest", "icon-180.png", "icon-512.png"];
self.addEventListener("install", e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE))); self.skipWaiting(); });
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  const isPage = req.mode === "navigate" || url.pathname.endsWith("/") || url.pathname.endsWith("index.html");
  if (isPage) {               // network first, cache fallback
    const net = fetch(req).then(r => { if (r.ok) { const copy = r.clone(); caches.open(CACHE).then(c => c.put(req, copy)); } return r; });
    const slow = new Promise((_, no) => setTimeout(() => no(new Error("slow network")), 4000));
    e.respondWith(Promise.race([net, slow])
      .catch(() => caches.match(req).then(hit => hit || caches.match("index.html")).then(hit => hit || net)));   // nothing saved yet: keep waiting
    return;
  }
  const isFont = url.hostname === "fonts.googleapis.com" || url.hostname === "fonts.gstatic.com";
  if (url.origin !== location.origin && !isFont) return;
  e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => {   // cache first for everything else
    if (r.ok || r.type === "opaque") { const copy = r.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
    return r;
  })));
});
