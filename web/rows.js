// Story rows for Home, Saved and History: the outlet and time above a headline cut to fit, the picture on the right,
// and the newest story with a picture as a hero on Home. Mirrors EntryRow, Kicker and HeroRow in the app.
function el(tag, cls, text) {
  var n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text != null) n.textContent = text;
  return n;
}

// "BBC" stays BBC; "Hacker News" is HN; "The Province" is P. Mirrors EntryThumbnail.initials in the app.
function initials(source) {
  var t = String(source || '').trim();
  if (t && t.length <= 4 && t === t.toUpperCase()) return t;
  var letters = t.split(/\s+/).filter(function (w) { return w && w.toLowerCase() !== 'the'; })
    .slice(0, 2).map(function (w) { return w[0].toUpperCase(); }).join('');
  return letters || 'C';
}

// "Now", "12m ago", "3h ago", "Yesterday", then a date; undated entries show nothing. Mirrors RelativeTime.short.
function ago(d, now) {
  if (!d || !d.getTime()) return '';
  now = now || Date.now();
  var s = (now - d.getTime()) / 1000;
  if (s < 60) return 'Now';
  if (s < 3600) return Math.floor(s / 60) + 'm ago';
  if (s < 86400) return Math.floor(s / 3600) + 'h ago';
  var y = new Date(now); y.setDate(y.getDate() - 1);
  if (d.toDateString() === y.toDateString()) return 'Yesterday';
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

function kicker(e) {
  var k = el('small', 'kick');
  if (e.source) k.appendChild(window.Coverage ? Coverage.paint(el('span', 'src oc', e.source), e.source) : el('span', 'src', e.source));
  var when = ago(e.date);
  if (e.source && when) k.appendChild(document.createTextNode(' · '));
  if (when) k.appendChild(document.createTextNode(when));
  if (window.listenTime && listenTime(e)) k.appendChild(document.createTextNode(' · ' + listenTime(e)));   // an episode's length
  var st = window.storyOf && storyOf[e.url];
  if (st && st.publishers > 1) k.appendChild(document.createTextNode(' · ' + st.publishers + ' sources'));
  if (window.Player && e.audio && Player.queued(e)) k.appendChild(document.createTextNode(' · Up Next'));
  if (window.Library && Library.isSaved(e)) k.appendChild(el('span', 'saved', ' · Saved'));
  return k;
}

// The thumbnail square: the story's image, else (as it scrolls in) the article's preview image, else the outlet's
// own icon, else its initials.
function thumb(e) {
  var mono = el('span', 'thumb mono', initials(e.source));
  if (window.Coverage) Coverage.paint(mono, e.source);   // the outlet's color, like its name above the headline
  mono.dataset.page = e.url;
  if (!e.image) return mono;
  var img = el('img', 'thumb');
  img.src = e.image; img.alt = ''; img.loading = 'lazy'; img.referrerPolicy = 'no-referrer';
  img.onerror = function () { img.replaceWith(mono); watch(mono); };
  return img;
}

function storyRow(e, onOpen) {
  var btn = el('button', 'row story' + (window.Library && Library.isRead(e) ? ' read' : ''));
  var txt = el('span', 'txt');
  txt.appendChild(kicker(e));
  var b = el('b', 'title', e.title);
  b.title = e.title;
  b._v = Headline.variants(e.title, e.source);
  txt.appendChild(b);
  btn.appendChild(txt);
  btn.appendChild(thumb(e));
  btn.onclick = function () { onOpen(e); };
  var li = el('li'); li.appendChild(btn);
  return li;
}

function heroRow(e, onOpen) {
  var btn = el('button', 'hero' + (window.Library && Library.isRead(e) ? ' read' : ''));
  var img = el('img');
  img.src = e.image; img.alt = ''; img.referrerPolicy = 'no-referrer';
  img.onerror = function () { img.remove(); btn.classList.add('noimg'); };
  btn.appendChild(img);
  // the outlet and headline sit on glass rising out of the photo, like an App Store Today card (same as the app)
  var glass = el('span', 'glass');
  glass.appendChild(kicker(e));
  // the longest clean cut up to 90 characters, so even the hero ends on a whole phrase (same as the app)
  var v = Headline.variants(e.title, e.source);
  glass.appendChild(el('h3', '', v.find(function (x) { return x.length <= 90; }) || v[v.length - 1]));
  btn.appendChild(glass);
  btn.onclick = function () { onOpen(e); };
  var li = el('li', 'hero-item'); li.appendChild(btn);
  return li;
}

// Fill a list. withHero puts the newest story with a picture (among the first five) on top, big.
function renderStories(ul, list, onOpen, withHero, empty) {
  ul.innerHTML = '';
  if (!list.length) { ul.appendChild(el('li', 'muted', empty)); return; }
  var hero = withHero ? list.slice(0, 5).find(function (e) { return e.image; }) : null;
  if (hero) ul.appendChild(heroRow(hero, onOpen));
  list.slice(0, 300).forEach(function (e) { if (e !== hero) ul.appendChild(storyRow(e, onOpen)); });
  requestAnimationFrame(fitTitles);
  ul.querySelectorAll('.mono').forEach(watch);
}

// No image in the feed: ask /og for the article's preview image as the row scrolls in, and remember the answer
// (a miss too) so each page is asked once. No preview either: the outlet's own icon from its site.
var previews = {};
try { previews = JSON.parse(localStorage.getItem('coranto.previews')) || {}; } catch (e) {}
function swapIn(mono, src, cls, onFail) {
  var img = el('img', cls);
  img.alt = ''; img.referrerPolicy = 'no-referrer';
  img.onload = function () { if (mono.isConnected && img.naturalWidth > 1) mono.replaceWith(img); else if (onFail) onFail(); };
  img.onerror = function () { if (onFail) onFail(); };
  img.src = src;
}
function outletIcon(mono) {
  var host;
  try { host = new URL(mono.dataset.page).host; } catch (e) { return; }
  swapIn(mono, 'https://' + host + '/apple-touch-icon.png', 'thumb', function () {
    swapIn(mono, 'https://' + host + '/favicon.ico', 'thumb icon');
  });
}
function preview(mono) {
  var page = mono.dataset.page;
  if (!page) return;
  var show = function (src) { if (src) swapIn(mono, src, 'thumb', function () { outletIcon(mono); }); else outletIcon(mono); };
  if (page in previews) return show(previews[page]);
  fetch('/og?url=' + encodeURIComponent(page)).then(function (r) { return r.ok ? r.json() : {}; }).then(function (d) {
    previews[page] = d.image || '';
    var keys = Object.keys(previews);
    if (keys.length > 1000) keys.slice(0, keys.length - 1000).forEach(function (k) { delete previews[k]; });
    try { localStorage.setItem('coranto.previews', JSON.stringify(previews)); } catch (e) {}
    show(previews[page]);
  }).catch(function () { outletIcon(mono); });
}
var previewSeen = window.IntersectionObserver && new IntersectionObserver(function (seen) {
  seen.forEach(function (x) { if (x.isIntersecting) { previewSeen.unobserve(x.target); preview(x.target); } });
}, { rootMargin: '400px' });
function watch(mono) { if (previewSeen) previewSeen.observe(mono); else preview(mono); }

// Each title becomes the longest headline variant that fits its row, so it ends on a word, not "…".
var measure = document.createElement('canvas').getContext('2d');
function fitTitles() {
  var bs = document.querySelectorAll('.title');
  if (!bs.length) return;
  var cs = getComputedStyle(bs[0]);
  measure.font = cs.fontWeight + ' ' + cs.fontSize + ' ' + cs.fontFamily;
  bs.forEach(function (b) {
    var w = b.clientWidth, v = b._v || [b.title];
    if (!w) return;   // hidden screen: fit when it shows
    // The canvas estimate jumps close; the live row has the final say (fonts may still be loading).
    // Two lines (wrapping wastes some of the second, hence 1.8).
    var i = Math.max(0, v.findIndex(function (x) { return measure.measureText(x).width <= w * 1.8; }));
    for (b.textContent = v[i]; b.scrollHeight > b.clientHeight + 1 && i < v.length - 1;) b.textContent = v[++i];
  });
}
var fitTimer;
function refit() { clearTimeout(fitTimer); fitTimer = setTimeout(fitTitles, 50); }
addEventListener('resize', refit);
// Refit once the web font lands (it is wider than the fallback) and whenever a list changes width.
if (document.fonts) { document.fonts.ready.then(fitTitles); document.fonts.addEventListener('loadingdone', fitTitles); }
if (window.ResizeObserver) { var ro = new ResizeObserver(refit); document.querySelectorAll('ul.rows').forEach(function (u) { ro.observe(u); }); }

// Swipe a row left to show a red action behind it, like iOS lists; swipe far, or tap the action, to run it.
// Works with a finger, a mouse drag or a trackpad; Delete or Backspace on the focused row does the same.
function swipeRemove(li, row, label, run) {
  var del = el('button', 'swipe-del', label), W = 88, x0 = null, y0 = 0, dx = 0, open = false;
  del.tabIndex = -1; del.onclick = run;
  li.classList.add('swipe'); li.insertBefore(del, row);
  row.tabIndex = 0; row.setAttribute('aria-keyshortcuts', 'Delete');
  function set(x, anim) {
    row.style.transition = anim ? 'transform .2s ease' : 'none';
    row.style.transform = x ? 'translateX(' + x + 'px)' : '';
    li.classList.toggle('swiping', !!x || !anim);
  }
  row.addEventListener('pointerdown', function (e) { x0 = e.clientX; y0 = e.clientY; dx = 0; });
  row.addEventListener('pointermove', function (e) {
    if (x0 === null) return;
    var mx = e.clientX - x0;
    if (Math.abs(mx) < 6) return;
    if (!dx && Math.abs(e.clientY - y0) > Math.abs(mx)) { x0 = null; return; }   // vertical: let the page scroll
    dx = Math.min(0, mx - (open ? W : 0)) || -0.01;
    row.setPointerCapture(e.pointerId); set(dx);
  });
  function end() {
    if (x0 === null) return; x0 = null;
    if (!dx) return;
    if (dx < -row.offsetWidth * 0.6) return run();
    open = dx < -W / 2; set(open ? -W : 0, true);
  }
  row.addEventListener('pointerup', end); row.addEventListener('pointercancel', end);
  // a drag is not a tap, and a tap on an open row just closes it
  row.addEventListener('click', function (e) {
    if (dx || open) { e.stopPropagation(); e.preventDefault(); if (!dx) { open = false; set(0, true); } dx = 0; }
  }, true);
  row.addEventListener('keydown', function (e) { if (e.key === 'Delete' || e.key === 'Backspace') run(); });
}
