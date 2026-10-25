import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            EntriesView()
            PairingView()
        }
        .tabViewStyle(.verticalPage)
    }
}
