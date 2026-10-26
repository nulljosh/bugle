import Foundation

#if DEBUG
/// ponytail: minimal self-check for the hand-rolled parser (Atom + RSS), not a full test target.
func feedParserDemo() {
    let atom = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <entry>
        <title>Test Entry</title>
        <link href="https://journal.jaybulb.com/2026/06/26/week/" rel="alternate" type="text/html" />
        <published>2026-06-26T09:00:00-07:00</published>
        <content type="html">&lt;p&gt;Hello&lt;/p&gt;</content>
      </entry>
    </feed>
    """
    let a = FeedParser.parse(data: Data(atom.utf8))
    assert(a.count == 1, "atom: expected 1 entry, got \(a.count)")
    assert(a[0].title == "Test Entry", "atom title mismatch: \(a[0].title)")
    assert(a[0].url == "https://journal.jaybulb.com/2026/06/26/week/", "atom url mismatch")

    let multiLink = atom.replacingOccurrences(of: "<published>", with:
        "<link href=\"https://example.com/feed.xml\" rel=\"self\"/><link href=\"https://example.com/comments\" rel=\"replies\"/><published>")
    assert(FeedParser.parse(data: Data(multiLink.utf8))[0].url == a[0].url,
           "self and replies links must not replace the article URL")

    let rss = """
    <?xml version="1.0"?>
    <rss version="2.0"><channel>
      <item>
        <title>RSS Item</title>
        <link>https://example.com/post</link>
        <pubDate>Fri, 26 Jun 2026 09:00:00 -0700</pubDate>
        <description>&lt;p&gt;World&lt;/p&gt;</description>
      </item>
    </channel></rss>
    """
    let r = FeedParser.parse(data: Data(rss.utf8))
    assert(r.count == 1, "rss: expected 1 entry, got \(r.count)")
    assert(r[0].title == "RSS Item", "rss title mismatch: \(r[0].title)")
    assert(r[0].url == "https://example.com/post", "rss url mismatch: \(r[0].url)")
    print("FeedParser demo: OK")

    // Named-zone RFC822 (CBC ships EDT, BBC ships GMT); the offset-only format misses these.
    assert(FeedParser.parseDate("Wed, 12 Aug 2026 15:00:00 EDT") != .distantPast, "EDT pubDate unparsed")
    assert(FeedParser.parseDate("Tue, 25 Aug 2026 11:53:36 GMT") != .distantPast, "GMT pubDate unparsed")
    assert(FeedParser.parseDate("Tue, 25 Aug 2026 11:20:18 -0400") != .distantPast, "offset pubDate unparsed")
    // Junk must sink, not float to the top as "now".
    assert(FeedParser.parseDate("not a date") == .distantPast, "unparseable date should sink")

    // --- thumbnails ---
    // The common case: most feeds carry no image at all, and must stay nil rather than
    // reserving an empty box in the list row.
    assert(a[0].imageURL == nil, "atom entry with no image should be nil")
    assert(r[0].imageURL == nil, "rss item with no image should be nil")

    func firstEntry(_ xml: String) -> JournalEntry { FeedParser.parse(data: Data(xml.utf8))[0] }

    // media:* beats <enclosure> beats the first <img> in the body.
    let media = firstEntry("""
    <?xml version="1.0"?>
    <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/"><channel><item>
      <title>M</title><link>https://example.com/a</link>
      <media:content url="https://cdn.example.com/big.jpg" type="image/jpeg"/>
      <description>&lt;img src="https://cdn.example.com/body.jpg"&gt;</description>
    </item></channel></rss>
    """)
    assert(media.imageURL?.absoluteString == "https://cdn.example.com/big.jpg", "media:content should win")

    // A podcast's audio enclosure is not a thumbnail; fall through to the body image.
    let podcast = firstEntry("""
    <?xml version="1.0"?>
    <rss version="2.0"><channel><item>
      <title>P</title><link>https://example.com/c</link>
      <enclosure url="https://cdn.example.com/ep.mp3" type="audio/mpeg" length="1"/>
      <description>&lt;img src="https://cdn.example.com/art.jpg"&gt;</description>
    </item></channel></rss>
    """)
    assert(podcast.imageURL?.absoluteString == "https://cdn.example.com/art.jpg", "audio enclosure must be skipped")
    assert(podcast.audioURL?.absoluteString == "https://cdn.example.com/ep.mp3", "the audio enclosure is the episode")

    // An episode with no link of its own is known by its audio; an untyped .m4a still counts.
    let bare = firstEntry("""
    <?xml version="1.0"?>
    <rss version="2.0"><channel><item>
      <title>E</title><enclosure url="https://cdn.example.com/ep.m4a?x=1"/>
    </item></channel></rss>
    """)
    assert(bare.url == "https://cdn.example.com/ep.m4a?x=1" && bare.audioURL != nil, "linkless episode keeps its audio as its url")
    assert(media.audioURL == nil, "an article has no audio")

    // A show that links every episode to its own page: each episode is known by its audio, and wears the show's art.
    let show = FeedParser.parse(data: Data("""
    <?xml version="1.0"?>
    <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"><channel>
      <itunes:image href="https://cdn.example.com/show.jpg"/>
      <item><title>A</title><link>https://example.com/show</link><enclosure url="https://cdn.example.com/a.mp3" type="audio/mpeg"/>
        <itunes:duration>16:40</itunes:duration></item>
      <item><title>B</title><link>https://example.com/show</link><enclosure url="https://cdn.example.com/b.mp3" type="audio/mpeg"/></item>
    </channel></rss>
    """.utf8))
    assert(show.map(\.url) == ["https://cdn.example.com/a.mp3", "https://cdn.example.com/b.mp3"], "shared show link: episodes keep apart")
    assert(show[0].imageURL?.absoluteString == "https://cdn.example.com/show.jpg", "episode wears the show's art")
    assert(show[0].listenTime == "17 min" && show[1].listenTime == nil, "episode length")
    assert(FeedParser.sharpen(URL(string: "http://ichef.bbci.co.uk/images/ic/3000x3000/p0.jpg")!)?.absoluteString
           == "https://ichef.bbci.co.uk/images/ic/480x480/p0.jpg", "http art upgraded and shrunk")

    // Protocol-relative and plain-relative srcs resolve against the entry link.
    let protoRel = firstEntry("""
    <?xml version="1.0"?>
    <rss version="2.0"><channel><item>
      <title>R</title><link>https://example.com/posts/d</link>
      <description>&lt;img src="//host.example/x.jpg"&gt;</description>
    </item></channel></rss>
    """)
    assert(protoRel.imageURL?.absoluteString == "https://host.example/x.jpg", "protocol-relative src unresolved")

    let plainRel = firstEntry("""
    <?xml version="1.0"?>
    <rss version="2.0"><channel><item>
      <title>R2</title><link>https://example.com/posts/e</link>
      <description>&lt;img src="thumb.png"&gt;</description>
    </item></channel></rss>
    """)
    assert(plainRel.imageURL?.absoluteString == "https://example.com/posts/thumb.png", "relative src unresolved")

    // data: blobs must never reach AsyncImage.
    let dataURI = firstEntry("""
    <?xml version="1.0"?>
    <rss version="2.0"><channel><item>
      <title>D</title><link>https://example.com/g</link>
      <description>&lt;img src="data:image/gif;base64,R0lGOD"&gt;</description>
    </item></channel></rss>
    """)
    assert(dataURI.imageURL == nil, "data: URI should be refused")
    print("FeedParser thumbnails: OK")
}
#endif
