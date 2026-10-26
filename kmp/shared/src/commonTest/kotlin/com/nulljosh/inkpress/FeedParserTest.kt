package com.nulljosh.inkpress

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class FeedParserTest {
    @Test fun parsesRss2Item() {
        val xml = """
            <rss><channel>
              <item>
                <title>Hello &amp; World</title>
                <link>https://example.com/a</link>
                <pubDate>Wed, 03 Sep 2026 12:00:00 GMT</pubDate>
                <description><![CDATA[<p>Body <img src="https://example.com/img.jpg"></p>]]></description>
              </item>
            </channel></rss>
        """.trimIndent()
        val entries = parseFeed(xml)
        assertEquals(1, entries.size)
        assertEquals("Hello & World", entries[0].title)
        assertEquals("https://example.com/a", entries[0].url)
        assertEquals("https://example.com/img.jpg", entries[0].imageUrl)
        assertTrue(entries[0].dateMillis > 0)
    }

    @Test fun prefersFullTextOverSummary() {
        val xml = """
            <rss><channel><item>
              <title>T</title>
              <description>Short</description>
              <content:encoded><![CDATA[<p>Full</p>]]></content:encoded>
            </item></channel></rss>
        """.trimIndent()
        assertEquals("<p>Full</p>", parseFeed(xml)[0].htmlContent)
    }

    @Test fun parsesAtomEntry() {
        val xml = """
            <feed>
              <entry>
                <title>Atom Post</title>
                <link href="https://example.com/b" />
                <updated>2026-09-03T12:00:00Z</updated>
                <content>Some content</content>
              </entry>
            </feed>
        """.trimIndent()
        val entries = parseFeed(xml)
        assertEquals(1, entries.size)
        assertEquals("Atom Post", entries[0].title)
        assertEquals("https://example.com/b", entries[0].url)
    }

    @Test fun mediaThumbnailWinsOverBodyImage() {
        val xml = """
            <rss><channel><item>
              <title>T</title>
              <link>https://example.com/c</link>
              <media:thumbnail url="https://example.com/thumb.jpg" />
              <description><![CDATA[<img src="https://example.com/other.jpg">]]></description>
            </item></channel></rss>
        """.trimIndent()
        assertEquals("https://example.com/thumb.jpg", parseFeed(xml)[0].imageUrl)
    }

    @Test fun unparseableDateSinksToDistantPast() {
        assertEquals(Long.MIN_VALUE, parseFeedDate("not a date"))
    }

    @Test fun namedTimezoneRfc822Parses() {
        val ms = parseFeedDate("Wed, 03 Sep 2026 12:00:00 EDT")
        assertTrue(ms > 0)
    }

    @Test fun audioEnclosureIsTheEpisode() {
        val xml = """<rss><channel>
            <item><title>A</title><link>https://e.com/show</link><enclosure url="https://c.com/a.mp3" type="audio/mpeg"/></item>
            <item><title>B</title><link>https://e.com/show</link><enclosure url="https://c.com/b.mp3" type="audio/mpeg"/></item>
            </channel></rss>"""
        val got = parseFeed(xml)
        assertEquals(listOf("https://c.com/a.mp3", "https://c.com/b.mp3"), got.map { it.url })
        assertEquals("https://c.com/a.mp3", got[0].audioUrl)
    }
}
