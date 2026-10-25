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

  const declared = Number(upstream.headers.get("content-length"));
  if (declared > MAX_BYTES) return bad("feed too large", 413);

  // content-length is optional, so cap the stream itself as well.
  let seen = 0;
  const capped = upstream.body?.pipeThrough(
    new TransformStream({
      transform(chunk, controller) {
        seen += chunk.byteLength;
        if (seen > MAX_BYTES) controller.error(new Error("feed too large"));
        else controller.enqueue(chunk);
      },
    }),
  );

  return new Response(capped, {
    status: upstream.status,
    headers: {
      "content-type": upstream.headers.get("content-type") || "application/xml",
      "access-control-allow-origin": ORIGIN,
      "cache-control": "public, max-age=300",
    },
  });
}

function bad(message, status = 400) {
  return new Response(message, {
    status,
    headers: { "access-control-allow-origin": ORIGIN },
  });
}
