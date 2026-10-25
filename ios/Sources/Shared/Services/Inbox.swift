import Foundation
import Security
import SwiftUI

/// What the share extension hands the app: "follow this site" or "save this story". The extension cannot write
/// the app's files without an App Group, so items wait in a keychain item both can reach (a team keychain group
/// needs no portal setup), and the app takes them in whenever it comes to the front.
enum Inbox {
    struct Item: Codable { let follow: Bool; let url: String; let title: String }

    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "bugle.inbox",
        kSecAttrAccessGroup as String: "QMM486NPYC.com.nulljosh.journal.shared",
    ]

    static func items() -> [Item] {
        var q = query
        q[kSecReturnData as String] = true
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return [] }
        return (try? JSONDecoder().decode([Item].self, from: data)) ?? []
    }

    static func add(_ item: Item) { store(items() + [item]) }

    static func store(_ items: [Item]) {
        SecItemDelete(query as CFDictionary)
        guard !items.isEmpty, let data = try? JSONEncoder().encode(items) else { return }
        var q = query
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }

    #if !SHARE_EXTENSION
    /// Follow or save everything waiting, then empty the inbox.
    @MainActor
    static func drain(store: FeedStore, library: Library) async {
        let waiting = items()
        guard !waiting.isEmpty else { return }
        Self.store([])
        for item in waiting {
            if item.follow {
                _ = store.add(urlString: await FeedStore.discover(item.url))
            } else {
                let e = JournalEntry(title: item.title.isEmpty ? item.url : item.title, url: item.url, date: .now, htmlContent: "")
                if !library.isSaved(e) { library.toggleSave(e) }
            }
        }
    }
    #endif
}

#if !SHARE_EXTENSION
extension View {
    /// Take in whatever the share extension left, each time the app comes to the front.
    func drainsInbox(store: FeedStore, library: Library) -> some View { modifier(InboxDrain(store: store, library: library)) }
}

private struct InboxDrain: ViewModifier {
    @Environment(\.scenePhase) private var phase
    let store: FeedStore
    let library: Library

    func body(content: Content) -> some View {
        content.onChange(of: phase, initial: true) { if phase == .active { Task { await Inbox.drain(store: store, library: library) } } }
    }
}
#endif

#if DEBUG && !SHARE_EXTENSION
/// `-inboxDemo`: an item written the way the share extension writes it comes back out, and the inbox empties.
func inboxDemo() {
    guard CommandLine.arguments.contains("-inboxDemo") else { return }
    let before = Inbox.items()
    Inbox.store(before + [.init(follow: true, url: "https://example.com", title: "Example")])
    let ok = Inbox.items().last?.url == "https://example.com"
    Inbox.store(before)
    NSLog("inboxDemo: %@", ok ? "ok" : "FAILED")
}
#endif
