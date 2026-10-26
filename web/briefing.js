// The Briefing: today's five biggest stories, numbered, each with its first line, and how long they take to read. Listen
// reads it top to bottom with the browser's voice. Same picks and rules as BriefingView.swift. Uses reader.js's
// stories, open and el, and the Now Playing sheet's styles.
// A sentence ends at . ! or ? after a lowercase letter or digit, so "B.C." and "U.S." do not cut it short.
function firstLine(text) {
  text = (text || '').replace(/\s+/g, ' ').replace(/^Photograph:.*$/, '').trim();   // the Guardian sends only a photo credit
  var m = /[a-z0-9)\u201D\u2019][.!?](?=\s|$)/.exec(text), line = m ? text.slice(0, m.index + 2) : text;
  return line.length > 160 ? line.slice(0, 157) + '\u2026' : line;
}
function plain(html) { return new DOMParser().parseFromString(html || '', 'text/html').body.textContent || ''; }

var Briefing = (function () {
  var box = null;
  function show() {
    var five = Coverage.today(stories).slice(0, 5);
    if (!box) { box = document.createElement('dialog'); box.className = 'np brief'; document.body.appendChild(box);
      box.addEventListener('click', function (ev) { if (ev.target === box) box.close(); });
      box.addEventListener('close', function () { if (window.speechSynthesis) speechSynthesis.cancel(); }); }
    box.innerHTML = '';
    var words = five.reduce(function (n, st) { return n + (plain(st.lead.html).match(/\S+/g) || []).length; }, 0);
    var top = el('div', 'np-top'); top.appendChild(el('b', '', 'Briefing'));
    var acts = el('span', 'acts');
    if (window.speechSynthesis) {
      var say = el('button', 'done', 'Listen');
      say.onclick = function () {
        if (speechSynthesis.speaking) { speechSynthesis.cancel(); say.textContent = 'Listen'; return; }
        var u = new SpeechSynthesisUtterance(five.map(function (st, i) {
          return (i + 1) + '. ' + st.lead.source + '. ' + Headline.clean(st.lead.title, st.lead.source) + '. ' + firstLine(plain(st.lead.html));
        }).join('\n'));
        u.onend = function () { say.textContent = 'Listen'; };
        speechSynthesis.speak(u); say.textContent = 'Stop';
      };
      acts.appendChild(say);
    }
    var done = el('button', 'done', 'Done'); done.onclick = function () { box.close(); }; acts.appendChild(done);
    top.appendChild(acts); box.appendChild(top);
    box.appendChild(el('div', 'np-label', five.length + ' stories \u00B7 ' + Math.max(1, Math.ceil(words / 230)) + ' min'));
    var ul = el('ul', 'np-q');
    five.forEach(function (st, i) {
      var li = el('li'), b = el('button', 'brief-row');
      b.appendChild(el('span', 'num', String(i + 1)));
      var t = el('span', 't'); t.appendChild(kicker(st.lead)); t.appendChild(el('b', '', Headline.clean(st.lead.title, st.lead.source)));
      var line = firstLine(plain(st.lead.html)); if (line) t.appendChild(el('small', '', line));
      b.appendChild(t); b.onclick = function () { box.close(); open(st.lead); };   // reader.js's open
      li.appendChild(b); ul.appendChild(li);
    });
    box.appendChild(ul);
    box.showModal();
  }
  return { show: show };
})();
