import SwiftUI
import WidgetKit

/// Today's top stories on the Home Screen: the lead with its photo, then the next two. Tapping opens Bugle.
/// ponytail: the widget reads the seed feeds, not the user's own list; share feeds.json through an App Group
/// when people ask for their own feeds on the widget.
struct Top: TimelineEntry {
    let date: Date
    let stories: [Story]
    var photo: Data? = nil
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Top { Top(date: .now, stories: []) }

    func getSnapshot(in context: Context, completion: @escaping (Top) -> Void) {
        Task { completion(await load()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Top>) -> Void) {
        Task { completion(Timeline(entries: [await load()], policy: .after(.now.addingTimeInterval(30 * 60)))) }
    }

    @MainActor private func load() async -> Top {
        let service = JournalFeedService()
        await service.refresh(feeds: FeedStore.seedFeeds)
        let top = Array(Coverage.today(service.stories).prefix(3))
        var photo: Data?
        if let url = top.first?.lead.imageURL { photo = try? await URLSession.shared.data(from: url).0 }
        return Top(date: .now, stories: top, photo: photo)
    }
}

struct TopView: View {
    @Environment(\.widgetFamily) private var family
    let top: Top

    var body: some View {
        if let lead = top.stories.first {
            if family == .systemSmall { Hero(story: lead, photo: top.photo) } else {
                HStack(spacing: 12) {
                    Hero(story: lead, photo: top.photo).aspectRatio(1, contentMode: .fit)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(top.stories.dropFirst()) { Line(story: $0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
            }
        } else {
            Text("Bugle").font(.headline).foregroundStyle(Color.bugleAccent)
        }
    }
}

/// The lead: the photo filling the tile, the outlet and headline in white over a dark fade at its foot.
struct Hero: View {
    let story: Story
    let photo: Data?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.bugleAccent.overlay {
                if let photo, let image = UIImage(data: photo) { Image(uiImage: image).resizable().scaledToFill() }
            }
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(story.lead.sourceTitle).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                Text(Headline.clean(story.lead.title, source: story.lead.sourceTitle))
                    .font(.footnote.weight(.semibold)).foregroundStyle(.white).lineLimit(3)
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct Line: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(story.lead.sourceTitle).font(.caption2.weight(.semibold))
                .foregroundStyle(Outlet.color(story.lead.sourceTitle)).lineLimit(1)
            Text(Headline.clean(story.lead.title, source: story.lead.sourceTitle))
                .font(.footnote.weight(.semibold)).lineLimit(3)
        }
    }
}

@main
struct BugleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BugleTop", provider: Provider()) { top in
            TopView(top: top).containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Top Stories")
        .description("Today's biggest stories, each with every outlet covering it.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
