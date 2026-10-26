# Bugle
iOS 2.0.0 live, iOS 6.1.0 waiting for review, Mac 2.0.0 in review. Repo at 7.1.0: 0 gaps vs Apple News, Ground News and RSS readers; bands 1 to 5 done. Podcasts (band 6 to 9) started with 6.0.0: default shows in `FeedStore.podcasts` (web `PODCASTS` in `player.js`), `Player.swift`, the Podcasts chip. Web reader live at bugle.jaybulb.com/read.

## Open
- Looping to 0 gaps vs Apple News and Ground News, then v100: gap matrix in `roadmap.md`, loop prompt `~/.claude/loops/bugle.md`. Tags are `bugle-vX.Y.Z` (the monorepo shares tags).

## The loop
Restart handoff, with the restart prompt, is `docs/LOOP-HANDOFF.md`. Gap matrix in `roadmap.md`.

## Ship gotchas (learned 2026-08-09)
- The App Store icon must be a **fully opaque square**, `AppIcon.appiconset/icon-1024.png` shipped with transparent rounded corners once and the upload failed with **90717**. iOS applies the corner mask itself. Flatten with `magick icon.png -background '#161412' -alpha remove -alpha off -type TrueColor PNG24:icon.png`.
- `ITSAppUsesNonExemptEncryption=false` now lives in `Sources/iOS/Info.plist`; without it every upload needs a manual `asc builds update --uses-non-exempt-encryption=false`.
- The 1284x2778 screenshot is `APP_IPHONE_65`, not `IPHONE_67`, `asc screenshots upload` rejects the wrong display type.
- `asc review submit` can falsely report the prepared submission "does not contain target version". Fall back to `asc review submissions-submit --id <submission-id> --confirm`.
- macOS: scheme `Bugle-macOS`; `asc xcode export` is iOS-only, so archive/export with raw xcodebuild + `ExportOptions-macOS.plist`, upload with `asc builds upload --pkg --version --build-number`.
- The xcodegen scheme is `Journal-iOS` (not `Bugle`), the bundle id `com.nulljosh.journal` and project name are Apple-locked from the pre-rename days.

## Rules
- Multi-feed RSS/Atom reader: iOS, macOS (`Bugle-macOS`, same bundle id, Universal Purchase) and a browser reader in `web/read.html`. Split from the `journal` repo 2026-07-21, that repo now holds only the Jekyll blog. No shared code between the two; `FeedStore.seedFeeds` in `ios/Sources/Shared/Models/Feed.swift` subscribes to the blog's `feed.xml` on first launch as one regular feed among the curated news seeds, same as anything a user adds themselves.
- Renamed "Journal" to "Inkpress" 2026-07-06 (Apple's own Journal app), then "Inkpress" to "Coranto" 2026-10-25, then "Coranto" to "Bugle" the same day (Joshua: Coranto took explaining). On the App Store the name is "Bugle News": Apple refused "Bugle" and "Bugler" as taken by other accounts, so the store name carries "News" and everything else (home screen, site, folder) is Bugle. ASC app id 6787759999, lives in the labs monorepo at `bugle/`. Bugle is set on the app info; the live listing says Inkpress until the next version ships.
- Still on old names on purpose: bundle id `com.nulljosh.journal`, `journal.xcodeproj` and scheme `Journal-iOS`, Pages project `inkpress` (inkpress.jaybulb.com keeps serving, the live listing links there), localStorage keys `inkpress.feeds` and `coranto.session`, `coranto.textSize`, `coranto.library`, `coranto.previews`, the jaybulb-api table `coranto_sync`, the Keychain item `com.nulljosh.coranto.account`, git tags `coranto-v1.5.0` to `coranto-v1.14.0` (new tags are `bugle-vX.Y.Z`), coranto.jaybulb.com (still serves), Supabase tables `inkpress_posts`/`inkpress_contacts`, KMP package and applicationId `com.nulljosh.inkpress`.
- Brand: clrs.cc blue, accent `#0059B3` (gradient top `#0074D9`), glyph is a bugle (mouthpiece, one coil, wide bell; 2026-10-25, the three-feeds mark read like a plane), `Bugle.icon`. Design system in `brand/BRAND.md`. Web type is Bugle Sans and Bugle Display (renamed OFL Inter and Inter Tight, `scripts/gen_font.py`), lowercase, no forced caps; the apps use SF.
- **Superseded 2026-08-02**: the "no accounts, no writing feature" rule below is being phased out, Bugle is pivoting to also be a CMS/CRM client (WordPress/Ghost-inspired), staying an RSS reader too. See CMS/CRM Pivot roadmap in `roadmap.md`. Old rule, now historical: no accounts, no journaling/writing feature, no user-authored content, it only reads feeds.
- Build via xcodegen (`project.yml`), no checked-in `.xcodeproj` diffs expected beyond what xcodegen regenerates.
- No emojis, no monospace UI chrome (see house style).

## Backend (CMS/CRM pivot, Phase 0 decided 2026-08-02)
- Supabase, reusing the shared `spark` project (`tjsxsqlxjmanwvmywwvw`) per house convention (free tier capped at 2 projects), not git-commit-to-Jekyll, because Phase 3 (subscriber contacts) needs real queryable tables.
- Tables: `inkpress_posts` (title, body_html, status draft/published, timestamps), `inkpress_contacts` (email unique, name, source, created_at). Both RLS-enabled with no policies yet, service-role-only writes until Phase 2 adds authenticated single-user write (Supabase Swift SDK pattern, same as litigate/epiphany).
- No Swift code or UI against these tables yet, that's Phase 2+.

## Run
```bash
cd ios
xcodegen generate
xcodebuild -project journal.xcodeproj -scheme Journal-iOS -destination 'generic/platform=iOS Simulator' build
```

## Key Files
- `ios/Sources/Shared/Models/Feed.swift`: `Feed`, `FeedStore` (persisted subscriptions, `seedFeeds` first-launch list)
- `ios/Sources/Shared/Views/ManageFeedsView.swift`: add/remove feeds UI
- `ios/Sources/Shared/Services/JournalFeedService.swift`: feed fetch/parse (RSS + Atom)
- `ios/Sources/Shared/Views/EntryDetailView.swift`: entry render, wraps HTML content in a forced `<style>` block since `NSAttributedString`'s HTML importer has no default CSS

## Related
[[journal]], the Jekyll blog this repo used to share a folder with. Bugle subscribes to journal.heyitsmejosh.com/feed.xml by default.
