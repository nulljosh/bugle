// A week of headlines, kept across refreshes in this browser, so a story can show its timeline: the days before,
// including what the feeds no longer carry (Ground News's timeline). Bodies are dropped to keep it small. Same rule as
// Archive.swift. Uses reader.js's el and open.
var Timeline = (function () {
  var KEY = 'bugle.archive', list = [];
  try { list = (JSON.parse(localStorage.getItem(KEY)) || []).map(function (e) { return Object.assign(e, { date: new Date(e.date) }); }); } catch (e) {}
  function keep(fresh) {
    var seen = {}, week = Date.now() - 7 * 86400000;
    list = fresh.map(function (e) { return { title: e.title, url: e.url, date: e.date, source: e.source, image: e.image }; }).concat(list)
      .filter(function (e) { return e.date >= week && !seen[e.url] && (seen[e.url] = true); })
      .sort(function (a, b) { return b.date - a.date; }).slice(0, 2000);   // ponytail: a cap, not a smarter store
    try { localStorage.setItem(KEY, JSON.stringify(list)); } catch (e) {}
  }
  // the story's timeline: its own headlines and the archive's matching ones (same grouping rule) from more than
  // 12 hours before the lead, newest first
  function earlier(st, archive) {
    // the same test the grouping uses, with the week's own common words left out
    var ids = {}, lead = st.lead || st.entries[0], pool = archive || list;
    var noise = Coverage.common(pool.map(function (e) { return e.title; }));
    var strip = function (t) { var k = Coverage.keywords(t); noise.forEach(function (w) { k.delete(w); }); return k; };
    var kw = strip(lead.title);
    st.entries.forEach(function (e) { ids[e.url] = true; });
    var matches = pool.filter(function (e) { return !ids[e.url] && Coverage.same(kw, strip(e.title)); });
    var cutoff = +lead.date - 12 * 3600000;
    return st.entries.concat(matches).filter(function (e) { return +e.date < cutoff; }).sort(function (a, b) { return b.date - a.date; });
  }
  function render(box, st) {
    var found = earlier(st);
    if (!found.length) return;
    box.appendChild(el('h3', 'earlier-head', 'Earlier'));
    var ul = el('ul', 'rows earlier');
    found.forEach(function (e) {
      var b = el('button', 'row'), t = el('span', 'txt');
      t.appendChild(el('small', '', e.source + ' \u00b7 ' + e.date.toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' })));
      t.appendChild(el('span', '', e.title));
      b.appendChild(t); b.onclick = function () { open(Object.assign({ html: '' }, e)); };
      var li = el('li'); li.appendChild(b); ul.appendChild(li);
    });
    var g = el('div', 'group'); g.appendChild(ul); box.appendChild(g);
  }
  return { keep: keep, earlier: earlier, render: render };
})();
