package com.nulljosh.inkpress

// Ported from ios/Sources/Shared/Services/JournalFeedService.swift's
// FeedParser (an XMLParserDelegate). Same field-handling logic, driven by
// MiniXml.tokenizeXml instead of Foundation's XMLParser.

data class JournalEntry(
    val title: String,
    val url: String,
    val dateMillis: Long,
    val htmlContent: String,
    val imageUrl: String?,
    /** A podcast episode's audio (the feed's audio enclosure); null for an article. */
    val audioUrl: String? = null,
)

private val IMAGE_EXTENSIONS = setOf("jpg", "jpeg", "png", "gif", "webp", "avif")

/** A media/enclosure element is an image if it says so, or -- when it declares neither a
 *  type nor a medium -- if the URL ends in an image extension. */
private fun isImage(attributes: Map<String, String>, url: String): Boolean {
    attributes["type"]?.let { return it.lowercase().startsWith("image/") }
    attributes["medium"]?.let { return it.lowercase() == "image" }
    val ext = url.substringAfterLast('.', "").substringBefore('?').lowercase()
    return ext in IMAGE_EXTENSIONS
}

private val AUDIO_EXTENSIONS = setOf("mp3", "m4a", "aac", "ogg", "oga", "opus", "wav")

/** An enclosure is an episode's audio if its type says audio, or, with no type, its URL ends in an audio extension. */
private fun isAudio(attributes: Map<String, String>, url: String): Boolean {
    attributes["type"]?.let { return it.lowercase().startsWith("audio/") }
    return url.substringAfterLast('.', "").substringBefore('?').lowercase() in AUDIO_EXTENSIONS
}

private val IMG_SRC_REGEX = Regex("<img[^>]+src\\s*=\\s*[\"']([^\"']+)[\"']", RegexOption.IGNORE_CASE)

private fun firstImageSrc(html: String): String? = IMG_SRC_REGEX.find(html)?.groupValues?.getOrNull(1)

/** Handles protocol-relative (//host/x.jpg) and plain relative paths; refuses
 *  anything that is not http(s) so data: blobs never reach an image loader. */
private fun resolve(src: String, base: String): String? {
    val s = src.trim()
    if (s.isEmpty()) return null
    val resolved = when {
        s.startsWith("//") -> {
            val scheme = base.substringBefore("://", "https")
            "$scheme:$s"
        }
        s.contains("://") -> s
        else -> {
            // relative path against base -- keep the base's scheme+host, replace the path
            val schemeEnd = base.indexOf("://")
            if (schemeEnd == -1) return null
            val afterScheme = base.substring(schemeEnd + 3)
            val hostEnd = afterScheme.indexOf('/').let { if (it == -1) afterScheme.length else it }
            val originAndScheme = base.substring(0, schemeEnd + 3 + hostEnd)
            if (s.startsWith("/")) originAndScheme + s else "$originAndScheme/$s"
        }
    }
    val scheme = resolved.substringBefore("://", "").lowercase()
    return if (scheme == "https" || scheme == "http") resolved else null
}

/** media:* wins over <enclosure>, which wins over the first <img> in the body.
 *  No match means no thumbnail -- never a placeholder URL. */
private fun pickImage(media: String, enclosure: String, html: String, entryUrl: String): String? {
    for (candidate in listOf(media, enclosure)) {
        if (candidate.isNotEmpty()) resolve(candidate, entryUrl)?.let { return it }
    }
    val src = firstImageSrc(html) ?: return null
    return resolve(src, entryUrl)
}

private val ISO8601 = Regex("""^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})""")
private val RFC822 = Regex(
    """^\w{3},\s*(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})""",
)
private val MONTHS = listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

/** Days since the epoch for a (y, m, d) civil date, Howard Hinnant's algorithm --
 *  avoids pulling in a date library for one calculation. */
private fun daysFromCivil(y: Int, m: Int, d: Int): Long {
    val yy = if (m <= 2) y - 1 else y
    val era = (if (yy >= 0) yy else yy - 399) / 400
    val yoe = (yy - era * 400).toLong()
    val doy = (153 * (if (m > 2) m - 3 else m + 9) + 2) / 5 + d - 1
    val doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146097L + doe - 719468L
}

/** Accepts ISO8601 (Atom) and RFC822 (RSS pubDate). Sinks anything unparseable to
 *  Long.MIN_VALUE rather than "now" -- entries sort newest-first, so defaulting to
 *  now would pin every unparseable entry above real news forever. */
fun parseFeedDate(raw: String): Long {
    ISO8601.find(raw)?.let { m ->
        val g = m.groupValues
        val days = daysFromCivil(g[1].toInt(), g[2].toInt(), g[3].toInt())
        return days * 86400_000L + g[4].toLong() * 3600_000L + g[5].toLong() * 60_000L + g[6].toLong() * 1000L
    }
    RFC822.find(raw)?.let { m ->
        val g = m.groupValues
        val mo = MONTHS.indexOfFirst { it.equals(g[2], ignoreCase = true) } + 1
        if (mo == 0) return Long.MIN_VALUE
        val days = daysFromCivil(g[3].toInt(), mo, g[1].toInt())
        return days * 86400_000L + g[4].toLong() * 3600_000L + g[5].toLong() * 60_000L + g[6].toLong() * 1000L
    }
    return Long.MIN_VALUE
}

fun parseFeed(xml: String): List<JournalEntry> {
    val entries = mutableListOf<JournalEntry>()
    var element = ""
    var title = ""
    var link = ""
    var date = ""
    var content = ""
    var summary = "" // RSS feeds often send both a summary and the full text
    var mediaSrc = ""
    var enclosureSrc = ""
    var audioSrc = ""
    var inItem = false

    for (event in tokenizeXml(xml)) {
        when (event) {
            is XmlEvent.StartElement -> {
                element = event.name
                when {
                    event.name == "entry" || event.name == "item" -> {
                        inItem = true; title = ""; link = ""; date = ""; content = ""; summary = ""
                        mediaSrc = ""; enclosureSrc = ""; audioSrc = ""
                    }
                    event.name == "link" && inItem -> event.attributes["href"]?.let { link = it }
                    inItem && (event.name == "media:thumbnail" || event.name == "media:content") -> {
                        if (mediaSrc.isEmpty()) {
                            val u = event.attributes["url"]
                            if (u != null && (event.name == "media:thumbnail" || isImage(event.attributes, u))) mediaSrc = u
                        }
                    }
                    inItem && event.name == "enclosure" -> {
                        if (enclosureSrc.isEmpty()) {
                            val u = event.attributes["url"]
                            if (u != null && isImage(event.attributes, u)) enclosureSrc = u
                        }
                        val a = event.attributes["url"]
                        if (audioSrc.isEmpty() && a != null && isAudio(event.attributes, a)) audioSrc = a
                    }
                }
            }
            is XmlEvent.Characters -> if (inItem) appendField(event.text, element) { field, text ->
                when (field) {
                    "title" -> title += text
                    "link" -> link += text
                    "date" -> date += text
                    "content" -> content += text
                    "summary" -> summary += text
                }
            }
            is XmlEvent.CData -> if (inItem) appendField(event.text, element) { field, text ->
                when (field) {
                    "content" -> content += text
                    "title" -> title += text
                    "summary" -> summary += text
                    else -> {}
                }
            }
            is XmlEvent.EndElement -> {
                if (event.name == "entry" || event.name == "item") {
                    inItem = false
                    val audio = audioSrc.ifBlank { null }
                    val entryUrl = link.trim().ifBlank { audio ?: "" }   // an episode with no page is known by its audio
                    entries.add(
                        JournalEntry(
                            title = title.trim(),
                            url = entryUrl,
                            dateMillis = parseFeedDate(date.trim()),
                            htmlContent = content.ifBlank { summary },
                            imageUrl = pickImage(mediaSrc, enclosureSrc, content + summary, entryUrl),
                            audioUrl = audio,
                        ),
                    )
                }
            }
        }
    }
    // Shows that link every episode to the show's page: an episode is then known by its audio. Same as the Swift parser.
    val links = entries.groupingBy { it.url }.eachCount()
    return entries.map { e -> if (e.audioUrl != null && (links[e.url] ?: 0) > 1) e.copy(url = e.audioUrl) else e }
}

private inline fun appendField(text: String, element: String, apply: (String, String) -> Unit) {
    when (element) {
        "title" -> apply("title", text)
        "link" -> apply("link", text)
        "published", "updated", "pubDate", "dc:date" -> apply("date", text)
        "content", "content:encoded" -> apply("content", text)
        "description", "summary" -> apply("summary", text)
    }
}
