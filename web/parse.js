// Feed parsing for the web reader: RSS and Atom into entries, with the image picker. Mirrors JournalFeedService
// in the app; change both or neither.
function text(node, names) {
  for (var i = 0; i < names.length; i++) {
    var el = node.querySelector(names[i]);
    if (el && el.textContent.trim()) return el.textContent.trim();
  }
  return '';
}

var IMG_EXT = /\.(jpe?g|png|gif|webp|avif)(\?|#|$)/i;

// A media/enclosure element is an image if it says so, or - declaring neither type nor
// medium - if the URL ends in an image extension.
function isImageEl(el, url) {
  var type = el.getAttribute('type');
  if (type) return /^image\//i.test(type);
  var medium = el.getAttribute('medium');
  if (medium) return medium.toLowerCase() === 'image';
  return IMG_EXT.test(url || '');
}

// Resolving against the entry link handles protocol-relative and plain relative srcs for
// free. Anything not http(s) is refused so data: blobs never become an <img src>.
function resolveImage(src, base) {
  if (!src) return '';
  try {
    var u = new URL(src, base || location.href);
    return (u.protocol === 'https:' || u.protocol === 'http:') ? u.href : '';
  } catch (e) { return ''; }
}

// media:* beats <enclosure> beats the first <img> in the body. Mirrors FeedParser.pickImage
// in the Swift app - the two parsers must agree or the same feed looks different per platform.
// BBC feeds point at a 240 px copy; the same path serves 976 px. NY Post escapes its whole path and query
// ("wp-content%2F...?w%3D1024"), so the resize never applies and a 5000 px original loads; unescape it.
// Mirrors FeedParser.sharpen.
// Pictures load over https (BBC podcast art is plain http, which an https page blocks), and BBC podcast art asks for
// 480 px instead of 3000.
function sharpen(url) {
  url = url.replace(/(ichef\.bbci\.co\.uk\/(?:ace\/\w+|news))\/\d+\//, '$1/976/').replace(/^http:\/\//, 'https://')
    .replace(/(ichef\.bbci\.co\.uk\/images\/ic)\/\d+x\d+\//, '$1/480x480/');
  var m = /^(https?:\/\/[^\/]+\/)([^?]*%2F.*)$/i.exec(url);
  if (m) try { url = m[1] + decodeURIComponent(m[2]); } catch (e) {}
  return url;
}

function imageFor(node, html, link) {
  // The widest media:* wins (the Guardian lists 140, 460 and 700 px copies), then the first image <enclosure>.
  var best = '', bestW = -1;
  ['media:thumbnail', 'media:content'].forEach(function (tag) {
    var els = node.getElementsByTagName(tag);
    for (var j = 0; j < els.length; j++) {
      var url = els[j].getAttribute('url'), w = +els[j].getAttribute('width') || 0;
      if (!url || w <= bestW || (tag !== 'media:thumbnail' && !isImageEl(els[j], url))) continue;
      var got = resolveImage(url, link);
      if (got) { best = got; bestW = w; }
    }
  });
  if (best) return best;
  var encs = node.getElementsByTagName('enclosure');
  for (var i = 0; i < encs.length; i++) {
    var u = encs[i].getAttribute('url');
    if (u && isImageEl(encs[i], u) && resolveImage(u, link)) return resolveImage(u, link);
  }
  var art = node.getElementsByTagName('itunes:image')[0];   // podcast and some blog feeds put the art here
  if (art && resolveImage(art.getAttribute('href'), link)) return resolveImage(art.getAttribute('href'), link);
  var srcs = imageSrcs(html || '');
  for (var k = 0; k < srcs.length; k++) { var r = resolveImage(srcs[k], link); if (r) return r; }
  return '';
}

// Every image URL the body offers: lazy-load attributes before src (often a placeholder), the first srcset
// entry, 1 by 1 tracking pixels skipped. Mirrors JournalFeedService.imageSrcs in the app.
function imageSrcs(html) {
  var out = [], tags = html.match(/<img\b[^>]*>/gi) || [];
  tags.forEach(function (t) {
    if (/(width|height)\s*=\s*["']?1["'\s>]/i.test(t)) return;
    var found = {}, re = /\b(data-src|data-lazy-src|data-original|srcset|src)\s*=\s*["']([^"']+)["']/gi, m;
    while ((m = re.exec(t))) found[m[1].toLowerCase()] = m[2];
    ['data-src', 'data-lazy-src', 'data-original', 'src', 'srcset'].forEach(function (k) {
      if (found[k]) out.push(k === 'srcset' ? found[k].split(',')[0].trim().split(/\s+/)[0] : found[k]);
    });
  });
  return out;
}

// A podcast episode's audio: an <enclosure> whose type says audio, or with no type, an audio file extension. Same
// rule as FeedParser.isAudio in the app.
function isAudio(type, url) {
  return type ? /^audio\//i.test(type) : /\.(mp3|m4a|aac|ogg|oga|opus|wav)(\?|#|$)/i.test(url || '');
}
function audioFor(node, link) {
  var encs = node.getElementsByTagName('enclosure');
  for (var i = 0; i < encs.length; i++) {
    var u = encs[i].getAttribute('url');
    if (u && isAudio(encs[i].getAttribute('type'), u)) return resolveImage(u, link);
  }
  return '';
}
// <itunes:duration> as seconds: "1:02:03", "16:40" or "1000"; 0 when there is none. Same as FeedParser.seconds.
function seconds(s) {
  var parts = String(s || '').trim().split(':');
  if (!parts[0] || parts.length > 3 || parts.some(function (p) { return !/^\d+$/.test(p); })) return 0;
  return parts.reduce(function (t, p) { return t * 60 + +p; }, 0);
}

// RSS <item> and Atom <entry> differ only in tag names and where the link lives.
function parse(xml, source) {
  var doc = new DOMParser().parseFromString(xml, 'application/xml');
  if (doc.querySelector('parsererror')) return [];
  var nodes = doc.querySelectorAll('item, entry');
  var out = Array.prototype.map.call(nodes, function (n) {
    var link = text(n, ['link']) ||
      (n.querySelector('link[href]') ? n.querySelector('link[href]').getAttribute('href') : '');
    var d = text(n, ['pubDate', 'updated', 'published', 'dc\\:date']);
    var html = text(n, ['content\\:encoded', 'content', 'description', 'summary']) || tagText(n, 'itunes:summary');
    var audio = audioFor(n, link);
    return {
      title: text(n, ['title']) || '(untitled)',
      url: link || audio,   // an episode with no page of its own is known by its audio
      date: d ? new Date(d) : new Date(0),
      html: html,
      image: sharpen(imageFor(n, html, link)),
      audio: audio,
      seconds: audio ? seconds(tagText(n, 'itunes:duration')) : 0,
      source: source
    };
  }).filter(function (e) { return e.url; });
  // WSJ and Megaphone shows give every episode the show's page as its link; an episode is then known by its audio,
  // or the whole show would collapse into one row. Same as FeedParser.parse.
  // An episode with no art of its own wears the show's.
  var links = {}, ch = doc.querySelector('channel'), art = '';
  if (ch) Array.prototype.some.call(ch.children, function (c) { return c.tagName === 'itunes:image' && (art = resolveImage(c.getAttribute('href'))); });
  out.forEach(function (e) { links[e.url] = (links[e.url] || 0) + 1; });
  out.forEach(function (e) { if (e.audio && links[e.url] > 1) e.url = e.audio; if (e.audio && !e.image) e.image = sharpen(art); });
  return out;
}
// querySelector cannot name a prefixed tag; getElementsByTagName takes the qualified name as written.
function tagText(node, name) {
  var el = node.getElementsByTagName(name)[0];
  return el ? el.textContent.trim() : '';
}

// "4 min read" at 230 words a minute; nothing for a summary too short to be worth timing. Same rule as
// JournalEntry.readingTime in the app.
function readingTime(text) {
  var words = (text.match(/\S+/g) || []).length;
  return words < 150 ? '' : Math.ceil(words / 230) + ' min read';
}

// An episode's length, "16 min"; nothing for an article. Same as JournalEntry.listenTime.
function listenTime(e) {
  return e.seconds ? Math.max(1, Math.round(e.seconds / 60)) + ' min' : '';
}
