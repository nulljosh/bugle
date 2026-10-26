import SwiftUI

/// iPad in regular width and the Mac: three columns, like Mail and NetNewsWire. Outlets on the left (Today,
/// Blindspots, your topics, the feeds you follow), the stories in the middle, the story itself on the right.
/// Picking an outlet is the same search Home already does, so both layouts read the same list.
struct HomeSplit<Home: View, Story: View>: View {
    @Binding var query: String
    /// The story column's stack: a story tapped in the middle column lands here.
    @Binding var path: [JournalEntry]
    let feeds: [Feed]
    let topics: [String]
    @ViewBuilder let home: Home
    @ViewBuilder let story: (JournalEntry) -> Story

    var body: some View {
        NavigationSplitView {
            List(selection: Binding<String?>(get: { query }, set: { query = $0 ?? "" })) {
                Section {
                    Label("Today", systemImage: "newspaper").tag("")
                    Label(LocalizedStringKey(Coverage.blindspots), systemImage: "eye.slash").tag(Coverage.blindspots)
                    Label(LocalizedStringKey(Coverage.podcasts), systemImage: "headphones").tag(Coverage.podcasts)
                }
                if !topics.isEmpty {
                    Section("Topics") { ForEach(topics, id: \.self) { Label($0, systemImage: "number").tag($0) } }
                }
                Section("Following") {
                    ForEach(feeds) { feed in
                        Label { Text(feed.title) } icon: { Image(systemName: "circle.fill").foregroundStyle(Outlet.color(feed.title)) }
                            .tag(feed.title)
                    }
                }
            }
            .navigationTitle("Bugle")
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } content: {
            home.navigationSplitViewColumnWidth(min: 340, ideal: 420)
        } detail: {
            NavigationStack(path: $path) {
                ContentUnavailableView("Pick a story", systemImage: "newspaper").navigationDestination(for: JournalEntry.self, destination: story)
            }
        }
    }
}
