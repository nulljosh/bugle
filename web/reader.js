var loading = false, feeds = load(), entries = [], stories = [], episodes = [], storyOf = {}, dead = {};   // dead: feeds that gave nothing last refresh

function load() {
  var list;
  try { list = JSON.parse(localStorage.getItem('inkpress.feeds')) || SEEDS.slice(); } catch (e) { list = SEEDS.slice(); }
  // Podcasts arrived in 6.0; everyone gets the default shows once, after which removing one sticks.
  try {
    if (!localStorage.getItem('bugle.podcasts')) {
      localStorage.setItem('bugle.podcasts', '1');
      list = list.concat(PODCASTS.filter(function (p) { return !list.some(function (f) { return f.url === p.url; }); }));
      localStorage.setItem('inkpress.feeds', JSON.stringify(list));
    }
  } catch (e) {}
  return list;
}
function save() {
  try { localStorage.setItem('inkpress.feeds', JSON.stringify(feeds)); } catch (e) {}
  if (window.BugleAccount) BugleAccount.push();   // signed in: the account keeps the same list
}


async function refresh() {
  lastRefresh = Date.now();
  var empty = !entries.length, all = [], shown = 0;   // nothing on screen: fill in as feeds arrive
  loading = true;
  if (empty) document.getElementById('entries').innerHTML = '<li class="muted">Loading…</li>';
  var results = await Promise.all(feeds.map(async function (f) {
    try {
      var r = await fetch('/feed?url=' + encodeURIComponent(f.url));
      var got = r.ok ? parse(await r.text(), f.title) : [];
      // ponytail: a show's newest 30 episodes
      if (got.some(function (e) { return e.audio; })) got = got.sort(function (a, b) { return b.date - a.date; }).slice(0, 30);
      dead[f.url] = !got.length;
      if (empty && got.length) { all = all.concat(got); if (Date.now() - shown > 2000) { shown = Date.now(); entries = dedupe(all); restory(); } }
      return got;
    } catch (e) { dead[f.url] = true; return []; }
  }));
  loading = false;
  entries = dedupe([].concat.apply([], results));
  if (window.Timeline) Timeline.keep(entries.filter(function (e) { return !e.audio; }));
  restory();
}

// One row per story: the same story from several outlets groups (Coverage.cluster), Ground News style.
// Muted outlets and words drop out first, so a muted outlet's copy never leads or counts.
function restory() {
  var m = window.Muted ? Muted.list() : [];
  // Episodes stay out of the news: a daily show's "top stories in 10 minutes" is not coverage. The Podcasts chip lists them.
  var shown = entries.filter(function (e) { return !Coverage.muted(e, m); });
  stories = Coverage.cluster(shown.filter(function (e) { return !e.audio; })); storyOf = {};
  var titles = {};   // WSJ posts one episode to two of its shows; list it once
  episodes = shown.filter(function (e) { return e.audio && !titles[e.title] && (titles[e.title] = true); }).map(function (e) { return { lead: e, entries: [e], publishers: 1 }; });
  stories.forEach(function (st) { st.entries.forEach(function (e) { storyOf[e.url] = st; }); });
  renderEntries();
}

function dateText(d, style) {
  return d.getTime() ? d.toLocaleDateString(undefined, { dateStyle: style }) : '';
}

// Search matches headlines and outlet names ("BBC" shows only BBC); while searching there is no hero. Same as the app.
function renderEntries() {
  var q = document.getElementById('q').value.trim().toLowerCase();
  if (window.HomeHead) HomeHead.update(document.getElementById('q').value.trim());
  var shown = (Coverage.collection(q) ? Coverage.pick(q, stories)   // the collection chips: Blindspots, Popular Left, ...
    : q === 'unread' ? Coverage.today(stories).filter(function (st) { return !(window.Library && Library.isRead(st.lead)); })   // the Unread chip
    : q === 'podcasts' ? (window.Player ? Player.upNext(episodes) : episodes)
    : q ? stories.concat(episodes).filter(function (st) { return st.entries.some(function (e) { return (e.title + ' ' + e.source).toLowerCase().indexOf(q) >= 0; }); }) : Coverage.today(stories))   // episodes too: a show tapped in Feeds lists them
    .map(function (st) { return st.lead; });
  window.shownLeads = shown;   // keys.js steps through these from a story
  // One outlet on screen: the reader wears its color (HN orange, BBC red); several: Bugle blue.
  var root = document.documentElement, only = shown.length && shown.every(function (e) { return e.source === shown[0].source; }) ? shown[0].source : null;
  if (only) { Coverage.paint(root, only); root.dataset.outlet = only; }
  else { delete root.dataset.outlet; root.style.removeProperty('--c'); root.style.removeProperty('--cd'); }   // or unknown outlets inherit it
  renderStories(document.getElementById('entries'), shown, open, !q && document.body.dataset.layout !== 'compact',
    q === 'blindspots' ? 'No blindspots right now.' : q === 'unread' ? 'All caught up.' : Coverage.collection(q) ? 'Nothing here right now.' : loading && !shown.length ? 'Loading…' : q === 'podcasts' ? 'No episodes yet. Follow a podcast in Feeds.' : q ? 'No stories match \u201C' + q + '\u201D.' : 'No entries yet. Add a feed or pull to refresh.');
  if (q === 'podcasts' && window.Player && episodes.length) Player.shows(episodes, document.getElementById('entries'), function (show) { document.getElementById('q').value = show; renderEntries(); });
  if (window.renderTopics) renderTopics();
}

document.getElementById('q').addEventListener('input', function () { clearTimeout(this._t); this._t = setTimeout(renderEntries, 120); });

function renderFeeds() {
  var following = document.getElementById('following');
  following.innerHTML = '';
  feeds.forEach(function (f, i) {
    var row = el('div', 'row');
    var txt = el('span', 'txt');
    txt.appendChild(Coverage.paint(el('b', 'oc', f.title), f.title)); txt.appendChild(el('small', '', dead[f.url] ? 'Not loading right now' : Coverage.about(f)));
    // Tap an outlet to read just it: Home searches for it and takes its color.
    txt.style.cursor = 'pointer';
    txt.onclick = function () { document.getElementById('q').value = f.title; location.hash = '#home'; renderEntries(); };
    row.appendChild(txt);
    var unread = entries.filter(function (e) { return e.source === f.title && !Library.isRead(e); }).length;
    if (unread) row.appendChild(el('small', 'count', String(unread)));
    var li = el('li'); li.appendChild(row); following.appendChild(li);
    swipeRemove(li, row, 'Remove', function () { feeds.splice(i, 1); save(); renderFeeds(); refresh(); });
  });
  if (!feeds.length) following.appendChild(el('li', 'muted', 'Not following anything yet.'));

  renderLocal();

  var spare = [JOURNAL].concat(SEEDS, PODCASTS).filter(function (s) {
    return !feeds.some(function (f) { return f.url === s.url; });
  });
  var suggested = document.getElementById('suggested');
  suggested.innerHTML = '';
  document.getElementById('suggested-label').hidden = document.getElementById('suggested-group').hidden = !spare.length;
  spare.forEach(function (s) {
    var btn = el('button', 'row');
    var txt = el('span', 'txt');
    txt.appendChild(Coverage.paint(el('b', 'oc', s.title), s.title)); txt.appendChild(el('small', '', Coverage.about(s)));
    btn.appendChild(txt); btn.appendChild(el('span', 'act', '+'));
    btn.setAttribute('aria-label', 'Follow ' + s.title);
    btn.onclick = function () { feeds.push(s); save(); renderFeeds(); refresh(); };
    var li = el('li'); li.appendChild(btn); suggested.appendChild(li);
  });
}

// Feeds: pick a city, then follow its newsrooms. Followed ones say so and open like any outlet.
function renderLocal() {
  var ul = document.getElementById('local'), region = '';
  try { region = localStorage.getItem('bugle.region') || ''; } catch (e) {}
  ul.innerHTML = '';
  var pick = el('select'); pick.id = 'region'; pick.setAttribute('aria-label', 'City');
  [''].concat(LOCAL.map(function (r) { return r.city; })).forEach(function (c) {
    var o = el('option', '', c || 'Choose'); o.value = c; o.selected = c === region; pick.appendChild(o);
  });
  pick.onchange = function () { try { localStorage.setItem('bugle.region', pick.value); } catch (e) {} renderLocal(); };
  var head = el('label', 'row'); head.appendChild(el('span', 'txt', 'City')); head.appendChild(pick);
  var li = el('li'); li.appendChild(head); ul.appendChild(li);
  (LOCAL.find(function (r) { return r.city === region; }) || { feeds: [] }).feeds.forEach(function (f) {
    var on = feeds.some(function (x) { return x.url === f.url; });
    var btn = el('button', 'row'), txt = el('span', 'txt');
    txt.appendChild(Coverage.paint(el('b', 'oc', f.title), f.title)); txt.appendChild(el('small', '', region));
    btn.appendChild(txt); btn.appendChild(el('span', 'act', on ? 'Following' : '+'));
    btn.setAttribute('aria-label', (on ? 'Read ' : 'Follow ') + f.title);
    btn.onclick = on ? function () { document.getElementById('q').value = f.title; location.hash = '#home'; renderEntries(); }
      : function () { feeds.push(f); save(); renderFeeds(); refresh(); };
    var row = el('li'); row.appendChild(btn); ul.appendChild(row);
  });
}

function show(e) {
  if (window.Library) { Library.markRead(e); document.getElementById('save').setAttribute('aria-pressed', String(Library.isSaved(e))); }
  document.getElementById('story-title').textContent = Headline.clean(e.title, e.source);
  document.getElementById('open').href = e.url;
  var box = document.getElementById('article');
  box.innerHTML = '';
  box.appendChild(el('h2', '', e.title));
  var meta = box.appendChild(el('p', 'meta', ''));
  // Feed HTML is untrusted: parse it inert and drop scripts and event handlers before
  // it ever reaches the live document.
  var frag = new DOMParser().parseFromString(e.html || '', 'text/html');
  frag.querySelectorAll('script, style, iframe, object, embed, link').forEach(function (n) { n.remove(); });
  frag.querySelectorAll('*').forEach(function (n) {
    Array.prototype.slice.call(n.attributes).forEach(function (a) {
      if (/^on/i.test(a.name) || /^\s*javascript:/i.test(a.value)) n.removeAttribute(a.name);
    });
  });
  meta.textContent = [e.source, dateText(e.date, 'long'), listenTime(e) || readingTime(frag.body.textContent)].filter(Boolean).join(' · ');
  listen.hidden = !window.speechSynthesis || !!e.audio;   // an episode plays its own audio instead
  // the story's picture under the headline, like the app, unless the body already opens with pictures
  if (e.image && !frag.querySelector('img')) {
    var pic = el('img', e.audio ? 'lead art' : 'lead'); pic.src = window.HiRes ? HiRes.upsize(e.image) : e.image; pic.alt = ''; pic.referrerPolicy = 'no-referrer';
    pic.onerror = function () { pic.remove(); };
    box.appendChild(pic);
  }
  if (e.audio && window.Player) Player.mount(box, e);   // the show's art, then its player, then the show notes
  var body = box.appendChild(el('div'));
  Array.prototype.forEach.call(frag.body.childNodes, function (n) { body.appendChild(document.importNode(n, true)); });
  if (window.fillFullText && !e.audio) fillFullText(e, body, meta);   // an episode's show notes are its page
  var p = el('p'), a = el('a', '', 'Open original');
  a.href = e.url; a.target = '_blank'; a.rel = 'noopener noreferrer';
  p.appendChild(a); box.appendChild(p);
  var st = storyOf[e.url];
  if (st && st.entries.length > 1) box.appendChild(Coverage.section(st, open));
  if (window.Timeline) Timeline.render(box, st || { entries: [e] });
  if (window.HN) HN.mount(box, body, e);   // a Hacker News story: its thread last
}

// Tabs live in the hash so the browser's back button works; an open story is one extra
// history entry on top of Home.
var current = null;
var homeScroll = 0;   // coming back from a story lands where you were, like the app
function open(e) { if (location.hash.slice(1) === '' || location.hash === '#home') homeScroll = scrollY; current = e; history.pushState(null, '', '#story'); route(); }
function route() {
  hush();
  var tab = location.hash.slice(1) || 'home';
  if (tab === 'story' && !current) tab = 'home';
  ['home', 'story', 'feeds', 'saved', 'history', 'settings'].forEach(function (id) { document.getElementById(id).hidden = id !== tab; });
  if (tab === 'story') show(current);
  if (tab === 'feeds') renderFeeds();   // fresh unread counts
  if (tab !== 'story' && window.renderLibrary) { renderLibrary(); if (tab === 'home') renderEntries(); }   // read and saved marks stay current
  var lit = tab === 'story' ? 'home' : (tab === 'saved' || tab === 'history') ? 'feeds' : tab;
  document.querySelectorAll('.tabbar a').forEach(function (a) {
    if (a.dataset.tab === lit) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
  });
  window.scrollTo(0, tab === 'home' ? homeScroll : 0);
  if (window.Player) Player.mini();   // the mini player hides on its own episode's story
  refit();
}
addEventListener('hashchange', route);
addEventListener('popstate', route);
document.querySelectorAll('.back-btn[data-back]').forEach(function (b) { b.onclick = function () { history.back(); }; });
// Listen: the browser's own voice reads the headline and the story; leaving the story stops it.
var listen = document.getElementById('listen');
if (!window.speechSynthesis) listen.hidden = true;
function hush() { if (window.speechSynthesis) speechSynthesis.cancel(); document.getElementById('listen').setAttribute('aria-pressed', 'false'); }
listen.onclick = function () {
  if (listen.getAttribute('aria-pressed') === 'true') { hush(); return; }
  var say = new SpeechSynthesisUtterance(current.title + '. ' + document.getElementById('article').innerText);
  say.onend = function () { listen.setAttribute('aria-pressed', 'false'); };
  speechSynthesis.speak(say);
  listen.setAttribute('aria-pressed', 'true');
};
// The system share sheet where there is one (phones, Safari), otherwise copy the link.
document.getElementById('share').onclick = function () {
  if (!current) return;
  var btn = this;
  if (navigator.share) { navigator.share({ title: current.title, url: current.url }).catch(function () {}); return; }
  navigator.clipboard.writeText(current.url).then(function () {   // no share sheet: copy, and show a check for a moment
    var was = btn.innerHTML;
    btn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12l5 5 9-10"/></svg>';
    btn.setAttribute('aria-label', 'Link copied');
    setTimeout(function () { btn.innerHTML = was; btn.setAttribute('aria-label', 'Share'); }, 1500);
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
  if (!host) { note.textContent = 'That is not a web address.'; return; }
  note.textContent = 'Looking for the feed…';
  discover(v).then(function (url) {
    if (feeds.some(function (f) { return f.url === url; })) { note.textContent = 'You already follow that feed.'; return; }
    feeds.push({ title: host, url: url });
    input.value = '';
    note.textContent = 'Paste a site or feed address to follow it.';
    save(); renderFeeds(); refresh();
  });
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
// Reader theme (Auto, Light, Dusk, Black), the app's ReaderTheme: paints the story screen only.
var themePick = document.getElementById('reader-theme');
try { themePick.value = localStorage.getItem('bugle.readerTheme') || ''; } catch (e) {}
function applyTheme() { if (themePick.value) document.body.dataset.reader = themePick.value; else delete document.body.dataset.reader; }
themePick.onchange = function () { try { localStorage.setItem('bugle.readerTheme', themePick.value); } catch (e) {} applyTheme(); };
// Compact: no pictures and no lead story, two lines a row, more stories on screen. Same as the app's Layout picker.
var layoutPick = document.getElementById('layout-pick');
try { layoutPick.value = localStorage.getItem('bugle.layout') || ''; } catch (e) {}
function applyLayout() { if (layoutPick.value) document.body.dataset.layout = layoutPick.value; else delete document.body.dataset.layout; }
applyLayout();
layoutPick.onchange = function () { try { localStorage.setItem('bugle.layout', layoutPick.value); } catch (e) {} applyLayout(); renderEntries(); };
applyTheme();

route();
renderFeeds();
refresh();
