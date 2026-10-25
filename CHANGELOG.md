# Changelog

Git tags are `bugle-vX.Y.Z`. Earlier history (as Journal, Inkpress and Coranto) is in git log.

## 5.4.0
- Italian, Korean, Traditional Chinese, Dutch and Arabic (right to left), in the apps and the web reader. The web-only strings moved into the one String Catalog.

## 5.3.0
- The web reader speaks the same six languages, from the apps' String Catalog (`scripts/gen_i18n.py` writes `web/i18n.js`).

## 5.2.1
- Lean labels, the blindspot note, the Saved and History empty states and the load error are translated too.

## 5.2.0
- The apps speak Spanish, French, German, Brazilian Portuguese, Japanese and Simplified Chinese (a String Catalog in `ios/Sources/Shared/Localizable.xcstrings`).

## 5.1.0
- Dynamic Type at the largest sizes: chips grow, the outlet line wraps, rows show the whole headline, the top story puts its headline under the photo, and story text follows the system size on top of Bugle's own.

## 5.0.1
- VoiceOver reads each story row as one item (outlet, time, sources, headline); labels on the clear button and the saved mark; stand-in pictures and the search magnifier are hidden from it.

## 5.0.0
- Band 4.x (iPad and Mac) done and QA'd on iPhone, iPad, web and the landing, light and dark. App extensions carry the app's build number. The landing logo no longer shows a stale cached icon.

## 4.4.0
- Share extension: from Safari or any app, Share → Bugle saves the story or follows the site.

## 4.3.0
- Spotlight finds saved stories and recent history; Handoff carries an open story to your other devices.

## 4.2.0
- Three columns on iPad and the Mac: outlets, stories, the story.

## 4.1.0
- Keyboard shortcuts on the web, Mac and iPad.

## 4.0.1
- Tighter grouping: a headline joins a story by its lead's words only, and words in a large share of the day's headlines ("apple", "iphone") no longer count, so a busy topic stops swallowing its neighbours.

## 4.0.0
- Story timeline: a week of headlines is kept, and each story shows its earlier coverage. Band 3.x (RSS power) is done.

## 3.7.0
- A Blindspots chip on Home: only the stories one side of the spectrum covered.

## 3.6.0
- Full article text when a feed only sends a summary.

## 3.5.0
- Unread counts on each followed feed, and Mark All Read.

## 3.4.0
- Reading time on each story, app and web.

## 3.3.0
- OPML import and export.

## 3.2.0
- Tech and Mac feeds: Wired, The Verge, Ars Technica, TechCrunch, MacRumors, 9to5Mac, AppleInsider, Macworld, Six Colors.

## 3.1.0
- Paste a site address and Bugle finds its feed. The web feed proxy always answers in sandboxed plain text.

## 3.0.0
- Listen: the system voice reads a story aloud. No gaps left against Apple News and Ground News.

## 2.5.0
- Siri and Shortcuts: "Top stories in Bugle".

## 2.4.0
- Top Stories widget, small and medium.

## 2.3.0
- Notifications for the feeds you pick.

## 2.2.0
- Background refresh; a glass story toolbar on the web.

## 2.1.0
- The top story as a full-bleed photo card with its headline on glass.

## 2.0.0
- Sync of saved stories, history, topics and mutes; follow topics, mute, local news, offline pictures, a Watch app on the shared core.
