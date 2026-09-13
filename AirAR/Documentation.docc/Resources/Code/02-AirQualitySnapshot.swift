import Foundation

/// 한 시점의 사용자 위치 대기 환경 데이터를 표현합니다.
struct AirQualitySnapshot: Equatable, Sendable {
    let locationName: String
    let measuredAt: String
    let temperature: Double
    let pm25: Double
    let uvIndex: Double
    /// 지상 10m 풍속이며 단위는 m/s입니다.
    let windSpeed: Double
    /// 바람이 불어오는 방향이며 정북을 0도로 한 시계 방향 각도입니다.
    let windDirection: Double
    /// 조회한 위치에서 오늘 태양이 뜨는 절대 시각입니다.
    let sunrise: Date?
    /// 조회한 위치에서 오늘 태양이 지는 절대 시각입니다.
    let sunset: Date?

    init(
        locationName: String,
        measuredAt: String,
        temperature: Double,
        pm25: Double,
        uvIndex: Double,
        windSpeed: Double = 0,
        windDirection: Double = 0,
        sunrise: Date? = nil,
        sunset: Date? = nil
    ) {
        self.locationName = locationName
        self.measuredAt = measuredAt
        self.temperature = temperature
        self.pm25 = pm25
        self.uvIndex = uvIndex
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.sunrise = sunrise
        self.sunset = sunset
    }

    /// 현재 시각이 일출 이상, 일몰 미만일 때만 태양 시각화를 표시합니다.
    /// 일출·일몰이 없는 테스트 데이터는 기존 동작을 유지하도록 낮으로 간주합니다.
    func isSunVisible(at date: Date = Date()) -> Bool {
        guard let sunrise, let sunset else { return true }
        return date >= sunrise && date < sunset
    }
}

/// 화면에서 사용하는 환경 데이터 로딩 상태입니다.
enum AirQualityLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
