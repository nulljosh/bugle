import SwiftUI

/// Watch-face equivalent of iOS's EntryListView — latest entries from the subscribed
/// feeds (default: the user's own journal.jaybulb.com), newest first.
struct EntriesView: View {
    @State private var entries: [WatchEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty && isLoading {
                    ProgressView()
                } else if entries.isEmpty {
                    ContentUnavailableView(
                        errorMessage == nil ? "No entries yet" : "Couldn't load",
                        systemImage: "doc.text",
                        description: Text(errorMessage ?? "Pull to refresh")
                    )
                } else {
                    List(entries) { entry in
                        NavigationLink(value: entry) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                        .font(.headline)
                                        .lineLimit(2)
                                    HStack(spacing: 4) {
                                        if !entry.sourceTitle.isEmpty {
                                            Text(entry.sourceTitle)
                                            Text("·")
                                        }
                                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Journal")
            .navigationDestination(for: WatchEntry.self) { entry in
                EntryDetailView(entry: entry)
            }
            .task { await load(showSpinner: entries.isEmpty) }
            .refreshable { await load(showSpinner: false) }
        }
    }

    private func load(showSpinner: Bool) async {
        if entries.isEmpty, let cached = WatchAPI.shared.cachedEntries() {
            entries = cached
        }
        if showSpinner { isLoading = true }
        defer { isLoading = false }
        do {
            entries = try await WatchAPI.shared.fetchEntries()
            errorMessage = nil
        } catch {
            if entries.isEmpty { errorMessage = "Check your connection" }
        }
    }
}
