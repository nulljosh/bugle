// Hero wall: Bugle's front page, live. Three big stories with their own photos, pulled through Bugle's feed proxy.
// ponytail: no sample stories. If the feeds fail the wall stays empty and the page reads fine without it.
(function () {
  var wall = document.getElementById('swall'); if (!wall) return;
  var still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  var n = innerWidth <= 560 ? 1 : innerWidth <= 900 ? 2 : 3;
  var FEEDS = [['BBC News', 'https://feeds.bbci.co.uk/news/rss.xml'], ['The Guardian', 'https://www.theguardian.com/world/rss']];
  var el = function (t, c) { var e = document.createElement(t); if (c) e.className = c; return e; };
  // The widest picture a story offers. BBC serves any width from the same path.
  function photo(item) {
    var best = '', most = 0;
    ['thumbnail', 'content'].forEach(function (tag) {
      Array.prototype.forEach.call(item.getElementsByTagNameNS('*', tag), function (m) {
        var u = m.getAttribute('url'), w = +m.getAttribute('width') || 0;
        if (u && w >= most) { best = u; most = w; }
      });
    });
    return best.replace('/standard/240/', '/standard/976/');
  }
  function read(f) {
    return fetch('/feed?url=' + encodeURIComponent(f[1])).then(function (res) { return res.ok ? res.text() : ''; }).then(function (x) {
      var items = new DOMParser().parseFromString(x, 'text/xml').querySelectorAll('item'), out = [];
      Array.prototype.forEach.call(items, function (i) {
        var t = i.querySelector('title'), img = photo(i);
        if (t && img) out.push({ source: f[0], title: t.textContent.trim(), img: img });
      });
      return out.slice(0, 8);
    }).catch(function () { return []; });
  }
  function card(s) {
    var a = el('article', 'sc'), c = { a: a, img: el('img'), src: el('span', 'sc-src'), title: el('h3', 'sc-title') };
    c.img.alt = ''; a.appendChild(c.img); a.appendChild(c.src); a.appendChild(c.title);
    show(c, s); wall.appendChild(a); return c;
  }
  function show(c, s) { c.img.src = s.img; c.src.textContent = s.source; c.title.textContent = s.title; }
  Promise.all(FEEDS.map(read)).then(function (lists) {
    var stories = [];
    for (var j = 0; j < 8; j++) lists.forEach(function (l) { if (l[j]) stories.push(l[j]); });
    if (stories.length < n) return;
    var k = n, cards = stories.slice(0, n).map(card);
    if (still || stories.length <= n) return;
    var turn = 0;
    setInterval(function () {
      var c = cards[turn++ % n], s = stories[k++ % stories.length], pre = new Image();
      pre.onload = function () {
        c.a.classList.add('out');
        setTimeout(function () { show(c, s); c.a.classList.remove('out'); }, 500);
      };
      pre.src = s.img;
    }, 5000);
  });
})();

// Hero parallax: the wall drifts at 0.45, the copy lifts at 0.2 and fades. Off under reduced motion.
(function () {
  var bg = document.querySelector('.hero-bg'), copy = document.querySelector('.hero-copy');
  if (!bg || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  var t = 0;
  addEventListener('scroll', function () {
    if (t) return;
    t = requestAnimationFrame(function () {
      t = 0; var y = scrollY, h = innerHeight; if (y > h * 1.2) return;
      bg.style.setProperty('--py', (y * .45) + 'px');
      copy.style.transform = 'translate3d(0,' + (y * .2) + 'px,0)'; copy.style.opacity = Math.max(0, 1 - y / (h * .7));
    });
  }, { passive: true });
})();
