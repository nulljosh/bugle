# Architecture

Bugle is a multi-feed RSS reader. Subscribe to any RSS/Atom feed, browse entries chronologically. Deployed as an iOS/macOS native app (shared codebase) and a web reader. Seeds 16 curated news feeds on first launch; users can add their own. Early CMS/CRM pivot in planning (Phase 0 decided 2026-08-02; backend infra in place, no UI yet).

## How it runs

iOS/macOS app: `ios/Sources/Shared/Models/Feed.swift` holds subscribed feeds (persisted to UserDefaults). `JournalFeedService.swift` fetches and parses RSS/Atom (tries multiple date field names: RFC822 zones by name, ISO timestamps). `ManageFeedsView.swift` lets users add/remove feeds. `EntryDetailView.swift` renders entries by wrapping HTML content with injected `<style>` (NSAttributedString's HTML importer has no default CSS). On first launch, `FeedStore.seedFeeds` subscribes to 16 curated news sources plus the Jekyll blog at `journal.heyitsmejosh.com/feed.xml` (which is the blog's RSS export, same as any user-added feed).

Web reader: `web/read.html` (no build step, plain HTML/JS). Fetches feeds via CORS proxy, renders a feed list and entry detail view.

Backend (CMS/CRM pivot): Supabase tables (`inkpress_posts`, `inkpress_contacts`) exist on the shared `spark` project with RLS enabled but no policies yet. No Swift code or UI against these tables yet (Phase 2+).

## Files

| File | What it owns |
|---|---|
| `ios/Sources/Shared/Models/Feed.swift` | Feed struct, FeedStore (persisted subscriptions, seedFeeds list for first launch) |
| `ios/Sources/Shared/Services/JournalFeedService.swift` | RSS/Atom parsing: tries multiple date field names, handles RFC822 zones by name and ISO timestamps |
| `ios/Sources/Shared/Views/ManageFeedsView.swift` | Add/remove feed UI, feed list management |
| `ios/Sources/Shared/Views/FeedListView.swift` | Feed entries: chronological reverse order, sort by date |
| `ios/Sources/Shared/Views/EntryDetailView.swift` | Entry rendering: wraps HTML with injected `<style>` tag (NSAttributedString workaround) |
| `ios/Sources/iOS/VoxprintApp.swift` | iOS app entry (mistaken copy, should be removed) |
| `ios/Sources/macOS/ContentView.swift` | macOS app entry and main window |
| `ios/project.yml` | XcodeGen: scheme `Journal-iOS`, bundle `com.nulljosh.journal` (frozen from pre-rename days) |
| `web/read.html` | Static HTML web reader: feed list, entry detail, CORS proxy fetch, no build step |
| `web/style.css` | Web reader styling |
| `web/read.js` | Web reader logic: fetch feeds, parse, render |
| `functions/feed.js` | Cloudflare Worker CORS proxy: accepts feed URLs, validates (https-only, blocks private hosts), fetches with 5MB cap, caches for 5min, only readable from bugle origin |
| `test.mjs` | Unit tests for feed proxy: validates security guards (https-only, loopback blocking, wildcard-CORS rejection, size cap) |
| `watchos/BugleWatchApp.swift` | watchOS app entry point with window group |
| `watchos/ContentView.swift` | watchOS feed reader: compact feed list, limited entry detail view |
| `watchos/Models/Feed.swift` | Feed model for watchOS (mirrors iOS model) |
| `watchos/Services/FeedService.swift` | watchOS feed fetching service, uses same CORS proxy as web reader |
| `Package.swift` + `tui/main.swift` | SwiftPM target for CLI reader: accepts feed URL, parses RSS/Atom via XMLParser, renders titles in terminal (static render, single invocation) |
| `scripts/capture-mac-shots.sh` | Fastlane integration: captures App Store screenshots on macOS via UI automation |
| `scripts/check-links.py` | Link validation: scans all HTML files in `web/` and verifies internal hrefs/src attributes resolve (blocks broken links from reaching the published site) |

## Backend (future)

`supabase/migrations/` (not yet written, but schema planned):
- `inkpress_posts`: title, body_html, status (draft/published), created_at, updated_at
- `inkpress_contacts`: email (unique), name, source, created_at

Both tables RLS-enabled, service-role-only writes until Phase 2 adds authenticated single-user write pattern (same as litigate/epiphany).

## Gotchas

- The Xcode project is named `journal.xcodeproj` and the scheme is `Journal-iOS` (frozen from pre-rename; bundle `com.nulljosh.journal` is also locked). This repo is Bugle but builds as Journal in Xcode.
- Date parsing: feeds vary in how they stamp dates. Parser tries: `pubDate` (RFC822), `dc:date`, `published`, `updated`. If none match, entry date is 0 (sorts to bottom forever). Fixed in v1.0.5 by handling RFC822 zones by name (EDT, GMT) instead of just numeric offsets.
- `EntryDetailView` wraps HTML content in an injected `<style>` block because NSAttributedString's HTML importer has no default CSS and leaves entries unstyled.
- Feeds can be parsed as RSS 2.0 or Atom without branching; service transparently handles both.
- The web app has no build step (plain HTML/JS). Deploy by pushing commits; nothing else needed.
