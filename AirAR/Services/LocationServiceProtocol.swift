import Foundation

/// 현재 위치 권한 요청과 좌표 획득을 추상화한 서비스 계약입니다.
@MainActor
protocol LocationServiceProtocol: AnyObject {
    func requestCurrentLocation() async throws -> UserLocation
    func cancel()
}

/// 위치 권한 또는 현재 좌표를 얻는 과정에서 발생하는 오류입니다.
enum LocationServiceError: Error, Equatable, LocalizedError {
    case servicesDisabled
    case permissionDenied
    case permissionRestricted
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .servicesDisabled:
            return "위치 서비스가 꺼져 있습니다. 설정에서 위치 서비스를 켜 주세요."
        case .permissionDenied:
            return "현재 위치의 환경 정보를 보려면 위치 권한이 필요합니다."
        case .permissionRestricted:
            return "이 기기에서는 위치 사용이 제한되어 있습니다."
        case .locationUnavailable:
            return "현재 위치를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요."
        }
    }
}
