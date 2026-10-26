// First run: pick a few topics to follow, like Yahoo News and SmartNews. Each becomes a chip on Home. Shown once, and
// only to a reader with nothing followed and nothing read. Same list as TopicPicker.swift. Uses library.js's Topics.
var TopicPicker = (function () {
  // web/mascot.svg with its moving parts named (lean, bell, waves), coloured by currentColor
  var MASCOT = '<svg viewBox="3 -13 300 300"><g class="lean"><rect x="22" y="92" width="160" height="22" rx="11" fill="currentColor"/>' +
    '<rect x="10" y="86" width="22" height="34" rx="8" fill="currentColor"/><path class="bell" d="M170 92 C 196 90 214 78 226 60 V 146 C 214 128 196 116 170 114 Z" fill="currentColor"/>' +
    '<path class="w w1" d="M240 92 A18 18 0 0 1 240 114"/><path class="w w2" d="M253 83 A34 34 0 0 1 253 123"/><path class="w w3" d="M266 73 A50 50 0 0 1 266 133"/>' +
    '<circle cx="100" cy="142" r="66" fill="#fff" stroke="currentColor" stroke-width="14"/><ellipse cx="80" cy="138" rx="9" ry="12" fill="#0B2545"/><ellipse cx="120" cy="138" rx="9" ry="12" fill="#0B2545"/>' +
    '<circle cx="83" cy="134" r="3" fill="#fff"/><circle cx="123" cy="134" r="3" fill="#fff"/><circle cx="64" cy="160" r="9" fill="#FF8FA3" opacity=".7"/><circle cx="136" cy="160" r="9" fill="#FF8FA3" opacity=".7"/>' +
    '<path d="M88 162 Q 100 174 112 162" fill="none" stroke="#0B2545" stroke-width="6" stroke-linecap="round"/></g></svg>';
  var WORDS = ['AI', 'Climate', 'Economy', 'Election', 'Housing', 'Markets', 'Oil', 'Space', 'Health',
    'Canada', 'Vancouver', 'China', 'Ukraine', 'Apple', 'Tesla', 'Crypto'];

  function show() {
    var box = document.createElement('dialog'); box.className = 'np picker'; document.body.appendChild(box);
    var top = el('div', 'np-top'); top.appendChild(el('b', '', 'What do you follow?'));
    var later = el('button', 'done', 'Not now'); later.onclick = function () { box.close(); }; top.appendChild(later);
    box.appendChild(top);
    // the mascot, inline so its parts move: it bobs while you choose and sounds its horn for every pick
    var face = el('div', 'pick-mascot'); face.setAttribute('aria-hidden', 'true'); face.innerHTML = MASCOT; box.appendChild(face);
    box.appendChild(el('p', 'muted', 'Pick a few. Each one becomes a chip on Home, and you can change them any time.'));
    var grid = box.appendChild(el('div', 'pick-grid'));
    WORDS.forEach(function (w) {
      var b = el('button', 'chip', w); b.setAttribute('aria-pressed', String(Topics.has(w)));
      b.onclick = function () { Topics.toggle(w); b.setAttribute('aria-pressed', String(Topics.has(w))); face.classList.remove('call'); void face.offsetWidth; face.classList.add('call'); };
      grid.appendChild(b);
    });
    var go = el('button', 'pick-go', 'Continue'); go.onclick = function () { box.close(); }; box.appendChild(go);
    box.addEventListener('close', function () { box.remove(); if (window.renderTopics) renderTopics(); });
    box.showModal();
  }

  try {
    var force = /[?&]pickTopics/.test(location.search);
    if (/[?&]embed/.test(location.search)) return { show: show };   // the landing's live demo never asks
    // after the boot splash, never over it (a modal sits above everything)
    if (force || (!localStorage.getItem('bugle.topicsPicked') && !Topics.list().length && !(window.Library && Library.history().length))) setTimeout(show, document.getElementById('splash') ? 1800 : 0);
    localStorage.setItem('bugle.topicsPicked', '1');   // asked once, whatever the answer
  } catch (e) {}
  return { show: show };
})();
