// Ground News-style coverage, ported from Sidewise: the same story grouped across outlets, each outlet's lean and
// owner, a left / center / right count, blindspots. Mirrors Coverage.swift; change both or neither. Leans are
// Bugle's own rating, -2 (left) to +2 (right); tech outlets and blogs are unrated, not center.
var Coverage = (function () {
  var O = function (lean, owner, publisher) { return { lean: lean, owner: owner, publisher: publisher }; };
  var OUTLETS = {
    'CBC': O(-1, 'Canadian public broadcaster', 'CBC'), 'The Guardian': O(-1, 'Guardian Media Group (Scott Trust)', 'The Guardian'),
    'NPR': O(-1, 'US nonprofit public radio', 'NPR'), 'BBC': O(0, 'UK public broadcaster', 'BBC'),
    'Global News': O(0, 'Corus Entertainment', 'Global News'), 'NBC News': O(-1, 'NBCUniversal (Comcast)', 'NBC News'),
    'Wall Street Journal': O(1, 'Dow Jones (News Corp)', 'Wall Street Journal'), 'National Post': O(1, 'Postmedia', 'National Post'),
    'Fox News': O(2, 'Fox Corporation', 'Fox News'), 'NY Post': O(2, 'News Corp', 'NY Post'), 'NY Post Opinion': O(2, 'News Corp', 'NY Post'),
    'Daily Wire': O(2, 'The Daily Wire (independent)', 'Daily Wire'), 'Vancouver Sun': O(0, 'Postmedia', 'Postmedia BC'),
    'The Province': O(0, 'Postmedia', 'Postmedia BC'), 'Hacker News': O(null, 'Y Combinator', 'Hacker News'),
    'Daring Fireball': O(null, 'John Gruber (independent)', 'Daring Fireball'), 'Journal': O(null, "Joshua's blog", 'Journal'),
    'Wired': O(null, 'Condé Nast', 'Wired'), 'The Verge': O(null, 'Vox Media', 'The Verge'), 'Ars Technica': O(null, 'Condé Nast', 'Ars Technica'), 'TechCrunch': O(null, 'Yahoo', 'TechCrunch'), 'Macworld': O(null, 'Foundry', 'Macworld'), 'Six Colors': O(null, 'Jason Snell (independent)', 'Six Colors')
  };
  // Each outlet's own color, [light, dark], each at least 4.5:1 on white and on black (test.mjs checks). Black brands
  // (WSJ, Daily Wire) turn white in dark mode; HN orange is darkened in light mode so a 13 pt name stays readable.
  var BRAND = {
    'Hacker News': ['#C24E00', '#FF7A1A'], 'BBC': ['#BB1919', '#FF6B6B'], 'CBC': ['#CC0000', '#FF6B6B'],
    'The Guardian': ['#052962', '#7FA8F0'], 'NPR': ['#1D6AA5', '#5AAEF0'], 'Global News': ['#1565C0', '#64A8FF'],
    'NBC News': ['#0A66B0', '#4CB6F5'], 'Wall Street Journal': ['#111111', '#F5F5F7'], 'National Post': ['#005A9C', '#63A4E0'],
    'Fox News': ['#003366', '#6FA3E0'], 'NY Post': ['#CC0000', '#FF6B6B'], 'NY Post Opinion': ['#CC0000', '#FF6B6B'],
    'Daily Wire': ['#111111', '#F5F5F7'], 'Vancouver Sun': ['#12599E', '#6AA6E6'], 'The Province': ['#C8102E', '#FF6B78'],
    'Daring Fireball': ['#4A525A', '#A3ABB3'], 'Journal': ['#0059B3', '#5AA9FF'],
    'Wired': ['#333333', '#BDBDBD'], 'Ars Technica': ['#C2410C', '#FF7A3D'], 'TechCrunch': ['#0A7A00', '#3DDC2F'], 'Macworld': ['#C8102E', '#FF6B6B']
  };
  // A feed Bugle doesn't know gets a steady color from its name, from this set (same contrast rule, no purple or teal).
  // ponytail: a name hash, not the site's own color; read its theme-color if someone wants the real brand.
  var PALETTE = [['#C62828', '#FF6B6B'], ['#C24E00', '#FF8A3D'], ['#2E7D32', '#5FD068'], ['#1565C0', '#64A8FF'],
    ['#1A3A6B', '#7FA8F0'], ['#C2185B', '#FF6FA5'], ['#B00020', '#FF5C7A'], ['#1B5E20', '#66BB6A'], ['#455A64', '#A3B4BD'], ['#0D47A1', '#82B1FF']];
  var FAMILY = { 'CBC ': 'CBC', 'Global ': 'Global News', 'BBC ': 'BBC', 'NY Post ': 'NY Post' };
  function colors(source) {
    if (BRAND[source]) return BRAND[source];
    // A newsroom's local desks wear its color: "CBC Toronto", "Global BC", "BBC London", "NY Post Metro".
    for (var p in FAMILY) if (source.indexOf(p) === 0) return BRAND[FAMILY[p]];
    for (var h = 0, i = 0; i < source.length; i++) h = (h * 31 + source.charCodeAt(i)) >>> 0;   // same hash as Outlet.colors in Swift
    return PALETTE[h % PALETTE.length];
  }
  // Paint an element in an outlet's color: --c and --cd, which reader.css picks between for light and dark.
  function paint(node, source) { if (source) { var b = colors(source); node.style.setProperty('--c', b[0]); node.style.setProperty('--cd', b[1]); } return node; }
  var SIDES = ['left', 'center', 'right'], TITLES = { left: 'Left', center: 'Center', right: 'Right' };
  var STOP = new Set(('the a an of to in on for and or as at by is are was with after over from amid says say new this that it its his her ' +
    'their they we you but not has have had will would could should about into more than what when who how why been being were where which').split(' '));
  var side = function (lean) { return lean < 0 ? 'left' : lean > 0 ? 'right' : 'center'; };
  var leanLabel = function (lean) { return ['Left', 'Leans left', 'Center', 'Leans right', 'Right'][Math.max(0, Math.min(4, lean + 2))]; };
  var outlet = function (source) { return OUTLETS[source] || null; };
  function keywords(t) {
    return new Set(String(t).toLowerCase().replace(/[^a-z0-9 ]/g, ' ').split(/\s+/).filter(function (w) { return w.length > 2 && !STOP.has(w); }));
  }
  function counts(entries) {
    var seen = { left: new Set(), center: new Set(), right: new Set() };
    entries.forEach(function (e) { var o = outlet(e.source); if (o && o.lean != null) seen[side(o.lean)].add(o.publisher); });
    return { left: seen.left.size, center: seen.center.size, right: seen.right.size };
  }
  // One story: two keywords in common at least ("Netflix" alone is not a story) and half of the shorter headline's,
  // against the headline that seeded the story (its lead), never every word a group collected. Mirrors Coverage.sameStory.
  function same(a, b) {
    var n = 0; b.forEach(function (w) { if (a.has(w)) n++; });
    return n >= 2 && n / Math.min(a.size, b.size) >= 0.5;
  }
  // Words in so many of today's headlines they say nothing about which story it is ("apple", "iphone" on a tech day):
  // in more headlines than any one story gets, max(8, 1 in 40). Mirrors Coverage.common.
  function common(titles) {
    var df = {}, cut = Math.max(8, Math.floor(titles.length / 40)), out = new Set();
    titles.forEach(function (t) { keywords(t).forEach(function (w) { df[w] = (df[w] || 0) + 1; }); });
    Object.keys(df).forEach(function (w) { if (df[w] > cut) out.add(w); });
    return out;
  }
  // Group stories sharing their headline keywords; the newest seeds each group. O(n²), like Sidewise.
  function cluster(entries) {
    var groups = [], noise = common(entries.map(function (e) { return e.title; }));
    entries.slice().sort(function (a, b) { return b.date - a.date; }).forEach(function (e) {
      var kw = keywords(e.title), hit = null;
      noise.forEach(function (w) { kw.delete(w); });
      if (kw.size) hit = groups.find(function (g) { return same(g.kw, kw); });
      if (hit) hit.entries.push(e); else groups.push({ kw: kw, entries: [e] });
    });
    return groups.map(function (g) {
      var c = counts(g.entries), pubs = new Set(g.entries.map(function (e) { var o = outlet(e.source); return o ? o.publisher : e.source; })).size;
      var lit = SIDES.filter(function (k) { return c[k] > 0; });
      return { lead: g.entries[0], entries: g.entries, counts: c, publishers: pubs, blindspot: lit.length === 1 && pubs > 1 ? lit[0] : null };
    });
  }
  // Today: the five biggest stories of the last day (most newsrooms, at least two) lead Home, then the rest, newest first.
  // Muted: an outlet by name, or any headline containing the word. Mirrors Coverage.isMuted.
  function muted(e, list) {
    var s = e.source.toLowerCase(), t = e.title.toLowerCase();
    return list.some(function (m) { m = m.toLowerCase(); return s === m || t.indexOf(m) >= 0; });
  }
  function today(stories, now) {
    now = now || Date.now();
    var top = stories.filter(function (s) { return s.publishers > 1 && now - s.lead.date < 864e5; })
      .sort(function (a, b) { return b.publishers - a.publishers || b.lead.date - a.lead.date; }).slice(0, 5);
    return top.concat(stories.filter(function (s) { return top.indexOf(s) < 0; }));
  }
  function readingLean(history) { var c = { left: 0, center: 0, right: 0 }; history.forEach(function (e) { var o = outlet(e.source); if (o && o.lean != null) c[side(o.lean)]++; }); return c; }
  function bar(c) {
    var total = c.left + c.center + c.right || 1, wrap = el('div', 'leanbar'), track = el('div', 'track'), legend = el('div', 'legend');
    SIDES.forEach(function (k) {
      if (c[k]) { var seg = el('span', k); seg.style.flexGrow = c[k] / total; track.appendChild(seg); }
      legend.appendChild(el('span', '', TITLES[k] + ' ' + c[k]));
    });
    if (!c.left && !c.center && !c.right) track.classList.add('empty');
    wrap.appendChild(track); wrap.appendChild(legend);
    return wrap;
  }
  // Every outlet's take, side by side by lean, under a story's body.
  function section(story, onOpen) {
    var box = el('section', 'coverage');
    box.appendChild(el('h3', '', 'Coverage'));
    box.appendChild(bar(story.counts));
    if (story.blindspot) box.appendChild(el('p', 'note-line', 'Blindspot: only ' + (story.blindspot === 'center' ? 'center' : story.blindspot + '-leaning') + ' outlets covered this.'));
    box.appendChild(el('p', 'note-line', 'Covered by ' + story.publishers + ' newsrooms. Leans are Bugle’s own rating of each outlet.'));
    SIDES.concat(['unrated']).forEach(function (k) {
      var rows = story.entries.filter(function (e) { var o = outlet(e.source); return k === 'unrated' ? !o || o.lean == null : o && o.lean != null && side(o.lean) === k; });
      if (!rows.length) return;
      box.appendChild(el('p', 'label', k === 'unrated' ? 'Not rated' : TITLES[k]));
      var ul = el('ul', 'rows group');
      rows.forEach(function (e) {
        var b = el('button', 'row'), t = el('span', 'txt'), o = outlet(e.source);
        var k2 = el('small', 'kick'); k2.appendChild(paint(el('span', 'src', e.source), e.source));
        k2.appendChild(document.createTextNode((o && o.lean != null ? ' · ' + leanLabel(o.lean) : '') + (ago(e.date) ? ' · ' + ago(e.date) : '')));
        t.appendChild(k2); t.appendChild(el('span', 'cov-title', Headline.clean(e.title, e.source)));
        b.appendChild(t); b.onclick = function () { onOpen(e); };
        var li = el('li'); li.appendChild(b); ul.appendChild(li);
      });
      box.appendChild(ul);
    });
    return box;
  }
  function about(feed) { var o = outlet(feed.title); return o ? (o.lean == null ? 'Not rated' : leanLabel(o.lean)) + ' · ' + o.owner : feed.url; }
  return { keywords: keywords, same: same, common: common, cluster: cluster, today: today, muted: muted, BRAND: BRAND, PALETTE: PALETTE, OUTLETS: OUTLETS, colors: colors, paint: paint, readingLean: readingLean, bar: bar, section: section, about: about };
})();
