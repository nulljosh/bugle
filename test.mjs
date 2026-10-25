// The proxy used to return any https URL with `access-control-allow-origin: *`, which
// made it usable as an anonymizing proxy by any site. These pin the guards.
import { test } from "node:test";
import assert from "node:assert/strict";
import { onRequestGet } from "./functions/feed.js";

const call = (url) =>
  onRequestGet({ request: new Request(`https://bugle.jaybulb.com/feed?url=${encodeURIComponent(url)}`) });

test("rejects non-https", async () => {
  assert.equal((await call("http://example.com/rss")).status, 400);
});

test("rejects loopback and private hosts", async () => {
  for (const h of ["http://localhost/x", "https://127.0.0.1/x", "https://169.254.169.254/x", "https://10.1.2.3/x"]) {
    assert.equal((await call(h)).status, 400, h);
  }
});

test("rejects a malformed url", async () => {
  assert.equal((await call("not a url")).status, 400);
});

test("never returns a wildcard CORS origin", async () => {
  const bad = await call("http://example.com/rss");
  assert.equal(bad.headers.get("access-control-allow-origin"), "https://bugle.jaybulb.com");

  globalThis.fetch = async () => new Response("<rss/>", { headers: { "content-type": "application/xml" } });
  const ok = await call("https://example.com/rss");
  assert.equal(ok.headers.get("access-control-allow-origin"), "https://bugle.jaybulb.com");
});

test("refuses a feed larger than the cap", async () => {
  globalThis.fetch = async () =>
    new Response("x", { headers: { "content-length": String(50 * 1024 * 1024) } });
  assert.equal((await call("https://example.com/big")).status, 413);
});

// Headline cleaning, shared rules with the Swift app (web/headline.js sets globalThis.Headline).
await import("./web/headline.js");
const { clean, variants } = globalThis.Headline;

test("headline drops section tags, outlet names and asides", () => {
  assert.equal(clean("Opinion | Congress’s Russia Problems"), "Congress’s Russia Problems");
  assert.equal(clean("Storm hits coast - BBC News", "BBC"), "Storm hits coast");
  assert.equal(clean("Rates fall (again) [Video]"), "Rates fall");
});

test("headline variants cut at a clause first, never on a filler word", () => {
  const v = variants("Jaylen Brown ratchets up Jayson Tatum drama: ‘He should stay ready at all times’");
  assert.equal(v[1], "Jaylen Brown ratchets up Jayson Tatum drama");
  assert.ok(variants("Show HN: I put employees inside S&P 500 bubbles").some((x) => x.startsWith("Show HN:")));
  for (const x of v) assert.ok(!["to", "the", "of", "at"].includes(x.split(" ").pop()), x);
  assert.ok(variants("Elon Musk says SpaceX closed Ukraine Starlink ‘loophole,’ which helped Russia target cities").every((v) => !/,’$/.test(v)));
});

// /og: the article preview image, the last thumbnail catch.
const { ogImage, onRequestGet: og } = await import("./functions/og.js");

test("og image reads either attribute order and resolves relative URLs", () => {
  assert.equal(ogImage('<meta property="og:image" content="https://x.com/i.jpg?a=1&amp;b=2">', "https://e.com/s"), "https://x.com/i.jpg?a=1&b=2");
  assert.equal(ogImage('<meta content="/p.png" name="twitter:image">', "https://e.com/a/s"), "https://e.com/p.png");
  assert.equal(ogImage("<title>none</title>", "https://e.com/"), null);
});

test("og refuses private hosts like the feed proxy", async () => {
  const r = await og({ request: new Request("https://bugle.jaybulb.com/og?url=" + encodeURIComponent("https://127.0.0.1/x")) });
  assert.equal(r.status, 400);
});

// Coverage grouping, shared rules with Coverage.swift (web/coverage.js is a classic script).
const { readFileSync } = await import("node:fs");
(await import("node:vm")).runInThisContext(readFileSync(new URL("./web/coverage.js", import.meta.url), "utf8"));

test("coverage groups one story across outlets, counts newsrooms once, flags blindspots", () => {
  const e = (title, source, t) => ({ title, source, url: source + t, date: new Date(t) });
  const stories = Coverage.cluster([
    e("Senate passes border funding bill after long debate", "Fox News", 3),
    e("Border funding bill passes Senate", "NY Post", 2),
    e("Senate approves border funding package", "NY Post Opinion", 1),
    e("Apple ships new MacBook", "Daring Fireball", 0),
  ]);
  assert.equal(stories.length, 2);
  const border = stories.find((s) => s.entries.length === 3);
  assert.equal(border.publishers, 2);
  assert.equal(border.blindspot, "right");
  assert.deepEqual(stories.find((s) => s.entries.length === 1).counts, { left: 0, center: 0, right: 0 });
  const newest = [{ publishers: 1, lead: { date: new Date(9) } }, border];
  assert.equal(Coverage.today(newest, 10)[0], border);           // two newsrooms outrank a newer single-source story
  assert.equal(Coverage.today(newest, 864e5 + 10)[0], newest[0]); // a day later it is no longer Today
});

test("outlet colors are readable in light and dark, and name real outlets", () => {
  const lum = (h) => { const c = [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16) / 255).map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4)); return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]; };
  const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
  for (const [i, [light, dark]] of Coverage.PALETTE.entries()) {
    assert.ok(ratio(light, "#ffffff") >= 4.5 && ratio(dark, "#000000") >= 4.5, "palette " + i);
  }
  assert.equal(Coverage.colors("Ars Technica"), Coverage.PALETTE[7]);   // pins the hash; Swift checks the same index
  for (const [name, [light, dark]] of Object.entries(Coverage.BRAND)) {
    assert.ok(name in Coverage.OUTLETS, name + " is not an outlet");
    assert.ok(ratio(light, "#ffffff") >= 4.5, name + " light " + light);
    assert.ok(ratio(dark, "#000000") >= 4.5, name + " dark " + dark);
  }
});

// Image sharpening, shared with FeedParser.sharpen (web/parse.js is a classic script).
(await import("node:vm")).runInThisContext(readFileSync(new URL("./web/parse.js", import.meta.url), "utf8"));

test("local desks take their newsroom's color", () => {
  assert.deepEqual(Coverage.colors("CBC Toronto"), Coverage.colors("CBC"));
  assert.deepEqual(Coverage.colors("Global BC"), Coverage.colors("Global News"));
  assert.deepEqual(Coverage.colors("NY Post Opinion"), Coverage.BRAND["NY Post Opinion"]);
});

test("mute hides an outlet by name or a word in the headline", () => {
  const e = { title: "Canucks lose again", source: "The Province" };
  assert.ok(Coverage.muted(e, ["the province"]));
  assert.ok(Coverage.muted(e, ["CANUCKS"]));
  assert.ok(!Coverage.muted(e, ["BBC", "Raptors"]));
});

test("BBC thumbnails ask for the 976 px copy, other hosts untouched", () => {
  assert.equal(sharpen("https://ichef.bbci.co.uk/ace/standard/240/cpsprodpb/a.jpg"), "https://ichef.bbci.co.uk/ace/standard/976/cpsprodpb/a.jpg");
  assert.equal(sharpen("https://ichef.bbci.co.uk/news/240/cpsprodpb/a.jpg"), "https://ichef.bbci.co.uk/news/976/cpsprodpb/a.jpg");
  assert.equal(sharpen("https://i.guim.co.uk/img/x.jpg?width=700"), "https://i.guim.co.uk/img/x.jpg?width=700");
});
