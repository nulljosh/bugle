# Bugle brand kit and design system

every feed runs into one current

## The mark
One bold flat white glyph on an accent gradient tile. No text, no outline, no emblem.

- `../Bugle.icon` is the source of truth (Icon Composer). Light and dark fills are set in it.
- `../icon.svg` is the flat copy for READMEs (shown at 80 px). `icon-1024.png` is the App Store icon, no alpha.
- `mark.svg` is the glyph alone in `currentColor` for your own background.
- Clear space equal to the width of the glyph's thickest stroke. Smallest size 16 px.

## Colour
| Role | Light | Dark |
|---|---|---|
| Accent, links | `#0059B3` | `#5aa9ff` |
| Buttons | `#0063BF` | `#0a6fd6` |
| Band (full-bleed sections, white text) | `#0063BF` | `#0a4f9a` |
| Icon gradient | `#0074D9` (clrs.cc Blue) to `#0059B3` | same |
| Text | `#141414` | `#f3f2f2` |
| Secondary text | `#5c5c66` | `#aaa6a6` |
| Background | `#ffffff` | `#0e0d0d` |
| Surface | `#f5f5f7` | `#1a1919` |
| Line | `#e2e2e6` | `#2c2a2a` |

The accent is for actions, links and the icon. Never brown, beige, purple or teal.

## Type
Two faces, both renamed from SIL OFL fonts by `scripts/gen_font.py`, license in `web/fonts/OFL.txt`.

- **Bugle Display** is Inter Tight Bold. Headlines, in normal case, tracked slightly tight (-0.02em, -0.035em at hero size).
- **Bugle Sans** is Inter, 400 to 700. Everything else. Inter is a screen sans serif in the Helvetica and San Francisco line, with proportional figures and real lowercase. No forced capitals anywhere (Joshua 2026-10-25).

The apps use SF until a build bundles the fonts. Web scale: hero 64 to 232, section 52 to 112, card 30/32, body 17/24, footnote 13/16. Labels 14/16 at 0.1em tracking.

## Art
Halftone dot masks of public domain print-shop engravings (Amman 1568, Stradanus and Galle c. 1590, the Encyclopedie), tinted with the band art colour. They live in `web/art/` and are credited in `web/index.html`.

## Space and shape
- Space on the 8 point grid: 4, 8, 12, 16, 24, 32, 48. Side margin 20. Reading column 680.
- Radii: cards 28, grouped lists 20, controls fully round in the apps, 2 point squares on the web, icon 22 percent.
- Controls are 48 points tall capsules, one height in a row. Focus is a 4 point ring at 30 percent accent.
- Motion is 0.2 s ease and honours reduced motion.

`tokens.css` here holds the accent. `web/tokens.css` is the full set the site uses: colour, both faces, the grid and the radii. `Theme.swift` mirrors the accent.
