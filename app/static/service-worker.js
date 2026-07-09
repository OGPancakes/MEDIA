const CACHE_NAME = "pia-social-v4";
const CORE_ASSETS = [
  "/",
  "/static/css/styles.css",
  "/static/images/pia-logo.jpeg",
  "/static/manifest.webmanifest"
];

const MEDIA_FRAME_FIX = `
.post-card img.media-frame {
  display: block;
  width: 100% !important;
  max-width: 100%;
  height: clamp(300px, 48vw, 620px) !important;
  max-height: 620px !important;
  aspect-ratio: auto !important;
  margin: 0 auto !important;
  object-fit: cover !important;
  object-position: center center !important;
}

.post-detail-thread img.media-frame,
img.media-frame {
  display: block;
  width: 100% !important;
  max-width: 100%;
  height: auto !important;
  max-height: none !important;
  margin: 0 auto !important;
  object-fit: contain !important;
  object-position: center center !important;
}

.post-card video.media-frame,
.post-detail-thread video.media-frame,
video.media-frame {
  display: block;
  width: 100% !important;
  max-width: 100%;
  height: auto !important;
  max-height: min(620px, 72vh) !important;
  object-fit: contain !important;
  object-position: center center !important;
}
`;

function isStylesheetRequest(request) {
  try {
    return new URL(request.url).pathname === "/static/css/styles.css";
  } catch (error) {
    return false;
  }
}

function appendMediaFrameFix(response) {
  return response.text().then((css) => {
    const headers = new Headers(response.headers);
    headers.set("content-type", "text/css; charset=utf-8");
    return new Response(`${css}\n${MEDIA_FRAME_FIX}`, {
      status: response.status,
      statusText: response.statusText,
      headers
    });
  });
}

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(CORE_ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") {
    return;
  }

  if (isStylesheetRequest(event.request)) {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          if (!response || response.status !== 200) {
            return response;
          }
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          return appendMediaFrameFix(response);
        })
        .catch(() => caches.match(event.request).then((cached) => cached ? appendMediaFrameFix(cached) : cached))
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) {
        return cached;
      }

      return fetch(event.request)
        .then((response) => {
          if (!response || response.status !== 200 || response.type !== "basic") {
            return response;
          }

          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          return response;
        })
        .catch(() => caches.match("/"));
    })
  );
});
