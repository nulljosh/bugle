import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: FeedStore
    @ObservedObject var account: Account
    @ObservedObject var library: Library
    @AppStorage("readerTextSize") private var textSize = 17.0
    @AppStorage("muted") private var muted = ""
    @State private var showSignIn = false
    @State private var confirmDelete = false
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let email = account.email {
                        LabeledContent("Signed in", value: email)
                        Button("Sign Out") { Task { await account.signOut() } }
                        Button("Delete Account", role: .destructive) { confirmDelete = true }
                    } else {
                        Button("Sign In or Create Account") { showSignIn = true }
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text(account.message ?? "Optional. Your followed feeds follow you to every device and the web reader. Reading never needs an account.")
                }
                Section {
                    LeanBar(counts: Coverage.readingLean(library.history))
                } header: {
                    Text("Your Reading")
                } footer: {
                    Text(library.history.isEmpty ? "Open a few stories to see how what you read leans." : "From the last \(library.history.count == 1 ? "story" : "\(library.history.count) stories") you opened, rated outlets only.")
                }
                Section {
                    ForEach(Topics.list(muted), id: \.self) { m in
                        Text(m).swipeActions { Button("Unmute", role: .destructive) { muted = Topics.toggled(m, in: muted) } }
                    }
                    if muted.isEmpty { Text("Nothing muted.").foregroundStyle(.secondary) }
                } header: {
                    Text("Muted")
                } footer: {
                    Text("Search an outlet or a word on Home, then tap Mute to hide its stories. Swipe left to unmute.")
                }
                Section("Reading") {
                    Stepper(value: $textSize, in: 13...28) {
                        LabeledContent("Text size", value: "\(Int(textSize)) pt")
                    }
                    Text("The quick brown fox reads the news.")
                        .font(.system(size: textSize))
                        .foregroundStyle(.secondary)
                }
                Section {
                    LabeledContent("Version", value: version)
                }
                Section {
                    Link("Website", destination: URL(string: "https://bugle.jaybulb.com")!)
                    Link("Privacy", destination: URL(string: "https://bugle.jaybulb.com/privacy")!)
                    Link("Support", destination: URL(string: "https://bugle.jaybulb.com/support")!)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showSignIn) { SignInView(store: store, account: account) }
            .confirmationDialog("Delete your Bugle account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) { Task { await account.deleteAccount() } }
            } message: {
                Text("This deletes your account and the feeds synced to it. Feeds on this device stay.")
            }
        }
    }
}

/// Email and password, one form for both: sign in, create an account, or reset a password.
private struct SignInView: View {
    @ObservedObject var store: FeedStore
    @ObservedObject var account: Account
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""

    private var ready: Bool { email.contains("@") && password.count >= 8 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                    SecureField("Password (8 or more characters)", text: $password)
                        .textContentType(.password)
                } footer: {
                    if let m = account.message { Text(m) }
                }
                // Sign In filled, Create Account tinted, both full-width capsules; Forgot is a plain link.
                Section {
                    VStack(spacing: 8) {
                        Button {
                            Task { await account.signIn(email: email, password: password, store: store); if account.signedIn { dismiss() } }
                        } label: { Text("Sign In").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent)
                            .disabled(!ready || account.busy)
                        Button { Task { await account.signUp(email: email, password: password) } } label: {
                            Text("Create Account").frame(maxWidth: .infinity)
                        }
                            .buttonStyle(.bordered)
                            .disabled(!ready || account.busy)
                        Button("Forgot Password?") { Task { await account.resetPassword(email: email) } }
                            .buttonStyle(.borderless)
                            .font(.subheadline.weight(.regular))
                            .disabled(!email.contains("@") || account.busy)
                            .padding(.top, 4)
                    }
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                    .fontWeight(.semibold)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Account")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .overlay { if account.busy { ProgressView() } }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 320)
        #endif
    }
}
