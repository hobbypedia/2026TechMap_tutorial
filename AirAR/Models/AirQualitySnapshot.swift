import Foundation

/// 한 시점의 사용자 위치 대기 환경 데이터를 표현합니다.
struct AirQualitySnapshot: Equatable, Sendable {
    let locationName: String
    let measuredAt: String
    let temperature: Double
    /// 결합 서비스에서는 Open-Meteo 값이며, WeatherKit 단독 응답에서는 `nil`입니다.
    let pm25: Double?
    let uvIndex: Double
    /// 지상 10m 풍속이며 단위는 m/s입니다.
    let windSpeed: Double
    /// 바람이 불어오는 방향이며 정북을 0도로 한 시계 방향 각도입니다.
    let windDirection: Double
    /// Apple Weather 데이터 출처의 법적 고지 페이지입니다.
    let attributionURL: URL?
    /// 어두운 앱 화면에서 사용하는 Apple Weather 결합 마크입니다.
    let attributionMarkURL: URL?
    /// PM2.5를 제공한 Open-Meteo Air Quality API 안내 페이지입니다.
    let pm25SourceURL: URL?
    /// Open-Meteo 대기질 예측의 기반 데이터인 Copernicus CAMS 출처입니다.
    let pm25ModelSourceURL: URL?

    init(
        locationName: String,
        measuredAt: String,
        temperature: Double,
        pm25: Double? = nil,
        uvIndex: Double,
        windSpeed: Double = 0,
        windDirection: Double = 0,
        attributionURL: URL? = nil,
        attributionMarkURL: URL? = nil,
        pm25SourceURL: URL? = nil,
        pm25ModelSourceURL: URL? = nil
    ) {
        self.locationName = locationName
        self.measuredAt = measuredAt
        self.temperature = temperature
        self.pm25 = pm25
        self.uvIndex = uvIndex
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.attributionURL = attributionURL
        self.attributionMarkURL = attributionMarkURL
        self.pm25SourceURL = pm25SourceURL
        self.pm25ModelSourceURL = pm25ModelSourceURL
    }
}

/// 화면에서 사용하는 환경 데이터 로딩 상태입니다.
enum AirQualityLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
