// The last catch for a story with no image in its feed: the article page's preview image (og:image, then
// twitter:image). Reads only the top of the page and answers JSON, cached for a day. Same guards as feed.js.
// Mirrors ios/Sources/Shared/Services/PreviewImage.swift.
const ORIGIN = "https://bugle.jaybulb.com";
// A full browser user agent with Bugle named at the end: some publishers (CBC) drop anything that does not look
// like a browser, and naming Bugle keeps it honest.
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15 Bugle/1.0 (+https://bugle.jaybulb.com)";
const HEAD_BYTES = 256 * 1024;
const PRIVATE = /^(0|10|127|169\.254|172\.(1[6-9]|2\d|3[01])|192\.168)\./;
const NAMES = ["og:image:secure_url", "og:image", "twitter:image", "twitter:image:src"];

export function ogImage(html, base) {
  for (const name of NAMES) {
    const n = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const res = [
      new RegExp(`<meta[^>]+(?:property|name)\\s*=\\s*["']${n}["'][^>]*content\\s*=\\s*["']([^"']+)["']`, "i"),
      new RegExp(`<meta[^>]+content\\s*=\\s*["']([^"']+)["'][^>]*(?:property|name)\\s*=\\s*["']${n}["']`, "i"),
    ];
    for (const re of res) {
      const m = re.exec(html);
      if (!m) continue;
      try {
        const u = new URL(m[1].replace(/&amp;/g, "&"), base);
        if (u.protocol === "https:" || u.protocol === "http:") return u.href;
      } catch {}
    }
  }
  return null;
}

export async function onRequestGet({ request }) {
  const target = new URL(request.url).searchParams.get("url");
  let u;
  try { u = new URL(target); } catch { return json({ error: "bad url" }, 400); }
  if (u.protocol !== "https:" && u.protocol !== "http:") return json({ error: "http(s) only" }, 400);
  if (u.hostname === "localhost" || PRIVATE.test(u.hostname)) return json({ error: "blocked host" }, 400);
  let image = null;
  try {
    const r = await fetch(u.toString(), {
      headers: { "user-agent": UA },
      cf: { cacheTtl: 86400, cacheEverything: true },
      signal: AbortSignal.timeout(8000),
    });
    const reader = r.body.getReader();
    let html = "", size = 0;
    const dec = new TextDecoder();
    while (size < HEAD_BYTES) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      html += dec.decode(value, { stream: true });
      if (/<\/head>/i.test(html)) break;
    }
    reader.cancel().catch(() => {});
    image = ogImage(html, u.href);
  } catch {}
  return json({ image }, 200, 86400);
}

function json(body, status, maxAge = 0) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "access-control-allow-origin": ORIGIN, "cache-control": `public, max-age=${maxAge}` },
  });
}
