# Bugle loop handoff (2026-10-26, 01:45)

## What the loop is

The Bugle loop works the gap matrix in `roadmap.md` top to bottom, every `todo` or `partial` row against Apple News and Ground News, then the Road to v100 bands. The goal is 0 gaps at A+, then v100. The loop prompt lives in `~/.claude/loops/bugle.md`. Joshua stopped the loop at 01:45 to wrap up; it is not running now. Restart it with the prompt below when he asks. Bugle is one codebase in the labs monorepo: SwiftUI for iPhone, iPad, Mac and Watch, plus the web reader in `web/`.

Rules that bite: deploy the web from the bugle root, never from `web/` (that left out `functions/` and emptied the live Home once). Commit only bugle paths, because the monorepo is shared with other sessions. Tags are `bugle-vX.Y.Z`, never bare `vX.Y.Z`. Keep the Swift, JS and KMP parsers in step. Never cancel a review to swap builds, and check `asc` for an open review before any upload. UI copy stays in plain words, SF in the apps and on the web, no em dashes, no emojis.

## Where things stand

- Repo is at 7.18.1 (tag `bugle-v7.18.1`). The 7.14 to 7.18 run added:
- 7.15: the mascot (the horn with a round smiling face), a boot splash where it pops up, blinks and toots, and a first-run topic picker, also shown after a new account's first sign-in. Lead pictures come in full size.
- 7.16: the mascot is the app icon (white on the blue tile; Icon Composer bundle, iOS, Mac and Watch sets, favicons, share card). The web uses the system font. `brand/BRAND.md` documents the mascot.
- 7.17 and 7.17.1: the splash plays whole and crossfades into a complete Home; launch work moved off the main thread; refresh returns grouped stories to every caller; the mascot sits on loading and empty lists; twice-escaped headline entities decode.
- 7.18 and 7.18.1: the mascot leans back into its toot with three waves that ripple out; the mascot is on the iOS launch screen itself, so a first launch shows it from the first frame. Joshua graded the mascot and its animation A+.
- Gap matrix: rows 48 to 52 are done. Row 53 (on-device key takeaways, the 8.0.0 major) is the only `todo` row left.
- Store: iOS 6.1.0 is approved and live. iOS 7.17.1 was uploaded and is WAITING_FOR_REVIEW. Mac 2.0.0 is still in review. The store screenshots in `ios/.asc/screenshots` predate the 7.10 Home redesign and need a retake.

## Next, in order

0. Retake the store screenshots so they show the new Home, the mascot and the first-run picker.
1. Store, on Joshua's yes: submit 7.18.x once iOS 7.17.1 clears, and submit Mac 7.x once Mac 2.0.0 clears. Never cancel a review.
2. Row 53: key takeaways and where sources agree or differ, written on device with Apple Foundation Models and no cloud (L, the 8.0.0 major).
3. Then the rest of the Road to v100 bands. Writing and subscribers (bands 10 to 29) and Android (30 to 49) stay gated on Joshua.

## Restart prompt

```
/loop Bugle loop: follow ~/.claude/loops/bugle.md (gap matrix in bugle/roadmap.md) until 0 gaps vs Apple News and Ground News at A+, then on to v100
```
