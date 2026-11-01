import CoreLocation

/// Local news without a picker: one coarse location fix, then the nearest city Bugle has newsrooms for.
/// Nothing leaves the device; the fix is compared against a fixed list and dropped.
@MainActor
final class NearestCity: NSObject, CLLocationManagerDelegate {
    /// City centres for FeedStore.local, same names.
    static let centres: [(city: String, lat: Double, lng: Double)] = [
        ("Vancouver", 49.28, -123.12), ("Calgary", 51.05, -114.07), ("Edmonton", 53.55, -113.49),
        ("Toronto", 43.65, -79.38), ("Ottawa", 45.42, -75.70), ("Montreal", 45.50, -73.57),
        ("Seattle", 47.61, -122.33), ("New York", 40.71, -74.01), ("Los Angeles", 34.05, -118.24),
        ("London", 51.51, -0.13),
    ]
    /// Further than this from every city means there is no local feed for you; the picker stays empty.
    static let reachKm = 150.0

    /// Pure: the nearest city within reach of a coordinate, or nil.
    static func city(lat: Double, lng: Double) -> String? {
        let here = CLLocation(latitude: lat, longitude: lng)
        let best = centres.map { ($0.city, here.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lng)) / 1000) }
            .min { $0.1 < $1.1 }
        guard let best, best.1 <= reachKm else { return nil }
        return best.0
    }

    private let manager = CLLocationManager()
    private var waiting: CheckedContinuation<CLLocation?, Never>?

    func find() async -> String? {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        let fix: CLLocation? = await withCheckedContinuation { c in
            waiting = c
            proceed()
        }
        guard let fix else { return nil }
        return Self.city(lat: fix.coordinate.latitude, lng: fix.coordinate.longitude)
    }

    private func proceed() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: finish(nil)
        }
    }

    private func finish(_ loc: CLLocation?) {
        waiting?.resume(returning: loc)
        waiting = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in if self.waiting != nil, self.manager.authorizationStatus != .notDetermined { self.proceed() } }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let first = locations.first
        Task { @MainActor in self.finish(first) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }
}
