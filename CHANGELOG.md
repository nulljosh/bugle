# Changelog

Git tags are `bugle-vX.Y.Z`. Earlier history (as Journal, Inkpress and Coranto) is in git log.

## 7.12.0
Your shows: the Podcasts list opens on a shelf of the shows you follow, their art and names, and a tap lists that show's episodes. Up Next says how long the whole queue runs, like Pocket Casts.

## 7.11.0
Ground News's collections beside Blindspots: Popular Left and Popular Right (what one side covers most) and Both Sides (stories both sides covered, to compare the takes). Biggest first, on Home, the iPad and Mac sidebar, and the web, in all 19 languages.

## 7.10.0
Home as Apple would build it, after Tykra's Apple DNA study of X. A large title with the date under it, the Briefing as a round glass button, and search as its own tab that opens a glass field at the bottom (iOS 18 and later; iOS 17 keeps the field at the top). Filtered by an outlet or a word, the title names it and a glass button clears it.

## 7.9.0
Episodes open on their cover: the art fills the top third, blurred under the glass bar, and drifts with a parallax as you scroll. Hacker News stories read in the app, the article and then the whole comment thread. Pages with no article body show their own summary. Swipe left to save, in green. A washed-out cover no longer tints the player beige.

## 7.8.0
- The cover blends into the episode: its art, blurred, washes the top of the page, and the player's glass takes a tint of the cover's color. Now Playing sits on the blurred cover, dimmed 35 percent so the rows read, as Apple asks for glass over rich media.

## 7.7.0
Liquid Glass, done Apple's way (from Apple's Adopting Liquid Glass, Applying Liquid Glass to custom views and the Materials guidelines):
- Glass only in the functional layer. The chips and search field scroll with the stories, so they are plain fills again (7.3.0 had made them glass).
- The player card's corners are concentric with the display's (`ConcentricRectangle`), and the tab bar recedes while you scroll down through stories.
- Web: with Reduce Transparency on, the tab bar, story toolbar and mini player go solid.
- Audited: every toolbar icon has a label, icons and text never share a background, sheets keep the system background.

## 7.6.0
- Reader themes: Auto, Light, Dusk (a soft gray for reading in the dark) and Black, from the story's More menu or Settings; the bar above the story matches. Same on the web, in Settings. No sepia or serif: the house palette has no beige, and type is sans serif.

## 7.5.0
- Briefing: a chip on Home opens today's five biggest stories, numbered, each with its first line and the minutes they take to read (Ground News's The Last 24). Listen reads it top to bottom. Same on the web.

## 7.4.0
- Translate: the story's More menu opens the system Translate sheet over its text, on device (iOS 17.4 and macOS 14.4 or later). Browsers translate the web reader themselves.
- Up and down arrows beside the back button walk the stories in Home's order (Command up and down on the Mac); on the web, j and k do it from a story.
- Share and Open in Browser moved into the More menu on iPhone to make room.

## 7.3.0
- Liquid Glass, second pass: the search field and the chips on Home are glass capsules on iOS 26 and macOS 26; a chip that is on keeps its tint under the glass.
- Dark mode uses Apple's dark system blue for the accent: the brand blue on black was under 3:1 for text.

## 7.2.0
- Liquid Glass, first pass: the episode player is a glass card floating over the page on iOS 26 and macOS 26, and so is the mini player on the Mac and older iPhones. Earlier systems keep the bar material.

## 7.1.0
- Eight more languages: Hindi, Russian, Turkish, Polish, Swedish, Indonesian, Vietnamese and Hebrew (right to left). Nineteen in all, on the apps and the web.
- Times ("2h ago"), source counts, reading time and episode length are translated too, in every language; the web matches strings with numbers in them.
- The player keeps time running left to right in Arabic and Hebrew, as Apple does, and English stories keep their own direction on a right-to-left page.
- Home says Loading while feeds are still coming in, instead of "No entries yet" when the podcasts land before the news.

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
