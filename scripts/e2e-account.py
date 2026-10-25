"""Bugle account end to end, on the real web reader and the real API code (local, mail stubbed).

Device A signs up, confirms, signs in. Device B (different feeds) signs in: its list and A's merge.
A reloads and sees B's feed. A deletes the account; the old session is refused. Recorded as video.
"""
import json, os, sys, time, urllib.request
from playwright.sync_api import sync_playwright

# Run: (cd ../jaybulb-api && npx wrangler dev --local --port 8787 --var ALLOWED_ORIGIN_SUFFIX:.jaybulb.com,.localhost),
#      npx wrangler pages dev --port 8788, then uv run --with playwright python3 scripts/e2e-account.py <out-dir>
OUT = sys.argv[1]
READER = "http://localhost:8788/read"
LOCAL_API = "http://localhost:8787"
EMAIL, PASSWORD = f"qa{int(time.time())}@example.com", "correct horse battery"
CUSTOM = {"title": "Kottke", "url": "https://feeds.kottke.org/main"}
mail_link = {}
checks = []


def check(name, ok):
    checks.append((name, bool(ok)))
    print(("ok   " if ok else "FAIL ") + name, flush=True)


def to_local(route):
    """Send the page's api.jaybulb.com calls to the local API, and keep the debug mail link from signup."""
    url = route.request.url.replace("https://api.jaybulb.com", LOCAL_API)
    resp = route.fetch(url=url)
    if "/auth/signup" in url and resp.headers.get("x-debug-mail"):
        mail_link["url"] = resp.headers["x-debug-mail"]
    route.fulfill(response=resp)


def settings(page):
    page.goto(READER + "#settings")
    page.wait_for_selector("#acct-mail, #acct-email", state="attached")


with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    vid = {"record_video_dir": OUT, "record_video_size": {"width": 390, "height": 844}, "viewport": {"width": 390, "height": 844}}

    a = browser.new_context(**vid)
    a.route("https://api.jaybulb.com/**", to_local)
    pa = a.new_page()
    pa.on("dialog", lambda d: d.accept())
    settings(pa)
    pa.screenshot(path=f"{OUT}/1-signed-out.png")
    pa.fill("#acct-mail", EMAIL); pa.fill("#acct-pass", PASSWORD)
    pa.click("#acct-signup")
    pa.wait_for_selector("#acct-note:has-text('Check')")
    check("sign up asks you to confirm by email", True)
    pa.screenshot(path=f"{OUT}/2-check-email.png")

    pa.click("#acct-signin")
    pa.wait_for_selector("#acct-note:has-text('Confirm your email')")
    check("sign in before confirming is refused in plain words", True)

    link = mail_link["url"]
    link = link[link.index("http"):].split()[0]
    urllib.request.urlopen(urllib.request.Request(link.replace("https://api.jaybulb.com", LOCAL_API), headers={"Origin": "http://localhost:8788", "User-Agent": "Mozilla/5.0 bugle-qa"}))
    pa.click("#acct-signin")
    pa.wait_for_selector("#acct-in:not([hidden])")
    check("confirmed account signs in", pa.inner_text("#acct-email") == EMAIL)
    time.sleep(1.5)
    pa.screenshot(path=f"{OUT}/3-signed-in.png")
    a_feeds = pa.evaluate("feeds.map(f => f.url)")

    # device B: a different list (two seeds plus one custom feed), then sign in
    b = browser.new_context(viewport={"width": 390, "height": 844})
    b.route("https://api.jaybulb.com/**", to_local)
    b.add_init_script(f"localStorage.setItem('inkpress.feeds', JSON.stringify({json.dumps([{'title': 'Hacker News', 'url': 'https://hnrss.org/frontpage'}, CUSTOM])}))")
    pb = b.new_page()
    settings(pb)
    pb.fill("#acct-mail", EMAIL); pb.fill("#acct-pass", PASSWORD)
    pb.click("#acct-signin")
    pb.wait_for_selector("#acct-in:not([hidden])")
    time.sleep(1.5)
    b_feeds = pb.evaluate("feeds.map(f => f.url)")
    check("device B ends with the union of both lists", set(a_feeds) | {CUSTOM["url"]} <= set(b_feeds))
    pb.goto(READER + "#feeds"); pb.wait_for_selector("#following li")
    pb.screenshot(path=f"{OUT}/4-device-b-feeds.png")

    # device A picks up B's custom feed on its next load
    pa.reload(); pa.wait_for_selector("#acct-in:not([hidden])")
    got, waited = False, 0
    while not got and waited < 10:
        got = CUSTOM["url"] in pa.evaluate("feeds.map(f => f.url)"); time.sleep(.5); waited += .5
    print(f"     (synced after {waited}s)" if got else "     note: " + pa.inner_text("#acct-note"))
    check("device A gets device B's feed on reload", got)
    pa.goto(READER + "#feeds"); pa.wait_for_selector("#following li"); time.sleep(.5)
    pa.screenshot(path=f"{OUT}/5-device-a-feeds.png")

    # delete the account from device A
    session = pa.evaluate("JSON.parse(localStorage.getItem('coranto.session'))")
    settings(pa)
    pa.click("#acct-delete")
    pa.wait_for_selector("#acct-out:not([hidden])")
    check("delete signs you out and says so", "deleted" in pa.inner_text("#acct-note"))
    pa.screenshot(path=f"{OUT}/6-deleted.png")
    check("feeds stay in the browser after delete", CUSTOM["url"] in pa.evaluate("feeds.map(f => f.url)"))
    req = urllib.request.Request(f"{LOCAL_API}/auth/token?grant_type=refresh_token", data=json.dumps({"refresh_token": session["refresh"]}).encode(),
                                 headers={"Content-Type": "application/json", "Origin": "http://localhost:8788"}, method="POST")
    try:
        urllib.request.urlopen(req); refused = False
    except urllib.error.HTTPError:
        refused = True
    check("the deleted account's session is refused", refused)

    a.close(); b.close(); browser.close()

print(f"\n{sum(ok for _, ok in checks)}/{len(checks)} passed")
sys.exit(0 if all(ok for _, ok in checks) else 1)
