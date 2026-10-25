package com.nulljosh.inkpress

import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.statement.bodyAsText

data class Feed(val title: String, val url: String)

// Same seed list as ios/Sources/Shared/Models/Feed.swift's FeedStore.seedFeeds
// (the blog's own feed plus curated news outlets), trimmed to a starter set --
// full ManageFeedsView-style add/remove is not ported.
val SEED_FEEDS = listOf(
    Feed("Journal", "https://journal.jaybulb.com/feed.xml"),
    Feed("Hacker News", "https://hnrss.org/frontpage"),
    Feed("BBC", "https://feeds.bbci.co.uk/news/rss.xml"),
)

class FeedClient {
    private val http = HttpClient()

    /** Fetches every feed and merges entries newest-first, matching
     *  JournalFeedService.refresh's shape (one bad feed doesn't blank the rest). */
    suspend fun refresh(feeds: List<Feed> = SEED_FEEDS): List<Pair<Feed, JournalEntry>> {
        val merged = mutableListOf<Pair<Feed, JournalEntry>>()
        for (feed in feeds) {
            val xml = runCatching { http.get(feed.url).bodyAsText() }.getOrNull() ?: continue
            val entries = runCatching { parseFeed(xml) }.getOrDefault(emptyList())
            entries.forEach { merged.add(feed to it) }
        }
        return merged.sortedByDescending { it.second.dateMillis }
    }
}
