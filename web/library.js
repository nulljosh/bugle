// Saved stories and reading history, kept whole (body included) in this browser, so a saved story opens offline.
// Saved and History sit at the top of Feeds, like the app. Mirrors Library.swift. Loads after rows.js.
// A saved story keeps its pictures (its thumbnail and the ones in its body) in the service worker's image cache,
// so it opens with them offline; unsaving drops them. The worker does the fetching (sw.js).
function keepImages(e, on) {
  var sw = navigator.serviceWorker && navigator.serviceWorker.controller;
  var urls = [e.image].concat(imageSrcs(e.html || '')).filter(function (u) { return /^https?:/.test(u || ''); });
  if (sw && urls.length) sw.postMessage({ images: urls, keep: on });
}

var Library = (function () {
  var KEY = 'coranto.library', CAP = 200, data = { saved: [], history: [] };
  try { data = JSON.parse(localStorage.getItem(KEY)) || data; } catch (e) {}
  var revive = function (e) { return Object.assign({}, e, { date: new Date(e.date) }); };
  data.saved = data.saved.map(revive); data.history = data.history.map(revive);
  var has = function (list, e) { return list.some(function (x) { return x.url === e.url; }); };
  // Stories cleared with Mark All Read: read, but kept out of History so Your Reading only counts what you opened.
  var cleared = {};
  try { (JSON.parse(localStorage.getItem('bugle.cleared')) || []).forEach(function (u) { cleared[u] = true; }); } catch (e) {}
  var write = function () { try { localStorage.setItem(KEY, JSON.stringify(data)); } catch (e) {} };
  return {
    saved: function () { return data.saved; },
    history: function () { return data.history; },
    isSaved: function (e) { return has(data.saved, e); },
    isRead: function (e) { return !!cleared[e.url] || has(data.history, e); },
    markAllRead: function (list) {
      if (Object.keys(cleared).length > 3000) cleared = {};   // ponytail: past 3000 keep only what is loaded now
      list.forEach(function (e) { cleared[e.url] = true; });
      try { localStorage.setItem('bugle.cleared', JSON.stringify(Object.keys(cleared))); } catch (e) {}
    },
    toggle: function (e) {
      var on = !has(data.saved, e);
      if (on) data.saved.unshift(e); else data.saved = data.saved.filter(function (x) { return x.url !== e.url; });
      write();
      keepImages(e, on);
      if (window.BugleAccount) BugleAccount.push();
    },
    markRead: function (e) {
      data.history = [e].concat(data.history.filter(function (x) { return x.url !== e.url; })).slice(0, CAP);
      write();
    },
    clearHistory: function () { data.history = []; write(); },
    // an account sync: stories saved or read elsewhere join the lists (account.js)
    merge: function (saved, history) {
      data.saved = data.saved.concat(saved.filter(function (e) { return !has(data.saved, e); }));
      data.history = data.history.concat(history.filter(function (e) { return !has(data.history, e); }))
        .sort(function (a, b) { return b.date - a.date; }).slice(0, CAP);
      write();
    }
  };
})();

// Topics you follow (chips on Home, one tap to read only them) and words or outlets you muted (gone from
// Home), Apple News and Ground News style. Mirrors Topics in Library.swift.
function wordList(KEY) {
  var list = [];
  try { list = JSON.parse(localStorage.getItem(KEY)) || []; } catch (e) {}
  var find = function (t) { t = t.toLowerCase(); return list.findIndex(function (x) { return x.toLowerCase() === t; }); };
  return {
    list: function () { return list; },
    has: function (t) { return find(t) >= 0; },
    toggle: function (t) {
      var i = find(t);
      if (i >= 0) list.splice(i, 1); else list.push(t);
      try { localStorage.setItem(KEY, JSON.stringify(list)); } catch (e) {}
      if (window.BugleAccount) BugleAccount.push();
    }
  };
}
var Topics = wordList('bugle.topics'), Muted = wordList('bugle.muted');

function renderMuted() {   // Settings: what you muted; swipe left to unmute
  var ul = document.getElementById('muted');
  ul.innerHTML = '';
  Muted.list().forEach(function (m) {
    var row = el('div', 'row');
    row.appendChild(el('span', 'txt', m));
    var li = el('li'); li.appendChild(row); ul.appendChild(li);
    swipeRemove(li, row, 'Unmute', function () { Muted.toggle(m); renderMuted(); restory(); });
  });
  if (!Muted.list().length) ul.appendChild(el('li', 'muted', 'Nothing muted.'));
}

function renderLibrary() {
  document.getElementById('saved-count').textContent = Library.saved().length || '';
  renderStories(document.getElementById('saved-list'), Library.saved(), open, false,
    'Tap Save on a story to keep it here. Saved stories open without a connection.');
  renderStories(document.getElementById('history-list'), Library.history(), open, false, 'Stories you open show up here.');
  document.getElementById('history-clear').hidden = !Library.history().length;
  var reading = document.getElementById('reading');   // Settings: how what you read leans
  reading.innerHTML = ''; reading.appendChild(Coverage.bar(Coverage.readingLean(Library.history())));
  document.getElementById('reading-note').textContent = Library.history().length
    ? 'From the last ' + (Library.history().length === 1 ? 'story' : Library.history().length + ' stories') + ' you opened, rated outlets only.' : 'Open a few stories to see how what you read leans.';
}

document.getElementById('save').onclick = function () {
  if (!current) return;
  Library.toggle(current);
  this.setAttribute('aria-pressed', String(Library.isSaved(current)));
  renderLibrary();
};
document.getElementById('history-clear').onclick = function () { Library.clearHistory(); renderLibrary(); renderEntries(); };
renderLibrary();
renderMuted();
restory();   // reader.js drew Home before Topics and Muted existed
