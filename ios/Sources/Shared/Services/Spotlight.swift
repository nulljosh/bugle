import CoreSpotlight
import SwiftUI

/// Spotlight and Handoff. Saved stories and recent history are searchable from the Home Screen and the Mac's
/// Spotlight; a story open on one device can be picked up on another (in Bugle, or in the browser).
enum Spotlight {
    static let storyActivity = "com.nulljosh.journal.story"

    static func index(_ entries: [JournalEntry]) {
        let items = entries.map { e -> CSSearchableItem in
            let a = CSSearchableItemAttributeSet(contentType: .text)
            a.title = Headline.clean(e.title, source: e.sourceTitle)
            a.contentDescription = e.sourceTitle
            a.thumbnailURL = e.imageURL
            return CSSearchableItem(uniqueIdentifier: e.url, domainIdentifier: "story", attributeSet: a)
        }
        // ponytail: replace the whole set each time; it is a few hundred items at most
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["story"]) { _ in
            CSSearchableIndex.default().indexSearchableItems(items)
        }
    }
}

extension View {
    /// Open a story from a Spotlight result or a Handoff from another device.
    func continuesStories(in library: Library, open: @escaping (JournalEntry) -> Void) -> some View {
        onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  let e = (library.saved + library.history).first(where: { $0.id == id }) else { return }
            open(e)
        }
        .onContinueUserActivity(Spotlight.storyActivity) { activity in
            guard let url = activity.webpageURL?.absoluteString else { return }
            open(JournalEntry(title: activity.title ?? url, url: url, date: .now, htmlContent: ""))
        }
    }

    /// Offer the open story to the user's other devices; one without Bugle opens it in the browser.
    func handsOff(_ entry: JournalEntry) -> some View {
        userActivity(Spotlight.storyActivity) { a in
            a.title = entry.title
            a.webpageURL = URL(string: entry.url)
            a.isEligibleForHandoff = true
        }
    }
}
