import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Share → Bugle from Safari or any app with a link: save the story or follow the site. The choice goes to the
/// Inbox; Bugle takes it in the next time it comes to the front.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let item = extensionContext?.inputItems.first as? NSExtensionItem
        let title = item?.attributedContentText?.string ?? ""
        let provider = item?.attachments?.first { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }
        guard let provider else { return finish() }
        provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, _ in
            let url = (data as? URL)?.absoluteString ?? ""
            DispatchQueue.main.async { self?.show(url: url, title: title) }
        }
    }

    private func show(url: String, title: String) {
        guard url.hasPrefix("http") else { return finish() }
        let card = UIHostingController(rootView: ShareCard(url: url, title: title) { [weak self] follow in
            if let follow { Inbox.add(.init(follow: follow, url: url, title: title)) }
            self?.finish()
        })
        addChild(card)
        card.view.frame = view.bounds
        card.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(card.view)
        card.didMove(toParent: self)
    }

    private func finish() { extensionContext?.completeRequest(returningItems: nil) }
}

private struct ShareCard: View {
    let url: String
    let title: String
    let done: (Bool?) -> Void   // true follow, false save, nil cancel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if !title.isEmpty { Text(title).font(.headline) }
                    Text(URL(string: url)?.host ?? url).foregroundStyle(.secondary)
                }
                Section {
                    Button { done(false) } label: { Label("Save Story", systemImage: "bookmark") }
                    Button { done(true) } label: { Label("Follow This Site", systemImage: "plus.circle") }
                } footer: {
                    Text("Bugle finds the site's feed and adds it the next time you open it.")
                }
            }
            .navigationTitle("Bugle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { done(nil) } } }
        }
        .tint(.bugleAccent)
    }
}
