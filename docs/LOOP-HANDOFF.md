# Bugle loop handoff (2026-10-25, late afternoon)

## What the loop is

The Bugle loop works the gap matrix in `roadmap.md` top to bottom, then the Road to v100 bands, until the matrix has no `todo` or `partial` rows against Apple News and Ground News. The goal after that is v100. The loop prompt lives in `~/.claude/loops/bugle.md`. Bugle is one codebase in the labs monorepo: SwiftUI for iPhone, iPad, Mac and Watch, plus the web reader in `web/`.

Restart prompt:

```
/loop Bugle loop: follow ~/.claude/loops/bugle.md (gap matrix in bugle/roadmap.md) until 0 gaps vs Apple News and Ground News at A+, then on to v100
```

## Where things stand

- Git is at 5.0.0 (QA'd: tests, builds, iPhone and iPad light and dark, web at 390 and desktop, the landing; the Mac capture was skipped because an unsigned capture build would prompt for the account keychain item). 4.4.0: the share extension (`Sources/Share`, bundle id `com.nulljosh.journal.share`, registered with Apple along with `.widget`), handing items over through a shared keychain group (`Inbox`). Band 4.x is done. 4.3.0: Spotlight and Handoff (`Spotlight.swift`). 4.2.0: three columns on iPad and Mac (`HomeSplit`; the outlet list sets the same search Home uses, and the story column has its own path). 4.1.0: keyboard shortcuts (web `keys.js`; apps use invisible buttons with `.keyboardShortcut`). 4.0.1: grouping matches each headline against the story's lead only and ignores the day's common words (`Coverage.common`). 4.0.0 (tag `bugle-v4.0.0`): Band 3.x, RSS power, is done: site-address discovery, tech and Mac feeds, OPML, reading time, unread counts and Mark All Read, full article text for summary-only feeds, the Blindspots chip, and the story timeline (a week of headlines in `Archive`, shown under Earlier).
- 3.0.0 closed every gap against Apple News and Ground News from the original matrix (widget 2.4.0, Siri 2.5.0, Listen 3.0.0 and everything before).
- The widget reads the seed feeds, not the user's list; an App Group would let it read `feeds.json`.
- The web reader is live at 4.0.0. `web/reader.js` sits near the 5000 token hook; new web features go in their own file (`feedio.js`, `fulltext.js`, `timeline.js`).
- App Store: iOS and Mac 2.0.0 are waiting for review. Everything since 2.1 ships with the next build; never cancel the review to swap builds.

## Next, in order

1. Ask Joshua the one podcasts question (band 5 to 9). Until he answers, work band 50 to 99 items that need no gate: VoiceOver labels, Dynamic Type, Reduce Motion.
2. Once 2.0.0 clears review, archive main as the next store version and submit iOS and Mac.
3. One Liquid Glass pass on one screen every tick.

## Rules that bite

- Deploy the web from the bugle root, never from web/. Deploying from web/ leaves out functions/, which emptied the live Home once.
- Commit only bugle paths. The monorepo is shared with other sessions, and tags are `bugle-vX.Y.Z` (never bare vX.Y.Z).
- Keep the Swift and JS parsers in step; the KMP parser mirrors them too.
- Never cancel a review to swap builds. Check `asc` for an open review before any upload.
- No em dashes, no emojis, plain words in the UI copy, SF in the apps and Bugle Sans on the web.
