const CACHE_NAME = "pia-social-css-patch-v8";

const MEDIA_FRAME_FIX = `
.post-card img.media-frame {
  display: block !important;
  width: 100% !important;
  max-width: 100% !important;
  height: auto !important;
  max-height: none !important;
  margin: 0 auto !important;
  object-fit: contain !important;
  object-position: center center !important;
  background: rgba(11, 61, 145, 0.05) !important;
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

body:not(.native-compose-enabled) .home-flow .composer {
  display: grid !important;
}

.web-compose-fab {
  position: fixed !important;
  right: max(1rem, env(safe-area-inset-right)) !important;
  bottom: calc(6.2rem + env(safe-area-inset-bottom)) !important;
  z-index: 70 !important;
  width: 52px !important;
  height: 52px !important;
  display: inline-grid !important;
  place-items: center !important;
  border-radius: 999px !important;
  background: #0b3d91 !important;
  color: #ffffff !important;
  text-decoration: none !important;
  font-size: 1.55rem !important;
  font-weight: 900 !important;
  line-height: 1 !important;
  box-shadow: 0 18px 44px rgba(11, 61, 145, 0.28), inset 0 0 0 1px rgba(255, 255, 255, 0.3) !important;
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
