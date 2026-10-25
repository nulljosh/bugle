# Bugle brand kit and design system

Every feed, one timeline. A bugle calls everyone in at once; Bugle does that for the feeds you follow.

## The mark
A bugle, side on: a mouthpiece, one coil hanging from the lead pipe, a wide bell. Bold, flat, white, on the clrs blue gradient. No text, no outline, no emblem. The pipe and bell are one shape, so nothing breaks at small sizes; it still reads as a bugle at 29 px.

- `../Bugle.icon` is the source of truth (Icon Composer), light and dark fills set in it.
- `icon-1024.png` is the App Store icon, no alpha. The iOS, Mac and Watch icon sets are cut from it; the Mac one is inset to 824 px with 185 px corners, like every Mac icon.
- `../icon.svg` is the README copy (80 px). `mark.svg` is the glyph alone in `currentColor`.
- `web/og.png` is the share card: the tile, the name in Bugle Display, the line.
- Clear space equal to the bell's height. Smallest size 16 px.

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
- **Apps:** SF, the system scale. Large title 34, title 22, headline 17 semibold, body 17, footnote 13.
- **Web:** Bugle Display (Inter Tight Bold, renamed by `scripts/gen_font.py`) for headlines in normal case, tracked -0.02em, -0.035em at hero size; Bugle Sans (Inter) for the rest. The reader runs a step under the landing because Inter reads larger than SF: body and rows 16/22, hero 20/26, story title 26/32, chips 14, footnote 13/18. No forced capitals anywhere.

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
- **Top story card:** the photo fills a 28 point card (4:3 on a phone, 16:9 wide, 480 at most); the outlet and headline sit on glass at its foot. Dark under the photo while it loads.
- **Rows:** the outlet above the headline, time and sources beside it, the picture on the right, no disclosure arrows; read rows dim.
- **Chips:** followed topics under the search, 36 tall; on means accent text on a 14 percent accent tint.
- **Toolbars:** glyphs, never words. A round glass back button, then one glass capsule of actions (save, share, open).
- **Tab bar:** native SwiftUI in the apps; on the web a glass capsule of three glyphs, labels kept for screen readers.
- **Lists that can lose a row** swipe left to remove (Following, Muted); a feed swipes right for notifications.
- **Buttons:** primary is a filled accent capsule, secondary a tinted one, both full width in forms.

## Art
Halftone engravings from the print shop (Amman 1568, Stradanus and Galle c. 1590, the Encyclopedie), tinted with the band colour, on the landing. The footer is an engraved band of six glyphs (the bugle, three feeds running into one, a newspaper, a feed, a globe, a bookmark), the same engraving as the Hermes landing.

## Files
`tokens.css` here holds the accent. `web/tokens.css` is the full set the site uses. `Theme.swift` mirrors the accent; `Coverage.swift` and `web/coverage.js` hold the outlet colours.
