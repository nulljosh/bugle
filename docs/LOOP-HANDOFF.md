# Bugle loop handoff (2026-10-26, 00:30)

## What the loop is

The Bugle loop works the gap matrix in `roadmap.md` top to bottom, every `todo` or `partial` row against Apple News and Ground News, then the Road to v100 bands. The goal is 0 gaps at A+, then v100. The loop prompt lives in `~/.claude/loops/bugle.md`. Bugle is one codebase in the labs monorepo: SwiftUI for iPhone, iPad, Mac and Watch, plus the web reader in `web/`.

Rules that bite: deploy the web from the bugle root, never from `web/` (that left out `functions/` and emptied the live Home once). Commit only bugle paths, because the monorepo is shared with other sessions. Tags are `bugle-vX.Y.Z`, never bare `vX.Y.Z`. Keep the Swift, JS and KMP parsers in step. Never cancel a review to swap builds, and check `asc` for an open review before any upload. UI copy stays in plain words, SF in the apps and Bugle Sans on the web, no em dashes, no emojis.

## Where things stand

- Repo is at 7.14.0 (tag `bugle-v7.14.0`). Tonight's run went from 7.9.0 to 7.14.0.
- 7.9: the episode cover is a hero across the top third, blurred under the glass bar, with scroll parallax. Hacker News stories open in the reader with the whole comment thread. Pages with no article body show their own summary. Swipe left to save, in green. Washed-out covers no longer tint the player.
- 7.10: Home is redone as Apple would build it: a large title with the date, a round glass Briefing button, and search as its own tab that opens a glass field at the bottom. The web matches.
- 7.11 to 7.14: Popular Left, Popular Right and Both Sides collections (rows 48 to 51 are done, along with the shelf of followed podcasts and Up Next total time, unread dots with an Unread chip, and the Compact layout in Settings). All in 19 languages.
- Gap matrix: rows 52 and 53 are the only `todo` rows left.
- Store: iOS 2.0.0 is live, iOS 6.1.0 is waiting for review, Mac 2.0.0 is in review. The screenshots in `ios/.asc/screenshots` predate the 7.10 Home redesign and need a retake before the next submit.

## Next, in order

0. Retake the store screenshots so they show the new Home (large title, search tab), the cover hero, the Podcasts shelf and the Compact layout.
1. Store, on Joshua's yes: when iOS 6.1.0 clears, create iOS 7.0.0, upload the new screenshots to the APP_IPHONE_65 and APP_IPAD_PRO_3GEN_129 sets on en-US, archive, upload and submit. When Mac 2.0.0 clears, archive and submit Mac 7.0.0.
2. Row 52: first-run topic picker (M, after Yahoo News and SmartNews).
3. Row 53: key takeaways and where sources agree or differ, written on device with Apple Foundation Models and no cloud (L, the 8.0.0 major).
4. Then the rest of the Road to v100 bands. Writing and subscribers (bands 10 to 29) and Android (30 to 49) stay gated on Joshua.

## Restart prompt

```
/loop Bugle loop: follow ~/.claude/loops/bugle.md (gap matrix in bugle/roadmap.md) until 0 gaps vs Apple News and Ground News at A+, then on to v100
```
