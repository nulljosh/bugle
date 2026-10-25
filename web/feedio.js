// Getting feeds in and out: a site address that finds its feed, and OPML. Uses reader.js's feeds, save,
// renderFeeds and refresh.
// OPML, the file every feed reader trades: import adds each outline with an xmlUrl, export writes the list.
document.getElementById('opml-in').onchange = function () {
  var file = this.files[0]; if (!file) return;
  file.text().then(function (text) {
    var added = 0;
    new DOMParser().parseFromString(text, 'text/xml').querySelectorAll('outline[xmlUrl]').forEach(function (o) {
      var url = o.getAttribute('xmlUrl');
      if (!/^https?:/i.test(url) || feeds.some(function (f) { return f.url === url; })) return;
      feeds.push({ title: o.getAttribute('title') || o.getAttribute('text') || new URL(url).hostname, url: url });
      added++;
    });
    document.getElementById('opml-note').textContent = added ? 'Added ' + added + (added === 1 ? ' feed.' : ' feeds.') : 'No new feeds in that file.';
    if (added) { save(); renderFeeds(); refresh(); }
  });
  this.value = '';
};
document.getElementById('opml-out').onclick = function () {
  var esc = function (s) { return s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;'); };
  var body = feeds.map(function (f) { return '    <outline type="rss" text="' + esc(f.title) + '" title="' + esc(f.title) + '" xmlUrl="' + esc(f.url) + '"/>'; }).join('\n');
  this.href = URL.createObjectURL(new Blob(['<?xml version="1.0" encoding="UTF-8"?>\n<opml version="2.0">\n  <head><title>Bugle feeds</title></head>\n  <body>\n' + body + '\n  </body>\n</opml>\n'], { type: 'text/x-opml' }));
};
// A site address works as well as a feed address: if the page is not a feed, follow the feed it links to.
async function discover(url) {
  try {
    var r = await fetch('/feed?url=' + encodeURIComponent(url));
    var text = await r.text();
    if (/<(rss|feed|rdf:RDF)[\s>]/.test(text)) return url;
    var link = new DOMParser().parseFromString(text, 'text/html')
      .querySelector('link[rel~="alternate"][type*="rss"], link[rel~="alternate"][type*="atom"]');
    if (link && link.getAttribute('href')) return new URL(link.getAttribute('href'), url).href;
  } catch (e) {}
  return url;
}
