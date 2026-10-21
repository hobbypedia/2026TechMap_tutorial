import Foundation

/// Defines the service contract for current environmental data.
/// 현재 대기 환경 데이터를 제공하는 서비스의 계약입니다.
protocol AirQualityServiceProtocol: Sendable {
    /// Fetches temperature, PM2.5, UV Index, and surface wind for the given coordinates.
    /// 지정한 좌표의 기온, PM2.5, UV Index와 지상 바람을 가져옵니다.
    /// - Parameters:
    ///   - latitude: The latitude to query.
    ///     조회할 위도입니다.
    ///   - longitude: The longitude to query.
    ///     조회할 경도입니다.
    /// - Returns: The environmental data snapshot used by the app.
    ///   앱에서 사용하는 환경 데이터 스냅샷입니다.
    /// - Throws: Throws ``AirQualityServiceError``.
    ///   ``AirQualityServiceError``를 던집니다.
    func fetchCurrentAirQuality(
        latitude: Double,
        longitude: Double
    ) async throws -> AirQualitySnapshot
}

/// Errors that can occur while requesting environmental data.
/// 대기 환경 데이터 요청 중 발생할 수 있는 오류입니다.
enum AirQualityServiceError: Error, Equatable, LocalizedError {
    case invalidURL
    case httpError(Int)
    case invalidResponse
    case decodingFailed
    case networkFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "요청 주소를 만들 수 없습니다."
        case let .httpError(statusCode):
            return "서버가 요청을 처리하지 못했습니다. (HTTP \(statusCode))"
        case .invalidResponse:
            return "서버 응답 형식을 확인할 수 없습니다."
        case .decodingFailed:
            return "환경 데이터 형식이 예상과 다릅니다."
        case .networkFailed:
            return "네트워크 연결을 확인한 뒤 다시 시도해 주세요."
        case .cancelled:
            return "요청이 취소되었습니다."
        }
    }
}
