import Foundation

/// 한 시점의 포항 대기 환경 데이터를 표현합니다.
struct AirQualitySnapshot: Equatable, Sendable {
    let locationName: String
    let measuredAt: String
    let temperature: Double
    let pm25: Double
    let uvIndex: Double
}

/// 화면에서 사용하는 환경 데이터 로딩 상태입니다.
enum AirQualityLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
