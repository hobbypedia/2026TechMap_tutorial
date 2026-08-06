import Foundation

/// 환경 수치를 사용자에게 전달할 때 사용하는 공통 5단계 상태입니다.
enum AirQualityLevel: CaseIterable, Equatable, Sendable {
    case veryGood
    case good
    case moderate
    case bad
    case veryBad

    var title: String {
        switch self {
        case .veryGood: "매우 좋음"
        case .good: "좋음"
        case .moderate: "보통"
        case .bad: "나쁨"
        case .veryBad: "매우 나쁨"
        }
    }

    /// 에어코리아 PM2.5 예보 경계(15/35/75㎍/㎥)를 유지합니다.
    /// 공식 `좋음` 구간(0~15)만 5단계 UI를 위해 0~7과 8~15로 나눕니다.
    static func pm25(_ value: Double) -> Self {
        switch max(0, value) {
        case ..<8: .veryGood
        case ..<16: .good
        case ..<36: .moderate
        case ..<76: .bad
        default: .veryBad
        }
    }

    /// 기상청 자외선 지수의 5단계 경계(2/5/7/10)를 사용합니다.
    static func uvIndex(_ value: Double) -> Self {
        switch max(0, value) {
        case ..<3: .veryGood
        case ..<6: .good
        case ..<8: .moderate
        case ..<11: .bad
        default: .veryBad
        }
    }
}
