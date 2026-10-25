import SwiftUI

/// Settings tab with an actual UI to set the API token WatchAPI reads from UserDefaults.
/// (talli's watchOS app reads `apiToken` but has no screen to set it — this exists so
/// Bugle's watch app doesn't repeat that gap. There's no live personal API yet — see
/// WatchAPI's doc comment — so pairing is optional today and just gets sent as a header
/// once one exists.)
struct PairingView: View {
    @State private var token: String = WatchAPI.shared.apiToken
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: WatchAPI.shared.isPaired ? "checkmark.circle.fill" : "key")
                    .font(.title3)
                    .foregroundStyle(WatchAPI.shared.isPaired ? .green : .secondary)

                Text("API Token")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                SecureField("Paste token", text: $token)
                    .font(.caption)

                Button(saved ? "Saved" : "Save") {
                    WatchAPI.shared.apiToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
                    saved = true
                }
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines) == WatchAPI.shared.apiToken)

                Text("Entries load from public feeds without a token. Pairing is only needed for a future personal API.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 4)
        }
        .onChange(of: token) { saved = false }
    }
}
