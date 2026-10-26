# Changelog

Git tags are `bugle-vX.Y.Z`. Earlier history (as Journal, Inkpress and Coranto) is in git log.

## 7.0.0
Podcasts, done as a whole: fourteen default shows, the Podcasts chip, a player with speed, skips, the lock screen and resume, Up Next, a mini player, Now Playing with AirPlay, downloads and a sleep timer, on the iPhone, iPad, Mac and the web.
- QA pass on iPhone and iPad in light and dark, the web at phone and desktop width, and the landing. Builds for iPhone, iPad, Mac and Watch.
- The mini player hides on the playing episode's own story, where its full player already is.
- New App Store screenshots that show podcasts (`ios/.asc/screenshots`).

## 6.4.0
- Now Playing: tap the mini player for the episode (tap it to open its story), Up Next to drag into order or swipe away, Clear, the full controls, and AirPlay. The web opens the same sheet, with Move up and remove.
- QA hooks load an episode paused (`-cueEpisode`, `-nowPlaying`), so a screenshot run never plays sound.

## 6.3.0
- Sleep timer: the moon on the player pauses after 5 to 60 minutes, or stops at the end of the episode and leaves Up Next waiting. The web cycles 15, 30, 60 minutes and end of episode.

## 6.2.0
- Downloads: save an episode from its toolbar or by pressing and holding its row, and it plays offline. A downloaded episode shows an arrow by its outlet, and one played to the end is removed, like Apple Podcasts. The web streams only.
- Search finds episodes too, so tapping a show in Feeds lists its episodes instead of "No stories match".
- Web: the default feeds moved to `seeds.js`.

## 6.1.1
- Home fills in as feeds arrive instead of waiting on the slowest one. A first launch on a phone network sat on a spinner; a clean install now shows stories in about 3 seconds. Same on the web.
- A feed that stops answering gives up after 15 seconds of silence instead of 60.

## 6.1.0
- One player for the whole app: an episode keeps playing while you read on. A mini player rides above the tab bar (the tab bar's own accessory on iOS 26.1, glass over the bottom edge on the Mac and the web) with the art, play and forward 30; tap it to open the episode. The last episode comes back paused after a relaunch.
- Up Next: add an episode from its page or by pressing and holding its row. Up Next leads the Podcasts list, and when an episode ends the next one plays.
- An episode you are not playing shows Play (or Resume) and Up Next instead of a second player.

## 6.0.1
- Feeds says "Podcast" under the default shows instead of their feed address.
- An episode WSJ posts to two of its shows is listed once.
- Web: the Listen button really hides on an episode (a style rule was beating `hidden`).
- The landing mentions podcasts.

## 6.0.0
- Podcasts. Fourteen shows come followed by default (WSJ's briefings, Wall Street Breakfast, World Report, The Markets, The AI Daily Brief, My First Million, Mel Robbins, Tim Dillon and more); add any podcast feed like any other. A Podcasts chip on Home, and a Podcasts row in the iPad and Mac sidebar, lists episodes newest first with their length. Episodes stay out of the news grouping.
- An episode's story plays its own audio: scrubber, 1x to 2x, back 15, forward 30, lock screen and Control Center controls, background audio, and it picks up where you left off. The same player on the web, with Media Session for the lock screen.
- The web proxy keeps a feed's newest 100 items, and cuts an oversized feed at its last whole item instead of refusing it, so big podcast feeds load on the web.
- Pictures load over https, so BBC podcast art and any other plain-http image show in the apps.

## 5.4.3
- A feed that gave nothing on the last refresh says "Not loading right now" in Feeds, on the web and in the apps (CBC blocks the web proxy).

## 5.4.2
- Web Settings matches the app: a Version row, and Website, Privacy and Support in the accent colour.

## 5.4.1
- Web story toolbar: the title fades in only once the headline scrolls under the bar, like an iOS inline title, so a phone shows back and the actions with room to breathe.

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
