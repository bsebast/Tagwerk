import Foundation
import CoreLocation

/// Reine Entfernungslogik für Orts-Tags (testbar ohne Standortzugriff).
enum LocationMatch {
    static let defaultRadius: CLLocationDistance = 150

    static func isNear(latitude: Double?, longitude: Double?, radius: Double, to location: CLLocation?) -> Bool {
        guard let latitude, let longitude, let location else { return false }
        let target = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: target) <= max(radius, 50)
    }
}

/// Liefert den aktuellen Standort, solange die App geöffnet ist.
/// Mitteilungen am Ort laufen unabhängig davon über das System (siehe `ReminderScheduler`).
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
        authorization = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    /// Fragt bei Bedarf nach der Erlaubnis und startet die Standortbestimmung.
    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = location
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Kein Standort verfügbar (z. B. Simulator ohne Ort): Orts-Funktionen bleiben einfach inaktiv.
    }
}
