// First run: pick a few topics to follow, like Yahoo News and SmartNews. Each becomes a chip on Home. Shown once, and
// only to a reader with nothing followed and nothing read. Same list as TopicPicker.swift. Uses library.js's Topics.
var TopicPicker = (function () {
  var WORDS = ['AI', 'Climate', 'Economy', 'Election', 'Housing', 'Markets', 'Oil', 'Space', 'Health',
    'Canada', 'Vancouver', 'China', 'Ukraine', 'Apple', 'Tesla', 'Crypto'];

  function show() {
    var box = document.createElement('dialog'); box.className = 'np picker'; document.body.appendChild(box);
    var top = el('div', 'np-top'); top.appendChild(el('b', '', 'What do you follow?'));
    var later = el('button', 'done', 'Not now'); later.onclick = function () { box.close(); }; top.appendChild(later);
    box.appendChild(top);
    var face = el('img', 'pick-mascot'); face.src = 'mascot.svg'; face.alt = ''; box.appendChild(face);   // bobs, and hops for every pick
    box.appendChild(el('p', 'muted', 'Pick a few. Each one becomes a chip on Home, and you can change them any time.'));
    var grid = box.appendChild(el('div', 'pick-grid'));
    WORDS.forEach(function (w) {
      var b = el('button', 'chip', w); b.setAttribute('aria-pressed', String(Topics.has(w)));
      b.onclick = function () { Topics.toggle(w); b.setAttribute('aria-pressed', String(Topics.has(w))); face.classList.remove('hop'); void face.offsetWidth; face.classList.add('hop'); };
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
    if (force || (!localStorage.getItem('bugle.topicsPicked') && !Topics.list().length && !(window.Library && Library.history().length))) setTimeout(show, document.getElementById('splash') ? 1600 : 0);
    localStorage.setItem('bugle.topicsPicked', '1');   // asked once, whatever the answer
  } catch (e) {}
  return { show: show };
})();
