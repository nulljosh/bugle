// The whole article when a feed only sends a summary: fetch the page through /feed and keep the paragraphs of its
// main block (the <article> or <main> with the most text) as plain text, so nothing from the page runs or styles
// the reader. Same rule as FullText.swift. Uses reader.js's current and dateText.
function articleParagraphs(html) {
  var doc = new DOMParser().parseFromString(html, 'text/html');   // inert: no scripts run, no pictures load
  var paras = function (root) {
    return Array.prototype.map.call(root.querySelectorAll('p'), function (p) { return p.textContent.replace(/\s+/g, ' ').trim(); })
      .filter(function (t) { return t.length > 60; });
  };
  // menus, sidebars, footers and sign-up blurbs are not the story; neither is any line the page repeats
  doc.querySelectorAll('nav, aside, footer, header, form, figure, [class*="newsletter"], [class*="related"], [class*="promo"]')
    .forEach(function (n) { n.remove(); });
  var seen = {};
  paras(doc.body).forEach(function (t) { seen[t] = (seen[t] || 0) + 1; });
  var once = function (p) { return p.filter(function (t) { return seen[t] === 1; }); };
  var best = [];
  doc.querySelectorAll('article, main').forEach(function (b) { var p = once(paras(b)); if (p.join('').length > best.join('').length) best = p; });
  return best.length ? best : once(paras(doc.body));
}

function fillFullText(e, body, meta) {
  if (readingTime(body.textContent)) return;   // the feed already sent the story
  fetch('/feed?url=' + encodeURIComponent(e.url)).then(function (r) { return r.ok ? r.text() : ''; }).then(function (html) {
    if (!html || current !== e) return;
    var found = articleParagraphs(html), time = readingTime(found.join(' '));
    if (!time) return;
    body.innerHTML = '';
    found.forEach(function (t) { body.appendChild(el('p', '', t)); });
    meta.textContent = [e.source, dateText(e.date, 'long'), time].filter(Boolean).join(' · ');
  }).catch(function () {});
}
