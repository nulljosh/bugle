# Bugle brand kit and design system

Every feed, one timeline. A bugle calls everyone in at once; Bugle does that for the feeds you follow.

## The mascot and the icon
The horn come alive: its coil is a round smiling face (dot eyes with a highlight, pink cheeks, a small smile), the tube runs from a mouthpiece behind the face into a wide bell. Bugle blue on a white face; on the icon tile everything but the face's features is white. It blinks, swells its bell and sends three sound waves out of it.

- `web/mascot.svg` (and `brand/mascot.svg`) is the source, a 240 grid. `Mascot.swift` draws the same shapes and animates them (`blink`, `toot`, `waves`).
- Where it lives: the app icon, the boot splash (pops up, blinks, toots, then Home fades up, about a second, a still fade under Reduce Motion), above the first-run topic picker (bobs, toots for every pick), the landing hero and the Get it section.
- `../Bugle.icon` is the icon's source of truth (Icon Composer: the white mascot on the clrs blue gradient, a deep navy one in dark mode). `icon-1024.png` is the App Store icon, no alpha; the iOS and Watch sets are cut from it, the Mac one is inset to 824 px with 185 px corners. `../icon.svg` is the README copy, also `web/icon.svg` and the favicons.
- `mark.svg` is the plain horn alone in `currentColor`, for one-colour places.
- Clear space equal to the bell's height. Smallest size 16 px; at 29 px it still reads as a face with a horn.

## Colour
| Role | Light | Dark |
|---|---|---|
| Accent: actions, links, the icon | `#0059B3` | `#5aa9ff` |
| Icon gradient | `#0074D9` (clrs.cc Blue) to `#0059B3` | same |
| Text | `#1d1d1f` | `#f5f5f7` |
| Secondary text | `#6e6e73` | `#98989d` |
| Background | `#ffffff` | `#000000` |
| Grouped surface | `#f5f5f7` | `#1c1c1e` |
| Hairline | `#e5e5ea` | `#38383a` |

Never brown, beige, purple or teal, and no decorative gradients. The only gradient fills are the icon tile; everything else that fades is a mask on glass.

**Outlet colours.** Each newsroom wears its own colour, a light and dark pair that each pass 4.5:1 on white and on black (`BRAND` in `web/coverage.js`, `Outlet.brand` in `Coverage.swift`, checked by `test.mjs`): Hacker News orange, BBC and CBC red, The Guardian navy, NPR blue and so on. A newsroom's local desks take its colour (CBC Toronto is CBC red). Unknown feeds get one of ten fixed pairs by name. When everything on screen comes from one outlet, the whole reader takes its colour.

## Type
The system font everywhere: SF in the apps and on the web (`-apple-system, BlinkMacSystemFont, "SF Pro Text"`, Helvetica elsewhere). No webfonts. Large title 34, title 22, headline 17 semibold, body 17 (the web reader runs 16/22), footnote 13. No forced capitals anywhere.

## Space and shape
- The 8 point grid: 4, 8, 12, 16, 24, 32, 48. Side margin 20. Reading column 680.
- One radius set: cards 28 (the top story, the share tile), grouped lists 20, story pictures 16, thumbnails 12, every control fully round, the icon 22.5 percent.
- Controls are 48 points tall, chips 36. Focus is a 4 point ring of the accent at 30 percent.
- Motion is 0.2 s ease and honours reduced motion.

## Liquid glass
Glass is for whatever floats over content: the tab bar, the story toolbar, the top story's headline.
- Recipe: a translucent tint (white .62 light, `#2c2c2e` .62 dark; black .34 over photos), `backdrop-filter: blur(30px) saturate(190%)`, a 1 point bright top edge as an inset shadow, a soft drop shadow.
- It stays see-through, so what is under it shows. Over a photo the glass fades in from the top with a mask, so there is never a hard band across the picture.
- White type on glass over photos, in both modes; each outlet uses its dark-mode colour there.

## Components
- **Home:** a large title with the date under it, the Briefing as a round glass button at the top right, and search as its own tab that opens a glass field at the bottom (iOS 18 and later; iOS 17 keeps the field at the top). Filtered, the title names the filter and a glass button clears it.
- **Collection chips:** Unread, Blindspots, Popular Left, Popular Right, Both Sides, Podcasts; each is a search word and a title.
- **Unread:** an 8 point accent dot in the margin, so titles still start on one edge; read rows dim.
- **Layout:** Standard, or Compact (no pictures, no lead story, two lines a row), in Settings.
- **Episode page:** the cover as a hero across the top third, blurred up under the glass bar, with a parallax as you scroll.
- **Top story card:** the photo fills a 28 point card (4:3 on a phone, 16:9 wide, 480 at most); the outlet and headline sit on glass at its foot. Dark under the photo while it loads.
- **Rows:** the outlet above the headline, time and sources beside it, the picture on the right, no disclosure arrows; read rows dim.
- **Chips:** collections and followed topics, 36 tall; on means accent text on a 14 percent accent tint.
- **Toolbars:** glyphs, never words. A round glass back button, then one glass capsule of actions (save, share, open).
- **Tab bar:** native SwiftUI in the apps; on the web a glass capsule of three glyphs, labels kept for screen readers.
- **Lists that can lose a row** swipe left to remove (Following, Muted); a feed swipes right for notifications.
- **Buttons:** primary is a filled accent capsule, secondary a tinted one, both full width in forms.

## Art
Halftone engravings from the print shop (Amman 1568, Stradanus and Galle c. 1590, the Encyclopedie), tinted with the band colour, on the landing. The footer is an engraved band of six glyphs (the bugle, three feeds running into one, a newspaper, a feed, a globe, a bookmark), the same engraving as the Hermes landing.

## Files
`tokens.css` here holds the accent. `web/tokens.css` is the full set the site uses. `Theme.swift` mirrors the accent; `Coverage.swift` and `web/coverage.js` hold the outlet colours.
