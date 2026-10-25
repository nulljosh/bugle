# Bugle loop handoff (2026-10-25, afternoon)

## What the loop is

The Bugle loop works the gap matrix in `roadmap.md` top to bottom, then the Road to v100 bands, until the matrix has no `todo` or `partial` rows against Apple News and Ground News. The goal after that is v100. The loop prompt lives in `~/.claude/loops/bugle.md`. Bugle is one codebase in the labs monorepo: SwiftUI for iPhone, iPad, Mac and Watch, plus the web reader in `web/`.

Restart prompt:

```
/loop Bugle loop: follow ~/.claude/loops/bugle.md (gap matrix in bugle/roadmap.md) until 0 gaps vs Apple News and Ground News at A+, then on to v100
```

## Where things stand

- Git is at 3.4.0. Band 3.x so far: 3.1.0 site-address discovery (and the feed proxy now answers in sandboxed plain text), 3.2.0 nine tech and Mac feeds, 3.3.0 OPML, 3.4.0 reading time. 3.0.0 (tag `bugle-v3.0.0`): Every gap row against Apple News and Ground News from the original matrix is done: follow topics, mute, local news, offline pictures, sync of saved and history, background refresh, notifications, the Top Stories widget (2.4.0), Siri and Shortcuts (2.5.0) and Listen (3.0.0).
- The widget reads the seed feeds, not the user's list; an App Group would let it read `feeds.json`.
- The web reader is live at 3.4.0. `web/reader.js` sits near the 5000 token hook; new web features go in their own file (as `feedio.js` did).
- App Store: iOS and Mac 2.0.0 are waiting for review. The new icon and everything since 2.1 ship with the next build; never cancel the review to swap builds.
- Brand: the bugle icon, share card, footer band and `brand/BRAND.md` design system are done.

## Next, in order

1. Band 3.x, RSS power, toward 4.0: 36 unread counts (next up), 35 full text, 37 Blindspot filter, 43 story timeline.
2. Band 4.x, iPad and Mac, toward 5.0: 38 keyboard shortcuts, 39 three columns, 40 share extension, 41 Spotlight and Handoff.
3. Once 2.0.0 clears review, archive main as the next store version and submit iOS and Mac.
4. One Liquid Glass pass on one screen every tick.
5. Podcasts at 5.0 need one question to Joshua first.

## Rules that bite

- Deploy the web from the bugle root, never from web/. Deploying from web/ leaves out functions/, which emptied the live Home once.
- Commit only bugle paths. The monorepo is shared with other sessions, and tags are `bugle-vX.Y.Z` (never bare vX.Y.Z).
- Keep the Swift and JS parsers in step; the KMP parser mirrors them too.
- Never cancel a review to swap builds. Check `asc` for an open review before any upload.
- No em dashes, no emojis, plain words in the UI copy, SF in the apps and Bugle Sans on the web.
