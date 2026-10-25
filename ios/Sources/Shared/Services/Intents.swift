import AppIntents

/// "Hey Siri, top stories in Bugle": fetches your feeds and reads Today's three biggest stories, each with its
/// outlet. Shortcuts gets the same headlines as text to pass along.
struct TopStoriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Top Stories"
    static var description = IntentDescription("Today's biggest stories from the feeds you follow.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let service = JournalFeedService()
        await service.refresh(feeds: FeedStore().feeds)
        let lines = Coverage.today(service.stories).prefix(3).map {
            "\($0.lead.sourceTitle): \(Headline.clean($0.lead.title, source: $0.lead.sourceTitle))"
        }
        let text = lines.isEmpty ? "Bugle couldn't load your feeds just now." : lines.joined(separator: "\n")
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

struct BugleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TopStoriesIntent(),
                    phrases: ["Top stories in \(.applicationName)", "What's the news in \(.applicationName)"],
                    shortTitle: "Top Stories", systemImageName: "newspaper")
    }
}
