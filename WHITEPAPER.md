# Bugle Technical Whitepaper

**v1.0.5** | August 2026

All your feeds, one timeline. An RSS and Atom reader for iOS, built because
following a dozen sites means a dozen tabs or a dozen apps, when the actual
thing wanted is one place newest-first with nothing else in the way.

Add any feed and read everything in one stream, newest first. Split from the
`journal` repo on 2026-07-21, since the two only ever shared a folder by
accident of naming, not because a blog and a feed reader are the same product.

## Content Model

Feeds are a simple persisted list (`FeedStore`, `Application Support/feeds.json`
on-device, no server sync), because a feed list is personal state with no
reason to leave the device it lives on. Seeded with one feed on first launch
(`journal.heyitsmejosh.com/feed.xml`, the author's own blog) purely so the
app isn't empty on first open, it's a regular subscription, fully
removable, with no special handling versus any other feed the user adds,
since an empty first screen would be the app's worst first impression.

## Parsing

`JournalFeedService` fetches and parses both RSS and Atom formats, because
the two formats are both still common in the wild and a reader that only
handled one would silently fail on half the feeds people actually add.
Entry HTML content is wrapped in a forced `<style>` block before rendering,
since `NSAttributedString`'s HTML importer has no default CSS and would
otherwise render unstyled serif text with no spacing.

## Scope

v1.0.3 is live on the App Store; v1.0.5 (seeded newsline feeds) is in review.

No accounts, no user-authored content, no writing/logging feature, Bugle
only reads feeds, on purpose: a reader that also wants to be a writing tool
stops being simple to use. Cross-device sync of subscriptions would need
accounts; not started, no current need.

## Security / Privacy

No backend, no user accounts, no data collection. Feed subscriptions are
stored locally on-device only.

## License

MIT 2026, Joshua Trommel
