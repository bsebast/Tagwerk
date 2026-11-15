import SwiftUI
import MapKit
import CoreLocation

/// Bearbeitbare Orts-Angaben eines Tags (wird erst beim Sichern übernommen).
struct TagLocationDraft: Equatable {
    var latitude: Double?
    var longitude: Double?
    var address: String = ""
    var radius: Double = LocationMatch.defaultRadius
    var suggest: Bool = true
    var autoFilter: Bool = false
    var notify: Bool = false

    init() {}

    init(tag: TodoTag?) {
        guard let tag else { return }
        latitude = tag.latitude
        longitude = tag.longitude
        address = tag.address
        radius = tag.radius
        suggest = tag.locationSuggest
        autoFilter = tag.locationAutoFilter
        notify = tag.locationNotify
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func apply(to tag: TodoTag) {
        tag.latitude = latitude
        tag.longitude = longitude
        tag.address = coordinate == nil ? "" : address
        tag.radius = radius
        tag.locationSuggest = suggest
        tag.locationAutoFilter = autoFilter
        tag.locationNotify = notify
    }
}

/// Abschnitt „Ort“ im Tag-Editor: Adresse suchen oder aktuellen Standort übernehmen,
/// Karte mit Umkreis und die drei Verhaltensweisen (vorschlagen, filtern, Mitteilung).
struct TagLocationSection: View {
    @Binding var draft: TagLocationDraft
    let color: Color
    let name: String

    @ObservedObject private var location = LocationService.shared
    @State private var isSearching = false
    @State private var waitingForCurrentLocation = false
    @State private var message: String?

    var body: some View {
        Section {
            if let coordinate = draft.coordinate {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: draft.radius * 5,
                    longitudinalMeters: draft.radius * 5
                ))) {
                    MapCircle(center: coordinate, radius: draft.radius)
                        .foregroundStyle(color.opacity(0.2))
                        .stroke(color, lineWidth: 1.5)
                    Marker(name.isEmpty ? "Ort" : name, coordinate: coordinate)
                        .tint(color)
                }
                .id("\(coordinate.latitude),\(coordinate.longitude),\(draft.radius)")
                .frame(height: 190)
                .listRowInsets(EdgeInsets())
                .allowsHitTesting(false)
            }

            HStack {
                TextField("Adresse, z. B. Hauptstraße 1, Mainz", text: $draft.address)
                    .textContentType(.fullStreetAddress)
                    .submitLabel(.search)
                    .onSubmit { Task { await searchAddress() } }
                if isSearching {
                    ProgressView()
                } else {
                    Button {
                        Task { await searchAddress() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(draft.address.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Adresse suchen")
                }
            }

            Button {
                useCurrentLocation()
            } label: {
                if waitingForCurrentLocation {
                    Label("Standort wird ermittelt …", systemImage: "location")
                } else {
                    Label("Aktuellen Standort verwenden", systemImage: "location.fill")
                }
            }
            .disabled(waitingForCurrentLocation)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Palette.coral)
            }

            if draft.coordinate != nil {
                Picker("Umkreis", selection: $draft.radius) {
                    Text("100 m").tag(100.0)
                    Text("150 m").tag(150.0)
                    Text("300 m").tag(300.0)
                    Text("500 m").tag(500.0)
                }
                Toggle("Tag vorschlagen, wenn ich dort bin", isOn: $draft.suggest)
                Toggle("Liste dort automatisch filtern", isOn: $draft.autoFilter)
                Toggle("Mitteilung beim Ankommen", isOn: $draft.notify)
                Button("Ort entfernen", role: .destructive) {
                    withAnimation {
                        draft.latitude = nil
                        draft.longitude = nil
                        draft.address = ""
                    }
                }
            }
        } header: {
            Text("Ort")
        } footer: {
            Text("Optional. In der Nähe dieses Orts schlägt Tagwerk den Tag vor, filtert die Liste oder meldet sich mit der Zahl offener Aufgaben. Jedes Verhalten lässt sich einzeln einschalten.")
        }
        .onReceive(location.$lastLocation) { current in
            guard waitingForCurrentLocation, let current else { return }
            waitingForCurrentLocation = false
            withAnimation {
                draft.latitude = current.coordinate.latitude
                draft.longitude = current.coordinate.longitude
            }
            Task { await fillAddress(for: current) }
        }
        .onReceive(location.$authorization) { status in
            if waitingForCurrentLocation && (status == .denied || status == .restricted) {
                waitingForCurrentLocation = false
                message = "Standortzugriff ist ausgeschaltet. Bitte in den iOS-Einstellungen unter Tagwerk → Standort erlauben."
            }
        }
    }

    private func useCurrentLocation() {
        message = nil
        if let current = location.lastLocation, abs(current.timestamp.timeIntervalSinceNow) < 120 {
            withAnimation {
                draft.latitude = current.coordinate.latitude
                draft.longitude = current.coordinate.longitude
            }
            Task { await fillAddress(for: current) }
        } else {
            waitingForCurrentLocation = true
            location.start()
        }
    }

    private func searchAddress() async {
        let query = draft.address.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        message = nil
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let current = location.lastLocation {
            request.region = MKCoordinateRegion(center: current.coordinate, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        }
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                message = "Adresse nicht gefunden."
                return
            }
            let coordinate = item.placemark.coordinate
            withAnimation {
                draft.latitude = coordinate.latitude
                draft.longitude = coordinate.longitude
            }
            if let title = item.placemark.title, !title.isEmpty {
                draft.address = title
            }
        } catch {
            message = "Adresse nicht gefunden."
        }
    }

    private func fillAddress(for current: CLLocation) async {
        // Lesbare Adresse für den Standort; ohne Treffer bleiben die Koordinaten stehen.
        if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(current),
           let placemark = placemarks.first {
            let parts = [placemark.thoroughfare, placemark.subThoroughfare, placemark.locality].compactMap { $0 }
            if !parts.isEmpty {
                draft.address = parts.joined(separator: " ")
                return
            }
        }
        draft.address = String(format: "%.5f, %.5f", current.coordinate.latitude, current.coordinate.longitude)
    }
}
