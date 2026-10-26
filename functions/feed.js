// CORS proxy so the web reader can fetch feeds the browser would otherwise block.
// ponytail: no host allowlist -- users paste their own feed URLs, so an allowlist would
// break the feature. Abuse is closed off at the other end instead: the response is only
// readable from bugle's own origin, so this cannot be used as a general proxy by
// another site, and the body is capped so it cannot be used to pull large files.
const ORIGIN = "https://bugle.jaybulb.com";
// A full browser user agent with Bugle named at the end: some publishers (CBC) drop anything that does not look
// like a browser, and naming Bugle keeps it honest.
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15 Bugle/1.0 (+https://bugle.jaybulb.com)";
const MAX_BYTES = 5 * 1024 * 1024;

// Workers will not route to these, but a hostname can resolve to one and the check is
// two lines. ponytail: literal-IP check only, no DNS resolution -- Cloudflare's own
// egress rules are the real guard; add DoH resolution here only if that ever changes.
const PRIVATE = /^(0|10|127|169\.254|172\.(1[6-9]|2\d|3[01])|192\.168)\./;

export async function onRequestGet({ request }) {
  const target = new URL(request.url).searchParams.get("url");
  let u;
  try { u = new URL(target); } catch { return bad("bad url"); }
  if (u.protocol !== "https:") return bad("https only");
  if (u.hostname === "localhost" || PRIVATE.test(u.hostname)) return bad("blocked host");

  let upstream;
  try {
    upstream = await fetch(u.toString(), {
      headers: { "user-agent": UA },
      cf: { cacheTtl: 300, cacheEverything: true },
      signal: AbortSignal.timeout(10000),
    });
  } catch {
    return bad("feed unreachable", 502);
  }

  // A declared size past any feed's is refused before a byte is read.
  if (Number(upstream.headers.get("content-length")) > 16 * MAX_BYTES) return bad("feed too large", 413);

  // Read at most MAX_BYTES (content-length is optional). A podcast's feed carries its whole back catalog and runs past
  // that (My First Million is 9 MB): keep its newest items, cut at a whole item, rather than refuse it.
  const body = await readCapped(upstream.body);
  const out = body && trim(body.bytes, body.over);
  if (!out) return bad("feed too large", 413);

  return new Response(out, {
    status: upstream.status,
    headers: {
      // Plain text, never HTML: a pasted site address passes through here for feed discovery, and its page must
      // not run as bugle.jaybulb.com. The charset carries over so r.text() still decodes it right.
      "content-type": "text/plain; charset=" + (/charset=([^;]+)/i.exec(upstream.headers.get("content-type") || "")?.[1] || "utf-8"),
      "x-content-type-options": "nosniff",
      "content-security-policy": "sandbox",
      "access-control-allow-origin": ORIGIN,
      "cache-control": "public, max-age=300",
    },
  });
}

async function readCapped(stream) {
  if (!stream) return { bytes: new Uint8Array(), over: false };
  const reader = stream.getReader(), parts = [];
  let seen = 0, over = false;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    if (seen + value.byteLength > MAX_BYTES) { parts.push(value.subarray(0, MAX_BYTES - seen)); seen = MAX_BYTES; over = true; reader.cancel(); break; }
    parts.push(value); seen += value.byteLength;
  }
  const bytes = new Uint8Array(seen);
  let at = 0;
  for (const p of parts) { bytes.set(p, at); at += p.byteLength; }
  return { bytes, over };
}

const ITEMS = 100;   // a feed's newest 100 items; the readers show at most a show's newest 30 episodes
const enc = (s) => new TextEncoder().encode(s);
const CUTS = [[enc("</item>"), enc("\n</channel></rss>\n")], [enc("</entry>"), enc("\n</feed>\n")]];

// The body up to its ITEMS-th item, or up to its last whole item when the read was cut off, closed so it still parses.
// Byte search: the tags are ASCII in any charset a feed uses. null when an over-long body has no item to cut at.
export function trim(bytes, over) {
  for (const [end, close] of CUTS) {
    let n = 0, last = -1, i = 0;
    while ((i = find(bytes, end, i)) >= 0) { i += end.length; last = i; if (++n === ITEMS) break; }
    if (last < 0) continue;
    if (!over && n < ITEMS) return bytes;
    const out = new Uint8Array(last + close.length);
    out.set(bytes.subarray(0, last)); out.set(close, last);
    return out;
  }
  return over ? null : bytes;
}

function find(bytes, needle, from) {
  for (let i = bytes.indexOf(needle[0], from); i >= 0 && i <= bytes.length - needle.length; i = bytes.indexOf(needle[0], i + 1)) {
    let k = 1;
    while (k < needle.length && bytes[i + k] === needle[k]) k++;
    if (k === needle.length) return i;
  }
  return -1;
}

function bad(message, status = 400) {
  return new Response(message, {
    status,
    headers: { "access-control-allow-origin": ORIGIN },
  });
}
