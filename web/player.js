// Podcasts: the default shows, and an episode's own audio, played from its story, picking up where you left off. The scrubber with elapsed
// and left, then speed, back 15, play, forward 30, like Apple Podcasts; the lock screen and media keys get the same
// through Media Session. Same rules as Player.swift. Leaving the story pauses it.

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
  var KEY = 'bugle.positions', RATES = [1, 1.25, 1.5, 2], audio = null, playing = null, rate = 1;
  var positions = function () { try { return JSON.parse(localStorage.getItem(KEY)) || {}; } catch (e) { return {}; } };
  // Seconds into each episode, by its url. Nearly done counts as done.
  function remember(e, a) {
    if (!a.readyState) return;   // not loaded yet: its time reads 0, which would forget where you were
    var p = positions(), t = a.currentTime, d = a.duration || e.seconds || 0;
    if (t > 5 && (!d || t < d - 30)) p[e.url] = Math.floor(t); else delete p[e.url];
    try { localStorage.setItem(KEY, JSON.stringify(p)); } catch (x) {}
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

  function mount(box, e) {
    stop();
    audio = new Audio();
    audio.preload = 'metadata';
    audio.src = e.audio;
    playing = e;
    var bar = el('div', 'episode'), scrub = el('input', 'scrub'), times = el('div', 'times');
    var at = el('span', '', '0:00'), left = el('span', '', e.seconds ? '-' + clock(e.seconds) : '');
    scrub.type = 'range'; scrub.min = 0; scrub.step = 1; scrub.max = e.seconds || 1; scrub.value = 0;
    scrub.setAttribute('aria-label', 'Position');
    times.appendChild(at); times.appendChild(left);
    var ctl = el('div', 'ctl'), speed = el('button', 'rate', rate + '×'), back = el('button'), play = el('button', 'play'), fwd = el('button');
    back.innerHTML = BACK; back.setAttribute('aria-label', 'Back 15 seconds');
    fwd.innerHTML = FWD; fwd.setAttribute('aria-label', 'Forward 30 seconds');
    speed.setAttribute('aria-label', 'Speed');
    [speed, back, play, fwd, el('span', 'rate')].forEach(function (b) { ctl.appendChild(b); });
    [scrub, times, ctl].forEach(function (n) { bar.appendChild(n); });
    box.appendChild(bar);

    var a = audio, held = false;
    var paint = function () {
      var d = a.duration || e.seconds || 0;
      if (!held) scrub.value = a.currentTime;
      scrub.max = d || 1;
      at.textContent = clock(a.currentTime);
      left.textContent = d ? '-' + clock(d - a.currentTime) : '';
      play.innerHTML = a.paused ? PLAY : PAUSE;
      play.setAttribute('aria-label', a.paused ? 'Play' : 'Pause');
    };
    var seek = function (t) { a.currentTime = Math.max(0, Math.min(t, a.duration || t)); paint(); remember(e, a); };
    var start = positions()[e.url];
    a.addEventListener('loadedmetadata', function () { if (start) a.currentTime = start; paint(); });
    a.addEventListener('timeupdate', function () { paint(); if (Math.floor(a.currentTime) % 5 === 0) remember(e, a); });
    a.addEventListener('play', paint);
    a.addEventListener('pause', function () { paint(); if (a.src) remember(e, a); });
    a.addEventListener('ended', function () { a.currentTime = 0; remember(e, a); paint(); });
    scrub.oninput = function () { held = true; at.textContent = clock(+scrub.value); };
    scrub.onchange = function () { held = false; seek(+scrub.value); };
    play.onclick = function () {
      if (!a.paused) { a.pause(); return; }
      a.playbackRate = rate;
      a.play().catch(function () {});
      session(e);
    };
    back.onclick = function () { seek(a.currentTime - 15); };
    fwd.onclick = function () { seek(a.currentTime + 30); };
    speed.onclick = function () {   // 1x, 1.25x, 1.5x, 2x, then back to 1x
      rate = RATES[(RATES.indexOf(rate) + 1) % RATES.length];
      a.playbackRate = rate;
      speed.textContent = rate + '×';
    };
    if (start) { at.textContent = clock(start); scrub.value = start; }
    paint();
  }

  // The lock screen, Control Center and media keys.
  function session(e) {
    var ms = navigator.mediaSession;
    if (!ms) return;
    ms.metadata = new MediaMetadata({ title: Headline.clean(e.title, e.source), artist: e.source, artwork: e.image ? [{ src: e.image }] : [] });
    var a = audio, by = function (s) { return function () { a.currentTime = Math.max(0, a.currentTime + s); }; };
    ms.setActionHandler('play', function () { a.play(); });
    ms.setActionHandler('pause', function () { a.pause(); });
    ms.setActionHandler('seekbackward', by(-15));
    ms.setActionHandler('seekforward', by(30));
    try { ms.setActionHandler('seekto', function (d) { a.currentTime = d.seekTime; }); } catch (x) {}
  }

  function toggle() { var b = document.querySelector('.episode .play'); if (b) b.click(); }
  function stop() {
    if (!audio) return;
    remember(playing, audio);
    audio.pause(); audio.removeAttribute('src'); audio.load(); audio = playing = null;
  }
  return { mount: mount, stop: stop, toggle: toggle, clock: clock };
})();
