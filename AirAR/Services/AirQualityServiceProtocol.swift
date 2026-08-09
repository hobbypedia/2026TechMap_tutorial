import Foundation

/// 현재 대기 환경 데이터를 제공하는 서비스의 계약입니다.
protocol AirQualityServiceProtocol: Sendable {
    /// 지정한 좌표의 기온, UV Index와 지상 바람을 가져옵니다.
    /// - Parameters:
    ///   - latitude: 조회할 위도입니다.
    ///   - longitude: 조회할 경도입니다.
    /// - Returns: 앱에서 사용하는 환경 데이터 스냅샷입니다.
    /// - Throws: ``AirQualityServiceError``를 던집니다.
    func fetchCurrentAirQuality(
        latitude: Double,
        longitude: Double
    ) async throws -> AirQualitySnapshot
}

/// 대기 환경 데이터 요청 중 발생할 수 있는 오류입니다.
enum AirQualityServiceError: Error, Equatable, LocalizedError {
    case weatherKitFailed
    case airQualityFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .weatherKitFailed:
            return "Apple Weather 데이터를 불러오지 못했습니다. WeatherKit 설정과 네트워크를 확인해 주세요."
        case .airQualityFailed:
            return "미세먼지 데이터를 불러오지 못했습니다. 네트워크 연결을 확인해 주세요."
        case .cancelled:
            return "요청이 취소되었습니다."
        }
    }
}
