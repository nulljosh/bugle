// ponytail: seed list mirrors FeedStore.seedFeeds and journalFeed in the app. Two copies beats
// standing up an API to serve 17 URLs; if it drifts, nothing breaks but the defaults.
var JOURNAL = { title: 'Journal', url: 'https://journal.jaybulb.com/feed.xml' };
var SEEDS = [
  ['CBC', 'https://www.cbc.ca/webfeed/rss/rss-topstories'],
  ['The Guardian', 'https://www.theguardian.com/world/rss'],
  ['NPR', 'https://feeds.npr.org/1001/rss.xml'],
  ['BBC', 'https://feeds.bbci.co.uk/news/world/rss.xml'],
  ['Global News', 'https://globalnews.ca/feed/'],
  ['NBC News', 'https://feeds.nbcnews.com/nbcnews/public/news'],
  ['Wall Street Journal', 'https://feeds.content.dowjones.io/public/rss/RSSWorldNews'],
  ['National Post', 'https://nationalpost.com/feed'],
  ['Fox News', 'https://moxie.foxnews.com/google-publisher/latest.xml'],
  ['NY Post', 'https://nypost.com/feed/'],
  ['NY Post Opinion', 'https://nypost.com/opinion/feed/'],
  ['Daily Wire', 'https://www.dailywire.com/feeds/rss.xml'],
  ['Vancouver Sun', 'https://vancouversun.com/feed'],
  ['The Province', 'https://theprovince.com/feed'],
  ['Hacker News', 'https://hnrss.org/frontpage'],
  ['Daring Fireball', 'https://daringfireball.net/feeds/main']
].map(function (f) { return { title: f[0], url: f[1] }; });

var feeds = load(), entries = [], stories = [], storyOf = {};

function load() {
  try { return JSON.parse(localStorage.getItem('inkpress.feeds')) || SEEDS.slice(); }
  catch (e) { return SEEDS.slice(); }
}
function save() {
  try { localStorage.setItem('inkpress.feeds', JSON.stringify(feeds)); } catch (e) {}
  if (window.BugleAccount) BugleAccount.push();   // signed in: the account keeps the same list
}


async function refresh() {
  lastRefresh = Date.now();
  document.getElementById('entries').innerHTML = '<li class="muted">Loading…</li>';
  var results = await Promise.all(feeds.map(async function (f) {
    try {
      var r = await fetch('/feed?url=' + encodeURIComponent(f.url));
      if (!r.ok) return [];
      return parse(await r.text(), f.title);
    } catch (e) { return []; }
  }));
  // One row per story: outlets that share a newsroom (NY Post and NY Post Opinion) carry the same link.
  var seen = {};
  entries = [].concat.apply([], results).sort(function (a, b) { return b.date - a.date; })
    .filter(function (e) { return !seen[e.url] && (seen[e.url] = true); });
  // One row per story: the same story from several outlets groups (Coverage.cluster), Ground News style.
  stories = Coverage.cluster(entries); storyOf = {};
  stories.forEach(function (st) { st.entries.forEach(function (e) { storyOf[e.url] = st; }); });
  renderEntries();
}

function dateText(d, style) {
  return d.getTime() ? d.toLocaleDateString(undefined, { dateStyle: style }) : '';
}

// Search matches headlines and outlet names ("BBC" shows only BBC); while searching there is no hero. Same as the app.
function renderEntries() {
  var q = document.getElementById('q').value.trim().toLowerCase();
  var shown = (q ? stories.filter(function (st) { return st.entries.some(function (e) { return (e.title + ' ' + e.source).toLowerCase().indexOf(q) >= 0; }); }) : stories)
    .map(function (st) { return st.lead; });
  renderStories(document.getElementById('entries'), shown, open, !q,
    q ? 'No stories match \u201C' + q + '\u201D.' : 'No entries yet. Add a feed or pull to refresh.');
}
document.getElementById('q').addEventListener('input', function () { clearTimeout(this._t); this._t = setTimeout(renderEntries, 120); });

function renderFeeds() {
  var following = document.getElementById('following');
  following.innerHTML = '';
  feeds.forEach(function (f, i) {
    var row = el('div', 'row');
    var txt = el('span', 'txt');
    txt.appendChild(el('b', '', f.title)); txt.appendChild(el('small', '', Coverage.about(f)));
    var rm = el('button', 'act', 'Remove');
    rm.setAttribute('aria-label', 'Remove ' + f.title);
    rm.onclick = function () { feeds.splice(i, 1); save(); renderFeeds(); refresh(); };
    row.appendChild(txt); row.appendChild(rm);
    var li = el('li'); li.appendChild(row); following.appendChild(li);
  });
  if (!feeds.length) following.appendChild(el('li', 'muted', 'Not following anything yet.'));

  var spare = [JOURNAL].concat(SEEDS).filter(function (s) {
    return !feeds.some(function (f) { return f.url === s.url; });
  });
  var suggested = document.getElementById('suggested');
  suggested.innerHTML = '';
  document.getElementById('suggested-label').hidden = document.getElementById('suggested-group').hidden = !spare.length;
  spare.forEach(function (s) {
    var btn = el('button', 'row');
    var txt = el('span', 'txt');
    txt.appendChild(el('b', '', s.title)); txt.appendChild(el('small', '', Coverage.about(s)));
    btn.appendChild(txt); btn.appendChild(el('span', 'act', '+'));
    btn.setAttribute('aria-label', 'Follow ' + s.title);
    btn.onclick = function () { feeds.push(s); save(); renderFeeds(); refresh(); };
    var li = el('li'); li.appendChild(btn); suggested.appendChild(li);
  });
}

function show(e) {
  if (window.Library) { Library.markRead(e); document.getElementById('save').textContent = Library.isSaved(e) ? 'Saved' : 'Save'; }
  var box = document.getElementById('article');
  box.innerHTML = '';
  box.appendChild(el('h2', '', e.title));
  box.appendChild(el('p', 'meta', [e.source, dateText(e.date, 'long')].filter(Boolean).join(' · ')));
  // Feed HTML is untrusted: parse it inert and drop scripts and event handlers before
  // it ever reaches the live document.
  var frag = new DOMParser().parseFromString(e.html || '', 'text/html');
  frag.querySelectorAll('script, style, iframe, object, embed, link').forEach(function (n) { n.remove(); });
  frag.querySelectorAll('*').forEach(function (n) {
    Array.prototype.slice.call(n.attributes).forEach(function (a) {
      if (/^on/i.test(a.name) || /^\s*javascript:/i.test(a.value)) n.removeAttribute(a.name);
    });
  });
  Array.prototype.forEach.call(frag.body.childNodes, function (n) { box.appendChild(document.importNode(n, true)); });
  var p = el('p'), a = el('a', '', 'Open original');
  a.href = e.url; a.target = '_blank'; a.rel = 'noopener noreferrer';
  p.appendChild(a); box.appendChild(p);
  var st = storyOf[e.url];
  if (st && st.entries.length > 1) box.appendChild(Coverage.section(st, open));
}

// Tabs live in the hash so the browser's back button works; an open story is one extra
// history entry on top of Home.
var current = null;
var homeScroll = 0;   // coming back from a story lands where you were, like the app
function open(e) { if (location.hash.slice(1) === '' || location.hash === '#home') homeScroll = scrollY; current = e; history.pushState(null, '', '#story'); route(); }
function route() {
  var tab = location.hash.slice(1) || 'home';
  if (tab === 'story' && !current) tab = 'home';
  ['home', 'story', 'feeds', 'saved', 'history', 'settings'].forEach(function (id) { document.getElementById(id).hidden = id !== tab; });
  if (tab === 'story') show(current);
  if (tab !== 'story' && window.renderLibrary) { renderLibrary(); if (tab === 'home') renderEntries(); }   // read and saved marks stay current
  var lit = tab === 'story' ? 'home' : (tab === 'saved' || tab === 'history') ? 'feeds' : tab;
  document.querySelectorAll('.tabbar a').forEach(function (a) {
    if (a.dataset.tab === lit) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
  });
  window.scrollTo(0, tab === 'home' ? homeScroll : 0);
  refit();
}
addEventListener('hashchange', route);
addEventListener('popstate', route);
document.querySelectorAll('.back-btn[data-back]').forEach(function (b) { b.onclick = function () { history.back(); }; });
// The system share sheet where there is one (phones, Safari), otherwise copy the link.
document.getElementById('share').onclick = function () {
  if (!current) return;
  var btn = this;
  if (navigator.share) { navigator.share({ title: current.title, url: current.url }).catch(function () {}); return; }
  navigator.clipboard.writeText(current.url).then(function () {
    btn.textContent = 'Link copied';
    setTimeout(function () { btn.textContent = 'Share'; }, 1500);
  });
};

document.getElementById('add-form').addEventListener('submit', function (ev) {
  ev.preventDefault();
  var input = document.getElementById('add'), note = document.getElementById('add-note');
  var v = input.value.trim();
  if (!v) return;
  if (!/^https?:/i.test(v)) v = 'https://' + v;
  var host;
  try { host = new URL(v).hostname; } catch (e) { host = ''; }
  if (!host || feeds.some(function (f) { return f.url === v; })) {
    note.textContent = 'That is not a new feed URL.';
    return;
  }
  feeds.push({ title: host, url: v });
  input.value = '';
  note.textContent = 'Paste any RSS or Atom feed URL to follow it.';
  save(); renderFeeds(); refresh();
});
// Pull to refresh: drag down from the top of Home. Coming back to the tab after 15 minutes refreshes too, which
// is how a desktop browser (no pull) stays current.
var pullStart = null, pulled = 0, lastRefresh = Date.now(), pullEl = document.getElementById('pull');
addEventListener('touchstart', function (ev) {
  pullStart = (scrollY <= 0 && !document.getElementById('home').hidden) ? ev.touches[0].clientY : null;
}, { passive: true });
addEventListener('touchmove', function (ev) {
  if (pullStart == null) return;
  pulled = Math.max(0, Math.min(96, (ev.touches[0].clientY - pullStart) / 2));
  pullEl.style.height = pulled + 'px';
  pullEl.classList.toggle('ready', pulled >= 56);
}, { passive: true });
addEventListener('touchend', function () {
  if (pullStart == null) return;
  pullStart = null;
  if (pulled >= 56) { pullEl.classList.add('busy'); refresh().then(done, done); } else done();
  function done() { pulled = 0; pullEl.style.height = ''; pullEl.classList.remove('ready', 'busy'); }
});
document.addEventListener('visibilitychange', function () {
  if (!document.hidden && Date.now() - lastRefresh > 15 * 6e4) refresh();
});

// Same range and default as the app's Settings stepper (13 to 28 pt, 17 default).
var textSize = 17;
try { textSize = +localStorage.getItem('coranto.textSize') || 17; } catch (e) {}
function applySize(n) {
  textSize = Math.min(28, Math.max(13, n));
  document.documentElement.style.setProperty('--read-size', textSize + 'px');
  document.getElementById('size-label').textContent = textSize + ' pt';
  document.getElementById('size-sample').style.fontSize = textSize + 'px';
  try { localStorage.setItem('coranto.textSize', textSize); } catch (e) {}
}
document.getElementById('size-down').onclick = function () { applySize(textSize - 1); };
document.getElementById('size-up').onclick = function () { applySize(textSize + 1); };
applySize(textSize);

route();
renderFeeds();
refresh();
