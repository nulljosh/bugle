# Bugle Roadmap

Joshua 2026-10-25: "build out roadmap to v100 then loop to it", then "compare gaps to other news apps like native Apple News and Ground News, loop until 0 remaining gaps, QA and test everything, until A+". The loop prompt lives at `~/.claude/loops/bugle.md`.

## Gap matrix (vs Apple News and Ground News)

Status: `todo`, `partial`, `done`, or `n/a` (with the reason). The loop works top to bottom. "0 remaining gaps" means no `todo` or `partial` rows. Each `n/a` has a reason Joshua can overrule.

| # | Feature | Apple News | Ground News | Bugle | Status | Version |
|---|---------|-----------|-------------|---------|--------|---------|
| 1 | Resizable window everywhere | yes | yes | Mac floor was 720 pt wide; iPad already resizes | done | 1.1.0 |
| 2 | One-line list titles, full title on open (Joshua 2026-09-12) | | | one line on iPhone, iPad, Mac and web; Watch keeps two (one line is about 15 characters there) | done | 1.2.0 |
| 3 | Web reader matches the app (bottom bar Home, Feeds, Settings) | | yes | same three screens, bottom bar, same seed list | done | 1.3.0 |
| 4 | Share, copy link, open in browser from a story | yes | yes | share sheet and Open in Browser in the reader; web shares or copies the link | done | 1.4.0 |
| 5 | Text size in the reader | yes | yes | Settings, 13 to 28 pt, app and web | done | 1.5.0 |
| 6 | Saved stories | yes | yes | swipe or press and hold to save (app), Save in the reader (app and web); Saved at the top of Feeds; stored whole so they open offline | done | 1.11.0 |
| 7 | History of read stories, read rows dimmed | yes | yes | History in Feeds, read rows dim, app and web | done | 1.11.0 |
| 8 | Search stories and sources | yes | yes | search field on Home matches headlines and outlet names, app and web | done | 1.12.0 |
| 9 | Offline reading with images | yes | | pictures seen or saved stay on disk (app); saved stories keep every picture and the reader opens offline (web) | done | 1.21.0 |
| 10 | Same story grouped across outlets (full coverage) | yes | yes | ported from Sidewise: one row per story, "N sources" (app and web) | done | 1.14.0 |
| 11 | Lean bar per story (left, center, right) | | yes | Coverage sheet from the reader (app and web) | done | 1.14.0 |
| 12 | Lean and owner label on each outlet | | yes | in Feeds and the Coverage sheet (app and web) | done | 1.14.0 |
| 13 | Compare headlines side by side | | yes | Coverage sheet groups headlines Left, Center, Right (app and web) | done | 1.14.0 |
| 14 | Blindspot: stories one side barely covers | | yes | noted in Coverage (app and web); a Blindspot filter comes with row 16 | done | 1.14.0 |
| 15 | My news bias (lean of what you read) | | yes | Your Reading in Settings (app and web) | done | 1.14.0 |
| 16 | Today: top stories ranked by coverage | yes | yes | five biggest stories of the day (most newsrooms) lead Home | done | 1.16.0 |
| 17 | Follow topics | yes | yes | follow a search as a topic; topics are chips on Home | done | 1.18.0 |
| 18 | Mute a source or topic | yes | yes | Mute on Home hides an outlet or word; Settings lists mutes | done | 1.19.0 |
| 19 | Local news for your region | yes | yes | pick a city in Feeds (10 cities), follow its newsrooms | done | 1.20.0 |
| 20 | Follow sources, suggested sources | yes | yes | Feeds tab | done | 1.0.8 |
| 21 | Background refresh | yes | yes | iOS wakes Bugle about every half hour to fetch feeds and the top pictures; the web refreshes on open | done | 2.2.0 |
| 22 | Notifications for chosen sources | yes | yes | swipe right on a feed (iPhone): new stories from it arrive as notifications after background refresh; web has no push server | done | 2.3.0 |
| 23 | Home Screen widgets | yes | yes | Top Stories, small and medium: the lead photo with its headline, then the next two in outlet colours, every 30 minutes | done | 2.4.0 |
| 24 | Sync of feeds, saved and history | yes | account | feeds, saved, history, topics and mutes sync on app and web (jaybulb-api columns live 2026-10-25) | done | 1.23.0 |
| 25 | Siri and Shortcuts | yes | | "Top stories in Bugle" reads the three biggest from your feeds; Shortcuts gets them as text, on iPhone, iPad and Mac | done | 2.5.0 |
| 26 | Listen to a story | News+ | | Listen in the story toolbar: the system voice reads the headline and story on device, on every platform and the web | done | 3.0.0 |
| 27 | Watch app at parity | yes | | runs on the phone's own feed list, parser and grouping: Today first, outlet colors, sources, Save | done | 1.22.0 |
| 33 | Paste a site address, find its feed (autodiscovery) | | | paste theverge.com and Bugle follows the feed the page links to, app and web | done | 3.1.0 |
| 34 | OPML import and export | | | Import OPML and Export OPML under Following, app and web; duplicates skipped | done | 3.3.0 |
| 35 | Full article text for summary-only feeds | yes | yes | a summary-only story fetches its page and shows the main article's paragraphs as plain text; menus, sidebars and repeated lines dropped | done | 3.6.0 |
| 36 | Unread counts and mark all read | yes | | each followed feed shows its unread count; Mark All Read clears them without filling History | done | 3.5.0 |
| 37 | Blindspot filter on Home | | yes | a Blindspots chip leads Home and shows only stories one side of the spectrum covered | done | 3.7.0 |
| 38 | Keyboard shortcuts (Mac, iPad, web) | yes | | web: j k, Enter, Esc, /, r, s, l, o, 1 to 3; apps: ⌘R, ⌘1 to ⌘3, ⌘S, ⌘L, ⌘⇧O | done | 4.1.0 |
| 39 | Three columns on iPad and Mac (feeds, list, story) | yes | yes | iPad in regular width and the Mac: outlets, stories, the story (HomeSplit); phones keep one stack | done | 4.2.0 |
| 40 | Share extension: add a feed or save a story from Safari | yes | yes | Share → Bugle: Save Story or Follow This Site; handed to the app through a shared keychain inbox | done | 4.4.0 |
| 41 | Spotlight and Handoff | yes | | saved stories and recent history are in Spotlight; an open story hands off to your other devices, or to the browser | done | 4.3.0 |
| 42 | Reading time on each story | yes | | "4 min read" beside the outlet and date on every story with a real body, app and web | done | 3.4.0 |
| 43 | Story timeline: the same story over several days | | yes | a week of headlines is kept; each story lists its earlier coverage under Earlier | done | 4.0.0 |
| 28 | Light and dark mode | yes | yes | yes | done | 1.0.6 |
| 29 | No account, no tracking | Apple ID | account | yes | done | 1.0.0 |
| 30 | Factuality score per source | | yes | | n/a | no free source we can cite; we won't invent scores |
| 31 | Puzzles, magazines, News+ narration | News+ | | | n/a | paid publisher content and licensing |
| 32 | Weather, stocks and sports scores in Today | yes | | | n/a | needs licensed live data; not reading |

## Mobbin study (2026-10-25)

Apple News's "similar screens" on Mobbin lined up about 18 news apps (informed, Guardian, Yahoo News, Ground News, USA Today, BuzzFeed News, SCMP, Artifact, The Athletic, Yahoo Finance, NYT, Citizen, WSJ, The Bulletin). What they share, and where Bugle stands:
- Text left, picture right, the outlet as a small label above the headline, time beside it: done 1.10.0.
- A big hero for the top story: done 1.10.0.
- Relative times ("4h ago"): done 1.10.0.
- No disclosure arrows on rows: done 1.10.0.
- Story clusters ("44 articles", "6 sources", "More on this story"): gap row 10.
- Filter chips at the top (For You, Local, Top Stories): with rows 16 and 19.
- Saved in reach (Guardian and USA Today put it in the tab bar; Bugle keeps it in Feeds): row 6.
- LIVE badges: not in RSS, skip.

## Road to v100

Rewritten 2026-10-25 at 1.19.5 (Joshua: "identify gaps, build roadmap, loop until v5, then 10"). Minor version per row, major version per band. Each major gets the full QA below, fresh README, WHITEPAPER and architecture.svg, and a store submit if no review is open.

- **1.x Reader core, finish** (rows 19, 9, 24, 27). **2.0** shipped 2026-10-25.
- **2.x Around the system** (rows 21, 22, 23, 25, 26: background refresh, notifications, widgets, Shortcuts, listen). **3.0** = 0 gaps against Apple News and Ground News: side-by-side QA.
- **3.x RSS power** (rows 33 to 37, 42, 43: autodiscovery, OPML, full text, unread counts, Blindspot filter, reading time, timelines). **4.0** = 0 gaps against NetNewsWire and Reeder too.
- **4.x iPad and Mac** (rows 38 to 41: shortcuts, three columns, share extension, Spotlight and Handoff). **5.0** QA.
- **6 to 9 Podcasts** (Joshua 2026-08-24; yes on 2026-10-25, with his own shows as the defaults). Apple Podcasts is the reference.
  - [x] 6.0.0: enclosure audio, fourteen default shows, the Podcasts chip, a player with speed, skips, background audio, lock-screen controls and resume, on the apps and the web.
  - [x] 6.1.0: Up Next, and a mini player that keeps playing after you leave the story.
  - [ ] Downloads, so an episode plays offline.
  - [ ] Sleep timer.
  - [ ] Web: BBC episodes redirect to plain-http audio, which an https page cannot play. The apps allow it for bbc.co.uk and tritondigital.com only.
- **10 to 19 Writing** (CMS phases 1 and 2 below). Gate: the backend (D1 on jaybulb-api, not Supabase) and Joshua's yes on accounts for writers.
- **20 to 29 Subscribers** (CRM phase 3). Same gate.
- **30 to 49 Android** from `kmp/`. Gate: a Play developer account.
- **50 to 99** speed, accessibility (VoiceOver, Dynamic Type, Reduce Motion), every language, design polish. Money is free or $1 only; ads go to Joshua as one question, since "no tracking" is the pitch.
- **100** one reader on iPhone, iPad, Mac, Watch, web and Android, in sync.

## QA every major version

- Tests: `node test.mjs` (web), the DEBUG parser self-checks on launch, `cd kmp && ./gradlew :shared:allTests` (when a JDK is present).
- Build iOS, Mac and Watch with no warnings added.
- Screenshots: iPhone and iPad simulators with `-tab 0|1|2` and `-selectFirst`, light and dark; Mac with `scripts/capture-mac-shots.sh` and `CAPTURE_FRAME=1` for the toolbar tabs; web reader at 390 px and desktop; the landing (it iframes `read.html?embed`).
- Live check after every web deploy: curl the pages and `/feed`.

## Other open asks from Joshua

- Expand the curated seed sources beyond the current set (2026-09-12). Check recency with Sidewise's `check-feeds.mjs` first: zombie feeds still return 200.
- Audit the journal repo for personal data (2026-08-22). That's the Jekyll blog repo, not this one.

## CMS/CRM plan (scoped 2026-08-02, gated, see band 10)

Bugle stays a reader and also becomes a Ghost-style writing client.
- Phase 1, single-user write access. Tables `inkpress_posts` and `inkpress_contacts` exist on the shared `spark` Supabase project, RLS on, no policies, no rows, and no `user_id` column. Before any policy: add `user_id uuid not null references auth.users(id) default auth.uid()`, then one `using (user_id = auth.uid()) with check (user_id = auth.uid())` policy per table. Auth config on `spark` is shared by other apps, so diff before any PATCH. `status` has no CHECK and there is no `scheduled_at`.
- Phase 2, compose, edit and publish with draft, scheduled and published states.
- Phase 3, subscribers as contacts (name, email, notes, source).
- Phase 4, pages, tags, search.

## Ship notes
- The jaybulb.com zone has Cloudflare Web Analytics on, so Cloudflare injects its beacon into every page. The site CSP blocks it on purpose (the privacy policy says no analytics); the console shows that block, nothing is collected. Turning it off for this host is a dashboard setting, not reachable with the CLI tokens.
- Publishers like CBC drop requests without a browser user agent; feed.js, og.js and PreviewImage send a Safari string ending in Bugle/1.0.
- Before submitting any build with accounts (1.9.0 on): update the App Privacy answers in App Store Connect. Data collected: Email Address (linked to the user, App Functionality) and Other User Content (the feed list, linked, App Functionality). No tracking.
- Account emails need `bugle` in authmail's THEMES; the app sends `Origin: https://bugle.jaybulb.com` and `redirect_to` so mails say Bugle.

- `asc validate` dies on "multiple app infos found" while a review is open; check readiness by hand and use `asc review submit --dry-run`.
- `whatsNew` can't be set on a platform's first release, and a failed field fails the whole localization PATCH.
- Article bodies render in a `WKWebView` on purpose; the `NSAttributedString` importer rendered blank bodies.
- Thumbnails come from `media:thumbnail`/`media:content`, then `enclosure`, then the first `<img>`; the Swift and JS extractors mirror each other, so change both.
- The feed parsers prefer `content:encoded` over `description` (2026-10-25); before that, both were glued together and stories showed their text twice.

## Shipped

- 2026-10-25 1.15.0: renamed Coranto to Bugle everywhere (folder, site bugle.jaybulb.com, app, fonts, icon bundle); the App Store name is "BugleNews" because Apple refused "Bugle" and "Bugler". coranto.jaybulb.com and inkpress.jaybulb.com keep serving.

- 2026-10-25 1.0.8 (iOS and Mac, both pulled for the rename on 2026-10-25): renamed Inkpress to Coranto, blue brand and icon, bottom tab bar replaces the sidebar, Settings tab, doubled-text fix, dead upvote button removed, purple links fixed, old heyitsmejosh feeds migrated, bugle.jaybulb.com live.
- 2026-08-30 macOS 1.0.7, first Mac release.
- 2026-08-25 1.0.5, 16 curated news feeds seeded, named-zone date fix.
- 2026-08-10 1.0.3, new icon, loading indicator.
