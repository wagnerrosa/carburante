//
//  LocationService.swift
//  Carburante
//
//  CoreLocation: pede permissão, captura uma posição e faz reverse geocoding
//  (cidade/estado/país). Best-effort — se a permissão for negada ou o GPS
//  falhar, retorna nil e o registro segue sem localização.
//

import Foundation
import CoreLocation

/// Snapshot de localização para gravar no abastecimento.
struct LocationSnapshot: Equatable {
    var latitude: Double
    var longitude: Double
    var city: String?
    var state: String?
    var country: String?
}

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Captura uma localização atual. Retorna nil se negado/indisponível.
    /// Pede autorização "when in use" se ainda não decidido.
    func currentSnapshot() async -> LocationSnapshot? {
        let status = manager.authorizationStatus
        switch status {
        case .denied, .restricted:
            return nil
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // Aguarda o usuário decidir; quando autorizar, segue para a captura.
            // Se negar, o request abaixo retorna nil rápido.
            try? await Task.sleep(for: .seconds(1))
            // Analytics: registra a resposta (só na 1ª decisão, contexto = 1º
            // save de abastecimento, único ponto que chama isto no MVP).
            let after = manager.authorizationStatus
            let result = (after == .authorizedWhenInUse || after == .authorizedAlways)
                ? "granted" : (after == .restricted ? "restricted" : "denied")
            Analytics.permissionResponded(permission: "location", result: result,
                                          context: "first_fuel_save")
        default:
            break
        }

        guard manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways else {
            return nil
        }

        guard let location = await requestLocation() else { return nil }
        let place = await reverseGeocode(location)
        return LocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            city: place?.locality,
            state: place?.administrativeArea,
            country: place?.country
        )
    }

    private func requestLocation() async -> CLLocation? {
        await withCheckedContinuation { (cont: CheckedContinuation<CLLocation?, Never>) in
            continuation = cont
            manager.requestLocation()
        }
    }

    private func reverseGeocode(_ location: CLLocation) async -> CLPlacemark? {
        let geocoder = CLGeocoder()
        let locale = Locale(identifier: "pt_BR")
        return try? await geocoder.reverseGeocodeLocation(location, preferredLocale: locale).first
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            continuation?.resume(returning: location)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }
}
