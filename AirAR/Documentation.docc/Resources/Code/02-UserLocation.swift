import Foundation

/// User coordinates for environmental queries and a location name for display.
/// 환경 데이터를 조회할 사용자 좌표와 화면 표시용 지역 이름입니다.
struct UserLocation: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let displayName: String
}
