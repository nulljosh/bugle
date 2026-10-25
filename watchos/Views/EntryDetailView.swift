import SwiftUI

/// watchOS has no WebKit, so this can't reuse iOS's WKWebView-based EntryDetailView.
/// Shows the tag-stripped plain-text preview instead of full HTML.
struct EntryDetailView: View {
    let entry: WatchEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title)
                    .font(.headline)
                HStack(spacing: 4) {
                    if !entry.sourceTitle.isEmpty {
                        Text(entry.sourceTitle)
                        Text("·")
                    }
                    Text(entry.date.formatted(date: .long, time: .omitted))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Divider()

                let preview = entry.plainTextPreview
                Text(preview.isEmpty ? "No preview available." : preview)
                    .font(.footnote)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Entry")
    }
}
