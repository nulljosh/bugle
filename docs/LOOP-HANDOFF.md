# Bugle loop handoff (2026-10-25, evening)

## What the loop is

The Bugle loop works the gap matrix in `roadmap.md` top to bottom, then the Road to v100 bands, until the matrix has no `todo` or `partial` rows against Apple News and Ground News. The goal after that is v100. The loop prompt lives in `~/.claude/loops/bugle.md`. Bugle is one codebase in the labs monorepo: SwiftUI for iPhone, iPad, Mac and Watch, plus the web reader in `web/`.

Restart prompt:

```
/loop Bugle loop: follow ~/.claude/loops/bugle.md (gap matrix in bugle/roadmap.md) until 0 gaps vs Apple News and Ground News at A+, then on to v100
```

## Where things stand

- Git is at 7.4.0: Translate (system sheet) and up and down story arrows (`StoryStepper`), rows 44 and 45 of the competitor matrix. 7.3.0: Liquid Glass passes 1 and 2 (the player card `floatingGlass()`, search and chips `capsuleGlass()`), dark accent #0A84FF. 7.1.0: Nineteen languages in `ios/Sources/Shared/Localizable.xcstrings` (146 strings; new UI strings go in by hand, `xcodebuild -exportLocalizations` does not extract them; then `python3 scripts/gen_i18n.py` writes `web/i18n.js`, which also matches keys with `%lld`/`%@` as patterns). Arabic and Hebrew are right to left; the player stays left to right.
- Podcasts (band 6 to 9) closed at 7.0.0: `FeedStore.podcasts` (web `seeds.js`), `Player.shared`, `Downloads`, `NowPlayingView`, sleep timer, mini player (iOS 26.1 tab bar accessory). QA hooks never play sound: `-cueEpisode`, `-nowPlaying` load paused.
- Home fills in as feeds arrive (6.1.1), and a feed gives up after 15 s of silence. Store screenshots showing podcasts are in `ios/.asc/screenshots` (iPhone 1284x2778, iPad 2064x2752; the Mac set is old).
- 3.0.0 closed every gap against Apple News and Ground News from the original matrix (widget 2.4.0, Siri 2.5.0, Listen 3.0.0 and everything before).
- The widget reads the seed feeds, not the user's list; an App Group would let it read `feeds.json`.
- The web reader is live at the same version. `web/reader.js` sits near the 5000 token hook; new web features go in their own file (`feedio.js`, `fulltext.js`, `timeline.js`, `player.js`, `seeds.js`).
- App Store: iOS 2.0.0 is live, iOS 6.1.0 waiting for review, Mac 2.0.0 in review. Never cancel a review to swap builds.

## Next, in order

1. Store: iOS 6.1.0 is waiting for review and Mac 2.0.0 is in review. When iOS 6.1.0 clears, create iOS 7.0.0, upload the new screenshots (replace the APP_IPHONE_65 and APP_IPAD_PRO_3GEN_129 sets on its en-US localization), archive, upload and submit. When Mac 2.0.0 clears, archive and submit Mac 7.0.0. Never cancel a review.
2. Road to 8.0.0 (semver: minor per feature, major per band). Ungated band 50 to 99 first: more languages (Hindi, Russian, Turkish, Polish, Swedish, Indonesian, Vietnamese, Hebrew), then one Liquid Glass pass per screen (done: the player card, search and chips; next: the competitor-screens matrix, rows 46 to 53, from the `mobbin` skill). Writing and subscribers (10 to 29) and Android (30 to 49) stay gated on Joshua.

## Rules that bite

- Deploy the web from the bugle root, never from web/. Deploying from web/ leaves out functions/, which emptied the live Home once.
- Commit only bugle paths. The monorepo is shared with other sessions, and tags are `bugle-vX.Y.Z` (never bare vX.Y.Z).
- Keep the Swift and JS parsers in step; the KMP parser mirrors them too.
- Never cancel a review to swap builds. Check `asc` for an open review before any upload.
- No em dashes, no emojis, plain words in the UI copy, SF in the apps and Bugle Sans on the web.
