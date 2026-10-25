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
function imageFor(node, html, link) {
  var tags = ['media:thumbnail', 'media:content', 'enclosure'];
  for (var i = 0; i < tags.length; i++) {
    var els = node.getElementsByTagName(tags[i]);
    for (var j = 0; j < els.length; j++) {
      var url = els[j].getAttribute('url');
      if (!url) continue;
      if (tags[i] !== 'media:thumbnail' && !isImageEl(els[j], url)) continue;
      var got = resolveImage(url, link);
      if (got) return got;
    }
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

// RSS <item> and Atom <entry> differ only in tag names and where the link lives.
function parse(xml, source) {
  var doc = new DOMParser().parseFromString(xml, 'application/xml');
  if (doc.querySelector('parsererror')) return [];
  var nodes = doc.querySelectorAll('item, entry');
  return Array.prototype.map.call(nodes, function (n) {
    var link = text(n, ['link']) ||
      (n.querySelector('link[href]') ? n.querySelector('link[href]').getAttribute('href') : '');
    var d = text(n, ['pubDate', 'updated', 'published', 'dc\\:date']);
    var html = text(n, ['content\\:encoded', 'content', 'description', 'summary']);
    return {
      title: text(n, ['title']) || '(untitled)',
      url: link,
      date: d ? new Date(d) : new Date(0),
      html: html,
      image: imageFor(n, html, link),
      source: source
    };
  }).filter(function (e) { return e.url; });
}
