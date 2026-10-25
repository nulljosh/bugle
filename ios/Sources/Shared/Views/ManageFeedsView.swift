import SwiftUI

struct ManageFeedsView: View {
    @ObservedObject var store: FeedStore
    @ObservedObject var library: Library
    /// Tap an outlet to read just it: Home searches for it and takes its color.
    var open: (Feed) -> Void = { _ in }
    @State private var newFeed = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            List {
                // Apple News keeps these under Following; here they sit above the feeds.
                Section {
                    NavigationLink { StoryList(title: "Saved", entries: library.saved, library: library, empty: "Swipe right on a story, or press and hold it, to save it here. Saved stories open without a connection.") } label: {
                        LabeledContent { Text("\(library.saved.count)") } label: { Label("Saved", systemImage: "bookmark") }
                    }
                    NavigationLink { StoryList(title: "History", entries: library.history, library: library, empty: "Stories you open show up here.", clear: library.clearHistory) } label: {
                        Label("History", systemImage: "clock")
                    }
                }
                Section {
                    HStack {
                        TextField("Add feed URL (RSS or Atom)", text: $newFeed)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            #endif
                            .autocorrectionDisabled()
                            .onSubmit(add)
                        Button("Add", action: add)
                            .disabled(newFeed.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } footer: {
                    Text("Paste any RSS or Atom feed URL to follow it.")
                }

                Section("Following") {
                    ForEach(store.feeds) { feed in
                        Button { open(feed) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feed.title).font(.body).foregroundStyle(Outlet.color(feed.title))
                                Text(Self.about(feed)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                    .onDelete(perform: store.remove)
                }

                if !store.unsubscribedSeeds.isEmpty {
                    Section("Suggested") {
                        ForEach(store.unsubscribedSeeds) { feed in
                            Button { store.add(feed) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(feed.title).font(.body)
                                        Text(Self.about(feed)).font(.caption)
                                            .foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "plus")
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Feeds")
            .alert("Invalid or duplicate URL", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    /// "Leans left · Canadian public broadcaster" for outlets Bugle rates; the address for anything else.
    static func about(_ feed: Feed) -> String {
        guard let o = Outlet.of(feed.title) else { return feed.url }
        return (o.lean.map(Outlet.leanLabel) ?? "Not rated") + " · " + o.owner
    }

    private func add() {
        guard store.add(urlString: newFeed) else { showError = true; return }
        newFeed = ""
    }
}

/// Saved or History: the same rows as Home, opening the same reader.
struct StoryList: View {
    let title: String
    let entries: [JournalEntry]
    @ObservedObject var library: Library
    let empty: String
    var clear: (() -> Void)? = nil

    var body: some View {
        List(entries) { EntryRow(entry: $0, library: library) }
            .listStyle(.plain)
            .overlay { if entries.isEmpty { ContentUnavailableView(title, systemImage: title == "Saved" ? "bookmark" : "clock", description: Text(empty)) } }
            .navigationTitle(title)
            .navigationDestination(for: JournalEntry.self) { EntryDetailView(entry: $0, library: library) }
            .toolbar {
                if let clear, !entries.isEmpty { ToolbarItem(placement: .primaryAction) { Button("Clear", role: .destructive, action: clear) } }
            }
    }
}
