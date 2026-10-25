// Optional Bugle account on jaybulb-api, the fleet's shared auth. One job: your followed feeds follow you to every
// device and the app. Mirrors ios/Sources/Shared/Services/Account.swift. The session (refresh token) is kept in
// localStorage on this browser only. Needs reader.js loaded first (feeds, save, renderFeeds, refresh).
(function () {
  var API = 'https://api.jaybulb.com', BACK = 'https://bugle.jaybulb.com/', KEY = 'coranto.session';
  var session = null, access = null;
  try { session = JSON.parse(localStorage.getItem(KEY)); } catch (e) {}
  var $ = function (id) { return document.getElementById(id); };

  var PLAIN = { 'Invalid login credentials': "That email and password don't match.",
    'Email not confirmed': 'Confirm your email first: the link is in your inbox.', 'slow down': 'Too many tries. Wait a minute and try again.' };
  async function call(method, path, body, token, headers) {
    var h = Object.assign({ 'Content-Type': 'application/json' }, headers || {});
    if (token) h.Authorization = 'Bearer ' + token;
    var r = await fetch(API + path, { method: method, headers: h, body: body ? JSON.stringify(body) : undefined });
    var json = await r.json().catch(function () { return {}; });
    if (!r.ok) { var err = new Error(PLAIN[json.error] || json.error || 'Something went wrong (' + r.status + ').'); err.status = r.status; throw err; }
    return json;
  }
  function keep(s) {
    access = s.access_token;
    session = { id: s.user.id, email: s.user.email, refresh: s.refresh_token };
    try { localStorage.setItem(KEY, JSON.stringify(session)); } catch (e) {}
  }
  function forget() { session = null; access = null; try { localStorage.removeItem(KEY); } catch (e) {} }
  async function authed(method, path, body, headers) {
    if (!access) await renew();
    try { return await call(method, path, body, access, headers); }
    catch (e) { if (e.status !== 401) throw e; await renew(); return call(method, path, body, access, headers); }
  }
  async function renew() {
    if (!session) throw new Error('Please sign in again.');
    try { keep(await call('POST', '/auth/token?grant_type=refresh_token', { refresh_token: session.refresh })); }
    catch (e) { forget(); render(); throw new Error('Please sign in again.'); }
  }

  // Union by URL, saved to both sides; a sync never drops a feed.
  // Union of this browser's feeds, saved stories, history, topics and mutes with the account's, saved to both.
  // Nothing is ever dropped. Mirrors Account.sync in the app.
  async function sync() {
    var row = (await authed('GET', '/rest/coranto_sync'))[0] || {};
    (row.feeds || []).forEach(function (f) {
      if (f && f.url && !feeds.some(function (x) { return x.url === f.url; })) feeds.push({ title: f.title, url: f.url });
    });
    var entry = function (d) { return { title: d.title, url: d.url, date: new Date(d.date || 0), source: d.source || '', image: d.image || '', html: '' }; };
    Library.merge((row.saved || []).map(entry), (row.history || []).map(entry));
    (row.topics || []).forEach(function (w) { if (!Topics.has(w)) Topics.toggle(w); });
    (row.muted || []).forEach(function (w) { if (!Muted.has(w)) Muted.toggle(w); });
    save(); renderFeeds(); renderLibrary(); renderMuted(); refresh();
    await push();
  }
  // headline, link, outlet, picture: the body stays in the browser it was read in
  var light = function (e) { return { title: e.title, url: e.url, date: e.date, source: e.source, image: e.image || '' }; };
  async function push() {
    if (!session) return;
    var up = function (b) { return authed('POST', '/rest/coranto_sync?on_conflict=id', b, { Prefer: 'resolution=merge-duplicates' }); };
    try {
      await up({ id: session.id, feeds: feeds, saved: Library.saved().slice(0, 200).map(light),
        history: Library.history().slice(0, 100).map(light), topics: Topics.list(), muted: Muted.list() });
    } catch (e) {   // ponytail: a server without the newer columns refuses them; the feed list still syncs
      if (e.status !== 400) throw e;
      await up({ id: session.id, feeds: feeds });
    }
  }
  window.BugleAccount = { push: function () { push().catch(function () {}); } };

  function say(text) { $('acct-note').textContent = text || 'Optional. Your feeds, saved stories, topics and mutes follow you to every device and the app. Reading never needs an account.'; }
  function render() {
    $('acct-out').hidden = !!session; $('acct-in').hidden = !session;
    if (session) $('acct-email').textContent = session.email;
  }
  async function act(work) {
    var btns = document.querySelectorAll('#settings .acct button');
    btns.forEach(function (b) { b.disabled = true; });
    try { await work(); } catch (e) { say(e.message || 'Could not reach the server. Try again.'); }
    btns.forEach(function (b) { b.disabled = false; });
    render();
  }
  var creds = function () { return { email: $('acct-mail').value.trim(), password: $('acct-pass').value }; };

  $('acct-signin').onclick = function () { act(async function () { keep(await call('POST', '/auth/token?grant_type=password', creds())); say(); await sync(); }); };
  $('acct-signup').onclick = function () { act(async function () {
    var c = creds(); if (c.password.length < 8) throw new Error('Use 8 or more characters for the password.');
    await call('POST', '/auth/signup', Object.assign(c, { redirect_to: BACK })); say('Check ' + c.email + ' for a link to confirm your account, then sign in.'); }); };
  $('acct-forgot').onclick = function () { act(async function () {
    await call('POST', '/auth/recover', { email: creds().email, redirect_to: BACK }); say('If ' + creds().email + ' has an account, a reset link is on its way.'); }); };
  $('acct-signout').onclick = function () { act(async function () { await authed('POST', '/auth/logout').catch(function () {}); forget(); say(); }); };
  $('acct-delete').onclick = function () {
    if (!confirm('Delete your Bugle account and the feeds synced to it? Feeds in this browser stay.')) return;
    act(async function () { await authed('DELETE', '/auth/user'); forget(); say('Your account and its synced feeds are deleted.'); });
  };
  say(); render();
  if (session) sync().catch(function () {});
})();
