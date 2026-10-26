// Podcasts: one player for the whole reader, so an episode keeps playing while you read on. A
// mini player rides above the tab bar, Up Next plays in order when an episode ends, every episode picks up where you
// left off, and the lock screen and media keys get the controls through Media Session. Same rules as Player.swift.

var Player = (function () {
  var RATES = [1, 1.25, 1.5, 2], SLEEPS = [0, 15, 30, 60, 'end'], rate = 1, sleep = 0, sleepTimer = null, held = false, audio = new Audio();
  audio.preload = 'none';
  var read = function (k) { try { return JSON.parse(localStorage.getItem(k)); } catch (e) { return null; } };
  var write = function (k, v) { try { if (v == null) localStorage.removeItem(k); else localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} };
  var keep = function (e) { return { title: e.title, url: e.url, date: e.date, source: e.source, image: e.image, audio: e.audio, seconds: e.seconds, html: e.html }; };
  var revive = function (e) { if (e) e.date = new Date(e.date); return e; };
  var cur = revive(read('bugle.playing')), queue = (read('bugle.queue') || []).map(revive);
  if (cur) audio.src = cur.audio;   // the last episode comes back paused where you left it

  // Seconds into each episode, by its url. Nearly done counts as done.
  var positions = function () { return read('bugle.positions') || {}; };
  function remember() {
    if (!cur || !audio.readyState) return;   // not loaded yet: its time reads 0, which would forget where you were
    var p = positions(), t = audio.currentTime, d = audio.duration || cur.seconds || 0;
    if (t > 5 && (!d || t < d - 30)) p[cur.url] = Math.floor(t); else delete p[cur.url];
    write('bugle.positions', p);
  }
  function clock(s) {
    s = Math.max(0, Math.floor(isFinite(s) ? s : 0));
    var h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = ('0' + s % 60).slice(-2);
    return h ? h + ':' + ('0' + m).slice(-2) + ':' + sec : m + ':' + sec;
  }
  var icon = function (d, label) {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + d +
      (label ? '<text x="12" y="15.2" text-anchor="middle" font-size="7.5" font-weight="700" fill="currentColor" stroke="none">' + label + '</text>' : '') + '</svg>';
  };
  var BACK = icon('<path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3"/><path d="M4 3.5v4h4"/>', '15');
  var FWD = icon('<path d="M19.5 12a7.5 7.5 0 1 1-2.2-5.3"/><path d="M20 3.5v4h-4"/>', '30');
  var MOON = icon('<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>');
  var PLAY = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 4.5v15l13-7.5z" fill="currentColor"/></svg>';
  var PAUSE = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6.5 4.5h4v15h-4zM13.5 4.5h4v15h-4z" fill="currentColor"/></svg>';
  var btn = function (cls, html, label, fn) { var b = el('button', cls); b.innerHTML = html; b.setAttribute('aria-label', label); b.onclick = fn; return b; };
  var isCur = function (e) { return !!cur && cur.url === e.url; };

  // Play this episode now. The one playing stops where it is, and its place is kept.
  function start(e) {
    if (!isCur(e)) { remember(); cur = e; write('bugle.playing', keep(e)); audio.src = e.audio; }
    queue = queue.filter(function (x) { return x.url !== e.url; }); write('bugle.queue', queue.map(keep));
    audio.playbackRate = rate;
    audio.play().catch(function () {});
    session();
    refresh();
  }
  function toggle() { if (!cur) return; if (audio.paused) { audio.playbackRate = rate; audio.play().catch(function () {}); session(); } else audio.pause(); }
  function seek(t) { audio.currentTime = Math.max(0, Math.min(t, audio.duration || t)); remember(); paint(); }
  function queued(e) { return queue.some(function (x) { return x.url === e.url; }); }
  function toggleQueue(e) {   // add to the end of Up Next, or take it out
    if (queued(e)) queue = queue.filter(function (x) { return x.url !== e.url; }); else if (!isCur(e)) queue.push(e);
    write('bugle.queue', queue.map(keep));
    refresh();
  }

  audio.addEventListener('loadedmetadata', function () { var s = cur && positions()[cur.url]; if (s) audio.currentTime = s; paint(); });
  audio.addEventListener('timeupdate', function () { paint(); if (Math.floor(audio.currentTime) % 5 === 0) remember(); });
  audio.addEventListener('play', paint);
  audio.addEventListener('pause', function () { paint(); remember(); });
  audio.addEventListener('ended', function () {   // the next in Up Next plays, or the player clears and the mini player goes
    var p = positions(); delete p[cur.url]; write('bugle.positions', p);
    if (sleep === 'end') sleep = 0; else if (queue.length) { start(queue[0]); return; }   // the sleep timer stops here; Up Next waits
    cur = null; write('bugle.playing', null); audio.removeAttribute('src'); refresh();
  });

  // The story's bar: the player when this episode is the one loaded, otherwise Play (or Resume) and Up Next.
  function bar(e) {
    if (!isCur(e)) {
      var cue = el('div', 'episode cue');
      cue.appendChild(btn('go', PLAY + '<span>' + (positions()[e.url] ? 'Resume' : 'Play') + '</span>', positions()[e.url] ? 'Resume' : 'Play', function () { start(e); }));
      cue.appendChild(btn('next', '<span>' + (queued(e) ? 'In Up Next' : 'Up Next') + '</span>', queued(e) ? 'Remove from Up Next' : 'Add to Up Next', function () { toggleQueue(e); }));
      return cue;
    }
    var box = el('div', 'episode current'), scrub = el('input', 'scrub'), times = el('div', 'times');
    scrub.type = 'range'; scrub.min = 0; scrub.step = 1; scrub.max = cur.seconds || 1; scrub.value = 0;
    scrub.setAttribute('aria-label', 'Position');
    scrub.oninput = function () { held = true; box.querySelector('.at').textContent = clock(+scrub.value); };
    scrub.onchange = function () { held = false; seek(+scrub.value); };
    times.appendChild(el('span', 'at', '0:00')); times.appendChild(el('span', 'left', ''));
    var ctl = el('div', 'ctl'), speed = btn('rate', rate + '×', 'Speed', function () {   // 1x, 1.25x, 1.5x, 2x, then 1x
      rate = RATES[(RATES.indexOf(rate) + 1) % RATES.length]; audio.playbackRate = rate; speed.textContent = rate + '×';
    });
    [speed, btn('', BACK, 'Back 15 seconds', function () { seek(audio.currentTime - 15); }), btn('play', PLAY, 'Play', toggle),
      btn('', FWD, 'Forward 30 seconds', function () { seek(audio.currentTime + 30); }), btn('sleep', '', 'Sleep Timer', nextSleep)].forEach(function (b) { ctl.appendChild(b); });
    [scrub, times, ctl].forEach(function (n) { box.appendChild(n); });
    return box;
  }
  function mount(box, e) { var b = bar(e); b.dataset.url = e.url; box.appendChild(b); paint(); }

  // Redraw what depends on what is loaded: the open story's bar, Home's Up Next order, the mini player.
  function refresh() {
    if (np && np.open) panel();
    document.querySelectorAll('.episode').forEach(function (old) {
      if (np && np.contains(old)) return;
      var e = window.current && current.url === old.dataset.url ? current : null;
      if (e) { var b = bar(e); b.dataset.url = e.url; old.replaceWith(b); }
    });
    if (window.renderEntries && !document.getElementById('home').hidden) renderEntries();
    paint();
  }

  function paint() {
    var d = audio.duration || (cur && cur.seconds) || 0, t = audio.currentTime || (cur && !audio.readyState && positions()[cur.url]) || 0;
    document.querySelectorAll('.episode.current').forEach(function (b) {
      var s = b.querySelector('.scrub');
      if (!held) s.value = t;
      s.max = d || 1;
      if (!held) b.querySelector('.at').textContent = clock(t);
      b.querySelector('.left').textContent = d ? '-' + clock(d - t) : '';
      setPlay(b.querySelector('.play'));
      setSleep(b.querySelector('.sleep'));
    });
    mini();
  }
  // Sleep timer: off, 15, 30, 60 minutes, end of episode, then off.
  function nextSleep() {
    sleep = SLEEPS[(SLEEPS.indexOf(sleep) + 1) % SLEEPS.length];
    clearTimeout(sleepTimer);
    if (typeof sleep === 'number' && sleep) sleepTimer = setTimeout(function () { audio.pause(); sleep = 0; paint(); }, sleep * 60000);
    paint();
  }
  function setSleep(b) {
    b.innerHTML = sleep ? '<span>' + (sleep === 'end' ? 'End' : sleep + 'm') + '</span>' : MOON;
    b.classList.toggle('on', !!sleep);
    b.setAttribute('aria-label', sleep ? 'Sleep Timer, ' + (sleep === 'end' ? 'End of Episode' : sleep + ' min') : 'Sleep Timer');
  }
  function setPlay(b) { b.innerHTML = audio.paused ? PLAY : PAUSE; b.setAttribute('aria-label', audio.paused ? 'Play' : 'Pause'); }

  // Now playing, above the tab bar: the art, the episode and its show, play and forward 30. Tap it to open the
  // episode. Hidden on that episode's own story, where the full player is.
  var m = null;
  function mini() {
    if (!m) {
      m = el('div', 'mini'); m.id = 'mini'; m.hidden = true;
      var now = el('button', 'now'); now.setAttribute('aria-label', 'Now Playing');
      now.innerHTML = '<img alt=""><span class="t"><b></b><small></small></span>';
      now.onclick = openPanel;
      m.appendChild(now);
      m.appendChild(btn('play', PLAY, 'Play', toggle));
      m.appendChild(btn('', FWD, 'Forward 30 seconds', function () { seek(audio.currentTime + 30); }));
      document.body.appendChild(m);
    }
    var here = location.hash === '#story' && window.current && cur && current.url === cur.url;
    m.hidden = !cur || here;
    document.body.classList.toggle('has-mini', !m.hidden);
    if (!cur) return;
    var img = m.querySelector('img');
    if (img.getAttribute('src') !== (cur.image || '')) { if (cur.image) img.src = cur.image; else img.removeAttribute('src'); }
    m.querySelector('b').textContent = Headline.clean(cur.title, cur.source);
    m.querySelector('small').textContent = cur.source;
    setPlay(m.querySelector('.play'));
  }

  // The lock screen, Control Center and media keys.
  function session() {
    var ms = navigator.mediaSession;
    if (!ms || !cur) return;
    ms.metadata = new MediaMetadata({ title: Headline.clean(cur.title, cur.source), artist: cur.source, artwork: cur.image ? [{ src: cur.image }] : [] });
    ms.setActionHandler('play', function () { audio.play(); });
    ms.setActionHandler('pause', function () { audio.pause(); });
    ms.setActionHandler('seekbackward', function () { seek(audio.currentTime - 15); });
    ms.setActionHandler('seekforward', function () { seek(audio.currentTime + 30); });
    try { ms.setActionHandler('seekto', function (d) { seek(d.seekTime); }); } catch (x) {}
  }

  // Now Playing, from the mini player, like the app's sheet: the episode (tap it to open its story), Up Next to move up or
  // take out, then the controls. A native dialog, so Escape and focus come for free.
  var np = null, UP = icon('<path d="M12 19V5M6 11l6-6 6 6"/>'), X = icon('<path d="M6 6l12 12M18 6L6 18"/>');
  function panel() {
    if (!np) {
      np = document.createElement('dialog'); np.className = 'np'; document.body.appendChild(np);
      np.addEventListener('click', function (ev) { if (ev.target === np) np.close(); });   // a tap on the backdrop
    }
    if (!cur) { if (np.open) np.close(); return; }
    np.innerHTML = '';
    var top = el('div', 'np-top'); top.appendChild(el('b', '', 'Now Playing'));
    top.appendChild(btn('done', 'Done', 'Done', function () { np.close(); })); np.appendChild(top);
    var head = btn('np-ep', '<img alt=""><span class="t"><b></b><small></small></span>', 'Opens the episode', function () { np.close(); open(cur); });   // reader.js's open
    if (cur.image) head.querySelector('img').src = cur.image;
    head.querySelector('b').textContent = Headline.clean(cur.title, cur.source);
    head.querySelector('small').textContent = [cur.source, listenTime(cur)].filter(Boolean).join(' · ');
    np.appendChild(head);
    var label = el('div', 'np-label'); label.appendChild(el('span', '', 'Up Next'));
    var total = queue.reduce(function (n, x) { return n + (x.seconds || 0); }, 0);   // the queue's length, like Pocket Casts
    if (total) label.appendChild(el('span', 'np-total', length(total)));
    if (queue.length) label.appendChild(btn('clear', 'Clear', 'Clear', function () { queue = []; write('bugle.queue', []); refresh(); }));
    np.appendChild(label);
    var ul = el('ul', 'np-q');
    if (!queue.length) ul.appendChild(el('li', 'muted', 'Nothing in Up Next. Add episodes from their pages.'));
    queue.forEach(function (e, i) {
      var li = el('li'), t = el('span', 't');
      t.appendChild(el('b', '', Headline.clean(e.title, e.source))); t.appendChild(el('small', '', [e.source, listenTime(e)].filter(Boolean).join(' · ')));
      li.appendChild(t);
      if (i) li.appendChild(btn('', UP, 'Move up', function () { queue.splice(i - 1, 0, queue.splice(i, 1)[0]); write('bugle.queue', queue.map(keep)); refresh(); }));
      li.appendChild(btn('', X, 'Remove from Up Next', function () { toggleQueue(e); }));
      ul.appendChild(li);
    });
    np.appendChild(ul);
    var b = bar(cur); b.dataset.url = cur.url; np.appendChild(b);
  }
  function openPanel() { panel(); if (cur && !np.open) np.showModal(); paint(); }

  // "2 hr, 10 min" in the reader's language where the browser can say it. Same as the app's Up Next header.
  function length(sec) {
    var h = Math.floor(sec / 3600), m = Math.round(sec % 3600 / 60);
    if (window.Intl && Intl.DurationFormat) return new Intl.DurationFormat(undefined, { style: 'short' }).format(h ? { hours: h, minutes: m } : { minutes: m });
    return (h ? h + ' hr ' : '') + m + ' min';
  }

  // Your shows, Apple Podcasts' shelf: one tile per show you follow, newest first; a tap lists its episodes.
  function shows(list, ul, pick) {
    var seen = {}, row = el('li', 'shows');
    list.forEach(function (x) {
      var e = x.lead || x;   // Home's episodes are one-entry stories
      if (seen[e.source]) return; seen[e.source] = 1;
      var b = el('button', 'show'), img = el('img'); img.src = e.image || ''; img.alt = ''; img.referrerPolicy = 'no-referrer'; img.loading = 'lazy';
      b.appendChild(img); b.appendChild(el('span', '', e.source)); b.onclick = function () { pick(e.source); };
      row.appendChild(b);
    });
    if (row.children.length) ul.insertBefore(row, ul.firstChild);
  }

  // Up Next first, in order, then every other episode. Same as the app's Podcasts list.
  function upNext(list) {
    return queue.map(function (e) { return { lead: e, entries: [e], publishers: 1 }; })
      .concat(list.filter(function (st) { return !queued(st.lead); }));
  }
  // The l key: this episode if it is the one loaded, otherwise start it.
  function press(e) { if (isCur(e)) toggle(); else if (e.audio) start(e); }
  addEventListener('hashchange', mini);
  return { mount: mount, toggle: toggle, press: press, queued: queued, upNext: upNext, mini: mini, clock: clock, shows: shows };
})();
