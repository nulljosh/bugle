// Home as Apple would build it: a large title with the date, the Briefing as a round glass button, and search as its
// own round button beside the tab bar that swaps the bar for a glass field at the bottom (iOS 26's search tab).
// Same as EntryListView.swift. Uses reader.js's renderEntries.
var HomeHead = (function () {
  var q = document.getElementById('q'), title = document.getElementById('home-title'), clear = document.getElementById('clear-q');
  document.getElementById('home-date').textContent = new Date().toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' });
  document.getElementById('brief-btn').onclick = function () { if (window.Briefing) Briefing.show(); };
  clear.onclick = function () { q.value = ''; renderEntries(); };

  function close() { document.body.classList.remove('searching'); q.value = ''; q.blur(); renderEntries(); }
  document.getElementById('search-close').onclick = close;
  q.addEventListener('keydown', function (ev) { if (ev.key === 'Escape') close(); });
  document.getElementById('search-tab').onclick = function () {
    if (location.hash && location.hash !== '#home') location.hash = '#home';
    document.body.classList.add('searching'); q.focus();
  };

  // Filtered by an outlet or a word, the title names it and a glass button clears it; while typing, the field says it.
  function update(text) {
    var searching = document.body.classList.contains('searching');
    title.textContent = text && !searching ? text : 'Home';
    clear.hidden = !text || searching;
  }
  return { update: update };
})();
