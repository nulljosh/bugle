// A Hacker News story's comment thread, under the article. One request to HN's Algolia API returns the whole tree.
// Same rule as HNComments.swift. Uses reader.js's el and current.
var HN = (function () {
  function id(e) { var m = /news\.ycombinator\.com\/item\?id=(\d+)/.exec((e.html || '') + ' ' + e.url); return m && m[1]; }

  // HN's own tags only (p, i, pre, code, and links out); every other tag, and any attribute, is dropped
  function clean(html) {
    return (html || '').replace(/<[^>]*>|<[^>]*$/g, function (t) {
      return /^(<\/?(p|i|pre|code)>|<\/a>|<a href="https?:\/\/[^"<>\s]*"( rel="nofollow")?>)$/.test(t) ? t : '';
    });
  }

  function total(c) { return (c.children || []).reduce(function (n, k) { return n + (k.text ? 1 : 0) + total(k); }, 0); }

  // ponytail: indent stops at four levels; deeper replies sit at the fourth so a long thread stays readable
  function render(c, depth) {
    var replies = (c.children || []).map(function (k) { return render(k, depth + 1); }).join('');
    if (!c.text || !c.author) return replies;   // deleted comments keep their replies
    var when = c.created_at_i ? dateText(new Date(c.created_at_i * 1000)) : '';
    return '<div class="c' + (depth > 0 && depth < 4 ? ' r' : '') + '"><p class="meta">' + clean(c.author) + ' · ' + when + '</p>'
      + clean(c.text) + replies + '</div>';
  }

  // The thread under the story; an HN feed body is only links, so a stub with no article becomes a link to it.
  function mount(box, body, e) {
    if (!id(e)) return;
    var a = el('a', '', new URL(e.url).host); a.href = e.url; a.target = '_blank'; a.rel = 'noopener noreferrer';
    body.innerHTML = ''; body.appendChild(el('p')).appendChild(a);
    var thread = box.appendChild(el('section', 'hn'));
    fetch('https://hn.algolia.com/api/v1/items/' + id(e)).then(function (r) { return r.ok ? r.json() : null; }).then(function (item) {
      if (!item || current !== e || !total(item)) return;
      thread.appendChild(el('h3', '', total(item) + ' comments'));
      var doc = new DOMParser().parseFromString(item.children.map(function (k) { return render(k, 0); }).join(''), 'text/html');
      Array.prototype.forEach.call(doc.body.childNodes, function (n) { thread.appendChild(document.importNode(n, true)); });
      thread.querySelectorAll('a').forEach(function (l) { l.target = '_blank'; l.rel = 'noopener noreferrer nofollow'; });
    }).catch(function () {});
  }

  return { id: id, clean: clean, mount: mount };
})();
