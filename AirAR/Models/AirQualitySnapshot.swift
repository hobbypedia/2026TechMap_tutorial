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
    /// Weather와 Air Quality API 제공자인 Open-Meteo 출처입니다.
    let sourceURL: URL?
    /// 대기질 예측 기반 데이터인 Copernicus CAMS 출처입니다.
    let airQualityModelSourceURL: URL?

    init(
        locationName: String,
        measuredAt: String,
        temperature: Double,
        pm25: Double,
        uvIndex: Double,
        windSpeed: Double = 0,
        windDirection: Double = 0,
        sourceURL: URL? = nil,
        airQualityModelSourceURL: URL? = nil
    ) {
        self.locationName = locationName
        self.measuredAt = measuredAt
        self.temperature = temperature
        self.pm25 = pm25
        self.uvIndex = uvIndex
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.sourceURL = sourceURL
        self.airQualityModelSourceURL = airQualityModelSourceURL
    }
}

/// 화면에서 사용하는 환경 데이터 로딩 상태입니다.
enum AirQualityLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
