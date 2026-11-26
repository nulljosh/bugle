// Hero scene, after Keyrate and Plank. A feed window lies on the desk under the title and fills with live headlines,
// newest on top, one every couple of seconds. Loose source chips drift at three depths. Every layer eases toward the
// scroll position at its own speed and leans away from the pointer on desktop. Reduced motion gets a still scene.
// ponytail: no sample stories. If the feeds fail the window stays empty and the page reads fine without it.
(function () {
  var still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  var el = function (t, c, x) { var e = document.createElement(t); if (c) e.className = c; if (x != null) e.textContent = x; return e; };
  var FEEDS = [['BBC News', 'https://feeds.bbci.co.uk/news/rss.xml'], ['The Guardian', 'https://www.theguardian.com/world/rss'],
               ['NPR', 'https://feeds.npr.org/1001/rss.xml'], ['Ars Technica', 'https://feeds.arstechnica.com/arstechnica/index']];
  var board = document.getElementById('board'), ground = document.querySelector('.ground');

  if (board) {
    var win = board.appendChild(el('div', 'win')), bar = win.appendChild(el('div', 'win-bar'));
    bar.appendChild(el('i')); bar.appendChild(el('i')); bar.appendChild(el('i')); bar.appendChild(el('b', '', 'Bugle'));
    var chips = bar.appendChild(el('span', 'chips'));
    ['Home', 'Podcasts', 'Saved', 'Mutes'].forEach(function (s, i) { chips.appendChild(el('span', i ? '' : 'on', s)); });
    var rows = win.appendChild(el('div', 'rows'));
    var read = function (f) {
      return fetch('/feed?url=' + encodeURIComponent(f[1])).then(function (r) { return r.ok ? r.text() : ''; }).then(function (x) {
        return Array.prototype.slice.call(new DOMParser().parseFromString(x, 'text/xml').querySelectorAll('item'), 0, 6).map(function (i) {
          var t = i.querySelector('title'); return t ? { src: f[0], title: t.textContent.trim() } : null;
        }).filter(Boolean);
      }).catch(function () { return []; });
    };
    Promise.all(FEEDS.map(read)).then(function (lists) {
      var all = [];
      for (var j = 0; j < 6; j++) lists.forEach(function (l) { if (l[j]) all.push(l[j]); });
      if (all.length < 8) return;
      var add = function (s) {
        var r = el('div', 'row'); r.appendChild(el('small', '', s.src)); r.appendChild(el('span', '', s.title));
        rows.insertBefore(r, rows.firstChild); while (rows.children.length > 7) rows.removeChild(rows.lastChild);
      };
      var k = 7; all.slice(0, 7).reverse().forEach(add);
      if (still) return;
      setInterval(function () { if (!document.hidden) add(all[k++ % all.length]); }, 2200);
    });
  }

  // loose chips at three depths; the middle stays clear for the title
  var sky = document.getElementById('sky'), layers = [];
  if (sky) {
    var seed = 11, rnd = function () { return (seed = (seed * 16807) % 2147483647) / 2147483647; };
    var few = innerWidth < 600;
    var words = ['BBC', 'NPR', 'Hacker News', 'Podcasts', 'Blindspot', 'Left', 'Center', 'Right', 'Briefing', 'OPML', '2x', 'Saved', 'Translate', 'RSS', 'Atom', 'Local', 'Mac', 'iPhone', 'Widget', 'Siri', 'Offline', 'Unread'];
    var depths = [
      { cls: 'far', n: 12, size: 22, lag: .7, o: .45, tilt: 10, spin: .02 },
      { cls: 'mid', n: 9, size: 36, lag: .35, o: .75, tilt: 20, spin: .04 },
      { cls: 'near', n: 6, size: 60, lag: -.35, o: .95, tilt: 34, spin: .08 }
    ];
    depths.forEach(function (d, di) {
      var layer = sky.appendChild(el('div', 'layer ' + d.cls));
      var n = few ? (d.cls === 'near' ? 0 : Math.ceil(d.n / 2)) : d.n;
      for (var i = 0; i < n; i++) {
        // stratified: alternate sides, each chip its own slice of height, jittered so none pile up
        var side = i % 2, slot = Math.floor(i / 2), slots = Math.ceil(n / 2);
        var band = d.cls === 'far' ? 24 : 13;
        var x = side ? 96 - band + rnd() * band - 4 : 2 + rnd() * band;
        var y = 4 + (slot + .15 + rnd() * .7) * (64 / slots);
        var hot = d.cls !== 'far' && rnd() < .25;
        var t = layer.appendChild(el('span', 'tok' + (hot ? ' hot' : ''), words[(i * 7 + di * 5 + 2) % words.length]));
        t.style.cssText = 'left:' + x.toFixed(1) + '%;top:' + y.toFixed(1) + '%;--s:' + d.size + 'px;opacity:' + d.o + ';' +
          'animation-duration:' + (5 + rnd() * 5).toFixed(1) + 's;animation-delay:' + (-rnd() * 10).toFixed(1) + 's;--r:' + Math.round(rnd() * 30 - 15) + 'deg';
        t.dataset.spin = ((rnd() < .5 ? -1 : 1) * d.spin * (.6 + rnd() * .8)).toFixed(3);
      }
      layers.push({ layer: layer, lag: d.lag, tilt: d.tilt, toks: Array.prototype.slice.call(layer.children) });
    });
  }

  // parallax, eased toward the target each frame so a flick of the wheel glides; the copy lifts and fades
  var copy = document.querySelector('.hero-copy');
  if (still) return;
  var now = { y: scrollY, px: 0, py: 0 }, goal = { y: scrollY, px: 0, py: 0 }, running = false;
  function frame() {
    var moving = false;
    for (var k in now) { var dd = goal[k] - now[k]; now[k] = Math.abs(dd) < .05 ? goal[k] : now[k] + dd * .12; if (now[k] !== goal[k]) moving = true; }
    var y = now.y;
    if (y < innerHeight * 1.4) {
      if (ground) ground.style.transform = 'translate3d(' + (now.px * 8).toFixed(2) + 'px,' + (y * .55 + now.py * 5).toFixed(2) + 'px,0)';
      layers.forEach(function (L) {
        L.layer.style.transform = 'translate3d(' + (now.px * L.tilt).toFixed(2) + 'px,' + (y * L.lag + now.py * L.tilt * .6).toFixed(2) + 'px,0)';
        L.toks.forEach(function (t) { t.style.rotate = (y * t.dataset.spin).toFixed(2) + 'deg'; });
      });
      if (copy) { copy.style.transform = 'translate3d(0,' + (y * .2).toFixed(2) + 'px,0)'; copy.style.opacity = Math.max(0, 1 - y / (innerHeight * .7)); }
    }
    running = moving;
    if (moving) requestAnimationFrame(frame);
  }
  function kick() { if (!running) { running = true; requestAnimationFrame(frame); } }
  addEventListener('scroll', function () { goal.y = scrollY; kick(); }, { passive: true });
  if (matchMedia('(pointer: fine)').matches) addEventListener('pointermove', function (e) {
    goal.px = -(e.clientX / innerWidth - .5) * 2; goal.py = -(e.clientY / innerHeight - .5) * 2; kick();
  }, { passive: true });
})();
