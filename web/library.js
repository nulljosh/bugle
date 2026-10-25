// Saved stories and reading history, kept whole (body included) in this browser, so a saved story opens offline.
// Saved and History sit at the top of Feeds, like the app. Mirrors Library.swift. Loads after rows.js.
var Library = (function () {
  var KEY = 'coranto.library', CAP = 200, data = { saved: [], history: [] };
  try { data = JSON.parse(localStorage.getItem(KEY)) || data; } catch (e) {}
  var revive = function (e) { return Object.assign({}, e, { date: new Date(e.date) }); };
  data.saved = data.saved.map(revive); data.history = data.history.map(revive);
  var has = function (list, e) { return list.some(function (x) { return x.url === e.url; }); };
  var write = function () { try { localStorage.setItem(KEY, JSON.stringify(data)); } catch (e) {} };
  return {
    saved: function () { return data.saved; },
    history: function () { return data.history; },
    isSaved: function (e) { return has(data.saved, e); },
    isRead: function (e) { return has(data.history, e); },
    toggle: function (e) {
      if (has(data.saved, e)) data.saved = data.saved.filter(function (x) { return x.url !== e.url; });
      else data.saved.unshift(e);
      write();
    },
    markRead: function (e) {
      data.history = [e].concat(data.history.filter(function (x) { return x.url !== e.url; })).slice(0, CAP);
      write();
    },
    clearHistory: function () { data.history = []; write(); }
  };
})();

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
  this.textContent = Library.isSaved(current) ? 'Saved' : 'Save';
  renderLibrary();
};
document.getElementById('history-clear').onclick = function () { Library.clearHistory(); renderLibrary(); renderEntries(); };
renderLibrary();
