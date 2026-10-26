// Keyboard, like a desktop feed reader: j and k move through stories, Enter opens, Esc goes back, / searches,
// r refreshes, s saves, l listens, o opens the original, 1 to 3 pick a tab. Typing in a field is left alone.
// Uses reader.js's refresh.
addEventListener('keydown', function (ev) {
  var t = ev.target, story = !document.getElementById('story').hidden;
  if (ev.metaKey || ev.ctrlKey || ev.altKey) return;
  if (/^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName)) { if (ev.key === 'Escape') t.blur(); return; }
  var click = function (id) { var n = document.getElementById(id); if (n && !n.hidden) n.click(); };
  var go = {
    '/': function () { location.hash = '#home'; document.getElementById('q').focus(); },
    'Escape': function () { if (story) history.back(); },
    'r': function () { if (!story) refresh(); },
    's': function () { if (story) click('save'); },
    'l': function () { if (story) { if (document.querySelector('.episode')) Player.toggle(); else click('listen'); } },
    'o': function () { if (story) click('open'); },
    '1': function () { location.hash = '#home'; },
    '2': function () { location.hash = '#feeds'; },
    '3': function () { location.hash = '#settings'; },
    'j': function () { step(1); },
    'k': function () { step(-1); }
  }[ev.key];
  if (go) { ev.preventDefault(); go(); }
});
function step(by) {
  if (!document.getElementById('home').hidden) {
    var rows = Array.prototype.slice.call(document.querySelectorAll('#home .hero, #home .row.story'));
    var next = rows[Math.max(0, Math.min(rows.length - 1, rows.indexOf(document.activeElement) + by))];
    if (next) { next.focus(); next.scrollIntoView({ block: 'nearest' }); }
  }
}
