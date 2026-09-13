import Foundation

/// 상단 상태 패널의 단일 항목을 표현하는 화면 전용 모델입니다.
struct AirQualityMetricViewModel: Identifiable, Equatable {
    enum Kind: String {
        case temperature
        case pm25
        case uvIndex
    }

    let id: Kind
    let title: String
    let value: String
    let accessibilityValue: String
    let symbol: String
    let level: AirQualityLevel?
}
