# Bugle loop handoff (2026-10-25, late)

## What the loop is

The Bugle loop works the gap matrix in `roadmap.md` top to bottom, then the Road to v100 bands, until the matrix has no `todo` or `partial` rows against Apple News and Ground News. The goal after that is v100. The loop prompt lives in `~/.claude/loops/bugle.md`. Bugle is one codebase in the labs monorepo: SwiftUI for iPhone, iPad, Mac and Watch, plus the web reader in `web/`.

Restart prompt:

```
/loop Bugle loop: follow ~/.claude/loops/bugle.md (gap matrix in bugle/roadmap.md) until 0 gaps vs Apple News and Ground News at A+, then on to v100
```

## Where things stand

- Git is at 1.17.1. Gap rows 16 (Today ranks the day's biggest stories by newsroom coverage) is done, and the 1.16.1 to 1.17.1 changes sit on top of it.
- 1.16.1: list titles get two lines (one line cut headlines to about three words on a phone), and a stray comma before a closing quote is gone.
- 1.17.0: every outlet shows in its own brand color (HN orange, BBC red, and so on). When only one outlet is on screen (one feed followed, a search for it, or a tap on it in Feeds), the whole app takes its color. Every color passes a contrast check in light and dark. The hero picture is capped at 360 points on wide Macs.
- 1.17.1: feeds you add yourself get a steady color picked from their name, and outlet names in the Feeds list show their colors.
- Web: the share card says Bugle (og.png redrawn; the og:image URL is og.png?v=2 so iMessage refetches). The landing headline reads "Every feed, one timeline." Reader asset links carry a version number so a deploy never pairs new JS with an old cached stylesheet.
- The rename from Coranto to Bugle is finished in code, the site and the store name. The store name is BugleNews because Apple refused plain Bugle. The Pages project, the bundle id and inkpress.jaybulb.com keep their old names on purpose.
- Nothing is in App Review. Both 1.0.8 submissions were pulled for the rename. The live store listing still says Inkpress until the next version ships, and the next store build carries everything above.
- Accounts run on api.jaybulb.com (table `coranto_sync`, one row of followed feeds per account). They sync the feed list only. Saved and History are not synced yet.
- Research done: a Mobbin study of about 18 news apps (roadmap section "Mobbin study") and live QA of the web reader with screenshots. CBC is blocked on the web proxy only; the app and the browser user agent work.
- Road to v100: bands 1.x and 2.x are done except gap row 9 (offline images, partial). Band 3.x has rows 17 to 19 open. Band 4.x (rows 21 to 27) is open. Podcasts, writing, subscribers, Android and ads are gated on Joshua's decision and are not started.

## Next, in order

1. Mascot. Design it with the icon rules (bold flat glyph, one accent, no text in the icon), then wire it into the empty states and the landing.
2. Bring the landing look into the apps: the same type, colour and spacing as `web/index.html`.
3. Resubmit to the App Store with the App Privacy update (email and feed list, linked to the user, app functionality, no tracking, because accounts shipped in 1.9.0) and iPad 13 screenshots. Set whatsNew, archive main as the new version, submit iOS and Mac. Submissions wait for Joshua's yes.
4. Gap rows 17 and up, in order: 17 follow topics (next up), 18 mute a source or topic (partial), 19 local news (partial), 21 background refresh, 22 notifications for chosen sources, 23 Home Screen widgets, 25 Siri and Shortcuts, 26 listen to a story, 27 Watch parity (partial), 9 offline images (partial), 24 sync of saved and history (partial).
5. When the matrix has no `todo` or `partial` rows left, run the full QA list in `roadmap.md` and send Joshua the screenshots before calling 5.0.

## Rules that bite

- Deploy the web from the bugle root, never from web/. Deploying from web/ leaves out functions/, which emptied the live Home once.
- Commit only bugle paths. The monorepo is shared with other sessions, and tags are `bugle-vX.Y.Z` (never bare vX.Y.Z).
- Keep the Swift and JS parsers in step; the KMP parser mirrors them too.
- Never cancel a review to swap builds. Check `asc` for an open review before any upload.
- No em dashes, no emojis, plain words in the UI copy, SF in the apps and Bugle Sans on the web.
