import Foundation
import Security

/// An optional Bugle account on jaybulb-api (api.jaybulb.com), the fleet's shared auth (Joshua 2026-10-25:
/// "add accounts support, register/login, in settings"). It does one job: your followed feeds follow you to every
/// device and the web reader. Reading never needs it. The refresh token sits in the Keychain; the access token
/// lives in memory and is renewed from it. Mirrors the account code in web/reader.js.
@MainActor
final class Account: ObservableObject {
    static let api = URL(string: "https://api.jaybulb.com")!
    static let confirmPage = "https://bugle.jaybulb.com/"

    @Published private(set) var email: String?
    @Published var busy = false
    @Published var message: String?
    private var userID: String?
    private var access: String?

    init() {
        if let saved = Keychain.read() { email = saved.email; userID = saved.id }
    }

    var signedIn: Bool { email != nil }

    func signUp(email: String, password: String) async {
        await run {
            _ = try await self.call("POST", "/auth/signup", body: ["email": email, "password": password, "redirect_to": Self.confirmPage])
            self.message = "Check \(email) for a link to confirm your account, then sign in."
        }
    }

    func signIn(email: String, password: String, store: FeedStore) async {
        await run {
            let session = try await self.call("POST", "/auth/token?grant_type=password", body: ["email": email, "password": password])
            try self.keep(session)
            try await self.sync(store)
        }
    }

    func resetPassword(email: String) async {
        await run {
            _ = try await self.call("POST", "/auth/recover", body: ["email": email, "redirect_to": Self.confirmPage])
            self.message = "If \(email) has an account, a reset link is on its way."
        }
    }

    func signOut() async {
        _ = try? await authed("POST", "/auth/logout")
        forget()
    }

    func deleteAccount() async {
        await run {
            _ = try await self.authed("DELETE", "/auth/user")
            self.forget()
            self.message = "Your account and its synced feeds are deleted. Your feeds stay on this device."
        }
    }

    /// Union of this device's feeds and the account's, by URL, saved to both. Nothing is ever dropped by a sync.
    func sync(_ store: FeedStore) async throws {
        let rows = try await authed("GET", "/rest/coranto_sync") as? [[String: Any]] ?? []
        let remote = (rows.first?["feeds"] as? [[String: String]] ?? []).compactMap { d -> Feed? in
            guard let t = d["title"], let u = d["url"] else { return nil }
            return Feed(title: t, url: u)
        }
        for f in remote where !store.feeds.contains(where: { $0.url == f.url }) { store.feeds.append(f) }
        try await push(store.feeds)
    }

    func push(_ feeds: [Feed]) async throws {
        guard let id = userID else { return }
        _ = try await authed("POST", "/rest/coranto_sync?on_conflict=id", body: ["id": id, "feeds": feeds.map { ["title": $0.title, "url": $0.url] }],
                             headers: ["Prefer": "resolution=merge-duplicates"])
    }

    // MARK: plumbing

    private func run(_ work: @escaping () async throws -> Void) async {
        busy = true; message = nil
        do { try await work() } catch { message = (error as? APIError)?.text ?? "Could not reach the server. Try again." }
        busy = false
    }

    private func keep(_ session: Any) throws {
        guard let s = session as? [String: Any], let token = s["access_token"] as? String, let refresh = s["refresh_token"] as? String,
              let user = s["user"] as? [String: Any], let id = user["id"] as? String, let mail = user["email"] as? String else { throw APIError(text: "Unexpected answer from the server.") }
        access = token; userID = id; email = mail
        Keychain.write(.init(id: id, email: mail, refresh: refresh))
    }

    private func forget() {
        access = nil; userID = nil; email = nil
        Keychain.clear()
    }

    /// Signed request; renews the access token from the Keychain refresh token once if it is missing or expired.
    private func authed(_ method: String, _ path: String, body: Any? = nil, headers: [String: String] = [:]) async throws -> Any {
        if access == nil { try await renew() }
        do { return try await call(method, path, body: body, headers: headers, token: access) }
        catch let e as APIError where e.status == 401 { try await renew(); return try await call(method, path, body: body, headers: headers, token: access) }
    }

    private func renew() async throws {
        guard let saved = Keychain.read() else { forget(); throw APIError(text: "Please sign in again.", status: 401) }
        do { try keep(try await call("POST", "/auth/token?grant_type=refresh_token", body: ["refresh_token": saved.refresh])) }
        catch { forget(); throw APIError(text: "Please sign in again.", status: 401) }
    }

    struct APIError: Error { var text: String; var status = 0 }

    private func call(_ method: String, _ path: String, body: Any? = nil, headers: [String: String] = [:], token: String? = nil) async throws -> Any {
        var req = URLRequest(url: URL(string: path, relativeTo: Self.api)!, timeoutInterval: 15)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("https://bugle.jaybulb.com", forHTTPHeaderField: "Origin")   // names the app in account emails
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) ?? [:]
        guard (200..<300).contains(status) else {
            let raw = (json as? [String: Any])?["error"] as? String ?? (json as? [String: Any])?["msg"] as? String
            throw APIError(text: Self.plain(raw, status: status), status: status)
        }
        return json
    }

    /// Server messages in words a person would use.
    private static func plain(_ raw: String?, status: Int) -> String {
        switch raw ?? "" {
        case "Invalid login credentials": return "That email and password don't match."
        case "Email not confirmed": return "Confirm your email first: the link is in your inbox."
        case "slow down": return "Too many tries. Wait a minute and try again."
        case let r where !r.isEmpty: return r.prefix(1).uppercased() + r.dropFirst() + "."
        default: return status == 0 ? "Could not reach the server. Try again." : "Something went wrong (\(status))."
        }
    }
}

/// The saved session: one generic-password item, so it survives relaunch and never lands in a backup in clear text.
private enum Keychain {
    struct Saved: Codable { let id: String; let email: String; let refresh: String }
    private static let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.nulljosh.coranto.account"]

    static func read() -> Saved? {
        var q = base; q[kSecReturnData as String] = true
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(Saved.self, from: data)
    }

    static func write(_ s: Saved) {
        clear()
        var q = base
        q[kSecValueData as String] = try? JSONEncoder().encode(s)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }

    static func clear() { SecItemDelete(base as CFDictionary) }
}
