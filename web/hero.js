// Hero wall: Bugle's timeline, live. Story cards pull today's headlines through Bugle's own feed proxy,
// swap in a new story every few seconds and show how left, center and right covered it.
(function () {
  var wall = document.getElementById('swall'); if (!wall) return;
  var still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  var n = innerWidth <= 560 ? 3 : innerWidth <= 900 ? 6 : 9;
  // Shown until the live feeds land, or for good if they don't (local preview, offline).
  var stories = [
    ['Top story', 'Central bank holds rates steady as inflation cools'], ['Tech', 'Show HN: a tiny database that fits in one file'],
    ['World', 'Leaders meet for climate talks as deadline nears'], ['Local', 'City council approves new rapid transit line'],
    ['Science', 'Telescope spots water vapour on a distant planet'], ['Business', 'Housing starts climb for a third straight month'],
    ['Sport', 'Underdogs clinch the title in extra time'], ['Health', 'New guidance on screen time for young children'],
    ['Tech', 'Open source model tops the coding leaderboard'], ['World', 'Ceasefire talks resume after a week of strikes'],
    ['Local', 'Rent growth slows across the region'], ['Science', 'Researchers map the brain of a fruit fly, neuron by neuron']
  ];
  var FEEDS = [['BBC News', 'https://feeds.bbci.co.uk/news/rss.xml'], ['NPR', 'https://feeds.npr.org/1001/rss.xml'], ['The Guardian', 'https://www.theguardian.com/world/rss']];
  var k = 0, cards = [];
  var el = function (t, c, x) { var e = document.createElement(t); if (c) e.className = c; if (x != null) e.textContent = x; return e; };
  var r = function (a, b) { return a + Math.floor(Math.random() * (b - a + 1)); };
  function fill(c, fresh) {
    var s = stories[k++ % stories.length], L = r(1, 7), C = r(1, 6), R = r(0, 6), t = L + C + R;
    c.src.textContent = s[0]; c.title.textContent = s[1]; c.time.textContent = fresh ? 'now' : r(2, 50) + 'm';
    c.l.style.flexGrow = L; c.c.style.flexGrow = C; c.r.style.flexGrow = R;
    c.meta.textContent = t + ' sources · ' + L + ' left · ' + C + ' center · ' + R + ' right';
  }
  for (var i = 0; i < n; i++) {
    var a = el('article', 'sc'), h = el('div', 'sc-head'), bar = el('div', 'sc-bar'), c = { a: a };
    h.appendChild(el('i')); h.appendChild(c.src = el('span')); h.appendChild(c.time = el('time'));
    bar.appendChild(c.l = el('span', 'l')); bar.appendChild(c.c = el('span', 'c')); bar.appendChild(c.r = el('span', 'r'));
    a.appendChild(h); a.appendChild(c.title = el('h3', 'sc-title')); a.appendChild(bar); a.appendChild(c.meta = el('p', 'sc-meta'));
    fill(c); wall.appendChild(a); cards.push(c);
  }
  // Real headlines: Bugle's /feed proxy only answers its own origin, so local previews keep the list above.
  Promise.all(FEEDS.map(function (f) {
    return fetch('/feed?url=' + encodeURIComponent(f[1])).then(function (res) { return res.ok ? res.text() : ''; }).then(function (x) {
      var d = new DOMParser().parseFromString(x, 'text/xml');
      return Array.prototype.slice.call(d.querySelectorAll('item > title'), 0, 8).map(function (t) { return [f[0], t.textContent.trim()]; });
    }).catch(function () { return []; });
  })).then(function (lists) {
    var live = []; for (var j = 0; j < 8; j++) lists.forEach(function (l) { if (l[j] && l[j][1]) live.push(l[j]); });
    if (live.length >= n) { stories = live; k = 0; cards.forEach(function (c) { fill(c); }); }
  });
  if (still) return;
  cards.forEach(function (c, j) {
    (function loop() {
      setTimeout(function () {
        c.a.classList.add('out');
        setTimeout(function () { fill(c, true); c.a.classList.remove('out'); c.a.classList.add('new'); setTimeout(function () { c.a.classList.remove('new'); }, 2100); loop(); }, 320);
      }, 4200 + j * 700 + Math.random() * 2600);
    })();
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
