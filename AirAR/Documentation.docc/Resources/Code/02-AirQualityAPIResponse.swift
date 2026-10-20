import Foundation

/// A data transfer object for Open-Meteo responses.
/// Open-Meteo 응답 전용 DTO입니다.
struct AirQualityAPIResponse: Decodable, Sendable {
    struct Current: Decodable, Sendable {
        let time: String
        let pm25: Double
        let uvIndex: Double

        // Map API JSON field names to Swift property names during decoding.
        // 디코딩할 때 API JSON 필드 이름을 Swift 속성 이름에 연결합니다.
        enum CodingKeys: String, CodingKey {
            case time
            case pm25 = "pm2_5"
            case uvIndex = "uv_index"
        }
    }

    let current: Current
}

/// A response DTO for current temperature and wind at 10 m from the Open-Meteo Forecast API.
/// Open-Meteo Forecast API의 현재 기온과 지상 10m 바람 응답 DTO입니다.
struct WeatherForecastAPIResponse: Decodable, Sendable {
    struct Current: Decodable, Sendable {
        let time: String
        let temperature: Double
        let windSpeed: Double
        let windDirection: Double

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case windSpeed = "wind_speed_10m"
            case windDirection = "wind_direction_10m"
        }
    }

    struct Daily: Decodable, Sendable {
        let sunrise: [String]
        let sunset: [String]
    }

    let current: Current
    let daily: Daily
    let timezone: String
    let utcOffsetSeconds: Int

    enum CodingKeys: String, CodingKey {
        case current
        case daily
        case timezone
        case utcOffsetSeconds = "utc_offset_seconds"
    }
}
