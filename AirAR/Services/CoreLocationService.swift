import CoreLocation
import Foundation

/// iOS 표준 권한 창을 통해 앱 사용 중 위치 권한을 요청하고 현재 좌표를 제공합니다.
@MainActor
final class CoreLocationService: NSObject, LocationServiceProtocol {
    private let manager: CLLocationManager
    private let geocoder: CLGeocoder
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        manager = CLLocationManager()
        geocoder = CLGeocoder()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation() async throws -> UserLocation {
        let servicesEnabled = await Task.detached(priority: .userInitiated) {
            CLLocationManager.locationServicesEnabled()
        }.value
        guard servicesEnabled else {
            throw LocationServiceError.servicesDisabled
        }

        try await requestAuthorizationIfNeeded()
        try Task.checkCancellation()
        let location = try await requestOneLocation()
        try Task.checkCancellation()

        return UserLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            displayName: await displayName(for: location)
        )
    }

    func cancel() {
        manager.stopUpdatingLocation()
        geocoder.cancelGeocode()
        authorizationContinuation?.resume(throwing: CancellationError())
        authorizationContinuation = nil
        locationContinuation?.resume(throwing: CancellationError())
        locationContinuation = nil
    }

    private func requestAuthorizationIfNeeded() async throws {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .notDetermined:
            try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        case .denied:
            throw LocationServiceError.permissionDenied
        case .restricted:
            throw LocationServiceError.permissionRestricted
        @unknown default:
            throw LocationServiceError.locationUnavailable
        }
    }

    private func requestOneLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    private func displayName(for location: CLLocation) async -> String {
        guard let placemark = try? await geocoder.reverseGeocodeLocation(
            location,
            preferredLocale: Locale(identifier: "ko_KR")
        ).first else {
            return "현재 위치"
        }

        let candidates = [
            placemark.administrativeArea,
            placemark.locality,
            placemark.subLocality
        ]
        var uniqueParts: [String] = []
        for part in candidates.compactMap({ $0 }) where !uniqueParts.contains(part) {
            uniqueParts.append(part)
        }
        return uniqueParts.isEmpty ? "현재 위치" : uniqueParts.joined(separator: " ")
    }
}

extension CoreLocationService: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = authorizationContinuation else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationContinuation = nil
            continuation.resume()
        case .denied:
            authorizationContinuation = nil
            continuation.resume(throwing: LocationServiceError.permissionDenied)
        case .restricted:
            authorizationContinuation = nil
            continuation.resume(throwing: LocationServiceError.permissionRestricted)
        case .notDetermined:
            break
        @unknown default:
            authorizationContinuation = nil
            continuation.resume(throwing: LocationServiceError.locationUnavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last(where: { $0.horizontalAccuracy >= 0 }),
              let continuation = locationContinuation else {
            return
        }
        locationContinuation = nil
        continuation.resume(returning: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        if let coreLocationError = error as? CLError, coreLocationError.code == .denied {
            continuation.resume(throwing: LocationServiceError.permissionDenied)
        } else {
            continuation.resume(throwing: LocationServiceError.locationUnavailable)
        }
    }
}
