# Bugle Technical Whitepaper

**v2.0** | October 2026

Every feed, one timeline. Bugle reads RSS and Atom feeds straight from the sites that publish them and puts every story in one stream on iPhone, iPad, Mac, Apple Watch and the web. When several newsrooms cover the same story it shows one row with all of them, how each side of the spectrum covered it, and the day's biggest stories first. Reading never needs an account.

## The core mechanic: one story, many newsrooms

Every entry from every followed feed goes through `Coverage.cluster`. Headlines are cut to their keywords (stop words out, case folded), and an entry joins a story when at least half of the shorter keyword set overlaps. The newest headline leads the story. Publishers count once: NY Post and NY Post Opinion are one newsroom. Each outlet Bugle rates carries a lean and an owner, so a story knows how many left, center and right newsrooms carried it, and flags a blindspot when only one side did.

`Coverage.today` then ranks: the five stories carried by the most newsrooms in the last 24 hours lead Home, newest first among ties, and everything else follows by time. A muted outlet or word drops out before grouping, so a muted outlet never leads a story or counts toward it.

## Feeds and parsing

`FeedStore` keeps the followed list on the device, seeded with sixteen newsrooms so the first screen is never empty, plus local desks for ten cities. `FeedParser` reads RSS `item` and Atom `entry`, prefers `content:encoded` over `description`, and picks a picture in order: the widest `media:thumbnail` or `media:content`, then an image `enclosure`, then the first `img` in the body, then the article page's own `og:image`. BBC thumbnails are asked for at 976 pixels instead of 240.

## One reader, two languages

The apps share one Swift core (feeds, parser, grouping, headline cleaning, library, outlet colors), including the Watch. The web reader mirrors each rule in plain JavaScript (`parse.js`, `coverage.js`, `headline.js`, `library.js`), and `test.mjs` pins the shared cases so the two cannot drift: the same headline cleans the same way, the same unknown outlet gets the same color.

## Your things

Saved stories are kept whole, body included, so they open offline. The app reads pictures from a disk cache first; the web reader's service worker keeps a saved story's pictures and the reader page itself. History dims stories you have opened and feeds Your Reading, the lean of what you actually read. Topics are followed searches shown as chips on Home.

## Accounts and sync

Optional. A Bugle account lives on jaybulb-api, the fleet's shared auth on Cloudflare D1. One row per account carries the feed list, saved stories (headline, link, outlet, picture), recent history, topics and mutes. Sync is a union by URL or word, so a sync never drops anything. Deleting the account deletes the row.

## Web

`web/read.html` is a static PWA on Cloudflare Pages. Publishers do not send CORS headers, so `/feed` proxies a feed (https only, private hosts refused, size capped) and `/og` reads an article's preview image. The landing page runs the real reader.

## Privacy

No tracking, no analytics, no ads. Feeds are fetched from their own sites. Without an account nothing leaves the device.

## License

MIT 2026, Joshua Trommel
