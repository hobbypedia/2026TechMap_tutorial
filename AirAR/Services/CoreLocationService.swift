import CoreLocation
import Foundation

/// Requests location access while using the app through the standard iOS prompt and provides current coordinates.
/// iOS 표준 권한 창을 통해 앱 사용 중 위치 권한을 요청하고 현재 좌표를 제공합니다.
@MainActor
final class CoreLocationService: NSObject, LocationServiceProtocol {
    private let manager: CLLocationManager
    private let geocoder: CLGeocoder
    // Keep authorization and location waits separate; delegate callbacks resume each pending operation.
    // 권한 대기와 위치 대기를 따로 저장하며, delegate 콜백에서 각각의 대기 작업을 재개합니다.
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        manager = CLLocationManager()
        geocoder = CLGeocoder()
        super.init()
        manager.delegate = self
        // Request roughly 100 m accuracy for regional environmental data.
        // 지역별 환경 데이터 조회에 맞춰 약 100m의 위치 정확도를 요청합니다.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Checks service availability, obtains authorization and coordinates, then resolves a display name.
    /// 위치 서비스 상태를 확인하고 권한과 좌표를 얻은 뒤 표시할 지역 이름을 구합니다.
    func requestCurrentLocation() async throws -> UserLocation {
        // Check system location availability off the main actor before starting the request.
        // 요청을 시작하기 전에 메인 액터 밖에서 시스템 위치 서비스 사용 가능 여부를 확인합니다.
        let servicesEnabled = await Task.detached(priority: .userInitiated) {
            CLLocationManager.locationServicesEnabled()
        }.value
        guard servicesEnabled else {
            throw LocationServiceError.servicesDisabled
        }

        // Check cancellation between asynchronous steps so a cancelled request does not proceed to the next stage.
        // 취소된 요청이 다음 단계로 진행하지 않도록 비동기 단계 사이에서 취소 여부를 확인합니다.
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

    /// Stops location and geocoding work and resumes pending waits with cancellation errors.
    /// 위치 조회와 역지오코딩을 중단하고 대기 중인 작업을 취소 오류로 재개합니다.
    func cancel() {
        manager.stopUpdatingLocation()
        geocoder.cancelGeocode()
        authorizationContinuation?.resume(throwing: CancellationError())
        authorizationContinuation = nil
        locationContinuation?.resume(throwing: CancellationError())
        locationContinuation = nil
    }

    /// Prompts only when authorization is undetermined; maps denied or restricted access to app errors.
    /// 권한이 미결정일 때만 안내 창을 띄우고 거부되거나 제한된 접근을 앱 오류로 변환합니다.
    private func requestAuthorizationIfNeeded() async throws {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .notDetermined:
            try await withCheckedThrowingContinuation { continuation in
                // Store the continuation before prompting; the authorization delegate callback completes this wait.
                // 권한 창을 띄우기 전에 continuation을 저장하며, 권한 delegate 콜백에서 이 대기를 완료합니다.
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

    /// Bridges a one-shot delegate-based location request to async/await.
    /// delegate 기반의 일회성 위치 요청을 async/await로 연결합니다.
    private func requestOneLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    /// Reverse-geocodes coordinates into a Korean location name, falling back when lookup fails.
    /// 좌표를 한국어 지역 이름으로 역지오코딩하고 조회 실패 시 대체 문구를 사용합니다.
    private func displayName(for location: CLLocation) async -> String {
        guard let placemark = try? await geocoder.reverseGeocodeLocation(
            location,
            preferredLocale: Locale(identifier: "ko_KR")
        ).first else {
            return "현재 위치"
        }

        // Build a broad-to-local name and omit repeated administrative names.
        // 넓은 행정구역부터 세부 지역 순서로 이름을 만들고 중복된 지역명은 제외합니다.
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

// Delegate callbacks complete the asynchronous waits stored by the service.
// delegate 콜백은 서비스에 저장한 비동기 대기 작업을 완료합니다.
extension CoreLocationService: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Ignore callbacks when no request is waiting; clear stored state before resuming it.
        // 대기 중인 요청이 없으면 콜백을 무시하고, 재개하기 전에 저장된 대기 상태를 비웁니다.
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
        // Use the last location with valid accuracy; negative accuracy indicates an invalid location.
        // 정확도가 유효한 마지막 위치를 사용하며, 음수 정확도는 유효하지 않은 위치를 뜻합니다.
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
        // Distinguish permission denial from other failures so the UI can offer the appropriate recovery.
        // 화면에서 적절한 복구 방법을 안내할 수 있도록 권한 거부와 그 밖의 실패를 구분합니다.
        if let coreLocationError = error as? CLError, coreLocationError.code == .denied {
            continuation.resume(throwing: LocationServiceError.permissionDenied)
        } else {
            continuation.resume(throwing: LocationServiceError.locationUnavailable)
        }
    }
}
