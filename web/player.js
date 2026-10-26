// Podcasts: the default shows, and one player for the whole reader, so an episode keeps playing while you read on. A
// mini player rides above the tab bar, Up Next plays in order when an episode ends, every episode picks up where you
// left off, and the lock screen and media keys get the controls through Media Session. Same rules as Player.swift.

// The default shows (Joshua's own list, 2026-10-25). Mirrors FeedStore.podcasts; reader.js adds them once.
var PODCASTS = [
  ['Wall Street Breakfast', 'https://www.spreaker.com/show/5725002/episodes/feed'],
  ["WSJ What's News", 'https://video-api.shdsvc.dowjones.io/api/podcasts/feed/the%20wall%20street%20journal%20whats%20news'],
  ['WSJ Tech News Briefing', 'https://video-api.shdsvc.dowjones.io/api/podcasts/feed/the%20wall%20street%20journal%20tech%20talk'],
  ['WSJ Your Money Briefing', 'https://video-api.shdsvc.dowjones.io/api/podcasts/feed/the%20wall%20street%20journals%20your%20money%20matters'],
  ['World Report', 'https://www.cbc.ca/podcasting/includes/wr.xml'],
  ['The Markets', 'https://feeds.megaphone.fm/GLD9322922848'],
  ['AI Daily: Claude News', 'https://media.rss.com/claude-ai-daily/feed.xml'],
  ['The AI Daily Brief', 'https://anchor.fm/s/f7cac464/podcast/rss'],
  ['The Philip DeFranco Show', 'https://feeds.megaphone.fm/AETTA1864906649'],
  ['Good Bad Billionaire', 'https://podcasts.files.bbci.co.uk/p0g7xj36.rss'],
  ['Deep Questions', 'https://rss.pdrl.fm/2d4b16/feeds.simplecast.com/_IjaDYAj'],
  ['My First Million', 'https://feeds.megaphone.fm/HS2300184645'],
  ['The Tim Dillon Show', 'https://audioboom.com/channels/5093219.rss'],
  ['The Mel Robbins Podcast', 'https://feeds.simplecast.com/UCwaTX1J']
].map(function (f) { return { title: f[0], url: f[1] }; });

var Player = (function () {
  var RATES = [1, 1.25, 1.5, 2], rate = 1, held = false, audio = new Audio();
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
    if (queue.length) { start(queue[0]); return; }
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
      btn('', FWD, 'Forward 30 seconds', function () { seek(audio.currentTime + 30); }), el('span', 'rate')].forEach(function (b) { ctl.appendChild(b); });
    [scrub, times, ctl].forEach(function (n) { box.appendChild(n); });
    return box;
  }
  function mount(box, e) { var b = bar(e); b.dataset.url = e.url; box.appendChild(b); paint(); }

  // Redraw what depends on what is loaded: the open story's bar, Home's Up Next order, the mini player.
  function refresh() {
    document.querySelectorAll('.episode').forEach(function (old) {
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
    });
    mini();
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
      now.onclick = function () { if (cur) open(cur); };   // reader.js's open, which shadows window.open
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

  // Up Next first, in order, then every other episode. Same as the app's Podcasts list.
  function upNext(list) {
    return queue.map(function (e) { return { lead: e, entries: [e], publishers: 1 }; })
      .concat(list.filter(function (st) { return !queued(st.lead); }));
  }
  // The l key: this episode if it is the one loaded, otherwise start it.
  function press(e) { if (isCur(e)) toggle(); else if (e.audio) start(e); }
  addEventListener('hashchange', mini);
  return { mount: mount, toggle: toggle, press: press, queued: queued, upNext: upNext, mini: mini, clock: clock };
})();
