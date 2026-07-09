const CACHE_NAME = "pia-social-css-patch-v7";

const MEDIA_FRAME_FIX = `
.post-card img.media-frame {
  display: block !important;
  width: 100% !important;
  max-width: 100% !important;
  height: clamp(300px, 48vw, 620px) !important;
  max-height: 620px !important;
  margin: 0 auto !important;
  object-fit: cover !important;
  object-position: center center !important;
}

.post-detail-thread img.media-frame,
img.media-frame {
  display: block !important;
  width: 100% !important;
  max-width: 100% !important;
  height: auto !important;
  max-height: none !important;
  margin: 0 auto !important;
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

function patchedCssResponse(response) {
  return response.text().then((css) => {
    const headers = new Headers(response.headers);
    headers.set("content-type", "text/css; charset=utf-8");
    headers.delete("content-length");
    headers.delete("content-encoding");
    return new Response(`${css}\n${MEDIA_FRAME_FIX}`, {
      status: response.status,
      statusText: response.statusText,
      headers
    });
  });
}

self.addEventListener("install", (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET" || !isStylesheetRequest(event.request)) {
    return;
  }

  event.respondWith(
    fetch(event.request, {cache: "no-store"})
      .then((response) => {
        if (!response || response.status !== 200) {
          return response;
        }
        return patchedCssResponse(response);
      })
  );
});
