package com.nulljosh.inkpress

// A minimal streaming XML tokenizer, just enough to drive an RSS/Atom parser
// the same way Foundation's XMLParser drives JournalFeedService's SAX
// delegate. Not a general XML parser: no namespace resolution, no entity
// tables beyond the five predefined XML entities, no DTD/schema handling.
// ponytail: swap for a real XML library if a feed needs more than this.

sealed class XmlEvent {
    data class StartElement(val name: String, val attributes: Map<String, String>) : XmlEvent()
    data class EndElement(val name: String) : XmlEvent()
    data class Characters(val text: String) : XmlEvent()
    data class CData(val text: String) : XmlEvent()
}

private fun decodeEntities(s: String): String {
    if ('&' !in s) return s
    val sb = StringBuilder()
    var i = 0
    while (i < s.length) {
        val c = s[i]
        if (c == '&') {
            val semi = s.indexOf(';', i)
            if (semi != -1 && semi - i <= 10) {
                val entity = s.substring(i + 1, semi)
                val replacement = when {
                    entity == "amp" -> "&"
                    entity == "lt" -> "<"
                    entity == "gt" -> ">"
                    entity == "quot" -> "\""
                    entity == "apos" -> "'"
                    entity.startsWith("#x") || entity.startsWith("#X") ->
                        entity.substring(2).toIntOrNull(16)?.let { it.toChar().toString() }
                    entity.startsWith("#") -> entity.substring(1).toIntOrNull()?.let { it.toChar().toString() }
                    else -> null
                }
                if (replacement != null) { sb.append(replacement); i = semi + 1; continue }
            }
        }
        sb.append(c); i++
    }
    return sb.toString()
}

private fun parseAttributes(raw: String): Map<String, String> {
    val attrs = mutableMapOf<String, String>()
    var i = 0
    while (i < raw.length) {
        while (i < raw.length && raw[i].isWhitespace()) i++
        val nameStart = i
        while (i < raw.length && raw[i] != '=' && !raw[i].isWhitespace()) i++
        if (i >= raw.length || nameStart == i) break
        val name = raw.substring(nameStart, i)
        while (i < raw.length && raw[i].isWhitespace()) i++
        if (i >= raw.length || raw[i] != '=') continue
        i++ // '='
        while (i < raw.length && raw[i].isWhitespace()) i++
        if (i >= raw.length) break
        val quote = raw[i]
        if (quote != '"' && quote != '\'') break
        i++
        val valueStart = i
        while (i < raw.length && raw[i] != quote) i++
        attrs[name] = decodeEntities(raw.substring(valueStart, i))
        i++ // closing quote
    }
    return attrs
}

/** Strips a leading namespace prefix (`content:encoded` stays as-is on purpose --
 *  callers key on the qualified name, matching the Swift delegate's `elementName`). */
fun tokenizeXml(xml: String): List<XmlEvent> {
    val events = mutableListOf<XmlEvent>()
    var i = 0
    val n = xml.length
    while (i < n) {
        val lt = xml.indexOf('<', i)
        if (lt == -1) {
            val text = xml.substring(i)
            if (text.isNotEmpty()) events.add(XmlEvent.Characters(decodeEntities(text)))
            break
        }
        if (lt > i) events.add(XmlEvent.Characters(decodeEntities(xml.substring(i, lt))))

        when {
            xml.startsWith("<![CDATA[", lt) -> {
                val end = xml.indexOf("]]>", lt)
                val stop = if (end == -1) n else end
                events.add(XmlEvent.CData(xml.substring(lt + 9, stop)))
                i = if (end == -1) n else end + 3
            }
            xml.startsWith("<!--", lt) -> {
                val end = xml.indexOf("-->", lt)
                i = if (end == -1) n else end + 3
            }
            xml.startsWith("<?", lt) -> {
                val end = xml.indexOf("?>", lt)
                i = if (end == -1) n else end + 2
            }
            xml.startsWith("<!", lt) -> {
                val end = xml.indexOf(">", lt)
                i = if (end == -1) n else end + 1
            }
            xml.startsWith("</", lt) -> {
                val end = xml.indexOf('>', lt)
                if (end == -1) { i = n } else {
                    events.add(XmlEvent.EndElement(xml.substring(lt + 2, end).trim()))
                    i = end + 1
                }
            }
            else -> {
                val end = xml.indexOf('>', lt)
                if (end == -1) { i = n } else {
                    var body = xml.substring(lt + 1, end)
                    val selfClosing = body.endsWith("/")
                    if (selfClosing) body = body.dropLast(1)
                    val nameEnd = body.indexOfFirst { it.isWhitespace() }.let { if (it == -1) body.length else it }
                    val name = body.substring(0, nameEnd).trim()
                    val attrs = if (nameEnd < body.length) parseAttributes(body.substring(nameEnd)) else emptyMap()
                    if (name.isNotEmpty()) {
                        events.add(XmlEvent.StartElement(name, attrs))
                        if (selfClosing) events.add(XmlEvent.EndElement(name))
                    }
                    i = end + 1
                }
            }
        }
    }
    return events
}
