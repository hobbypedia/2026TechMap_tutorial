import Foundation

/// Open-Meteo 응답 전용 DTO입니다.
struct AirQualityAPIResponse: Decodable, Sendable {
    struct Current: Decodable, Sendable {
        let time: String
        let pm25: Double
        let uvIndex: Double

        enum CodingKeys: String, CodingKey {
            case time
            case pm25 = "pm2_5"
            case uvIndex = "uv_index"
        }
    }

    let current: Current
}

/// Open-Meteo Forecast API의 현재 기온과 지상 10m 바람 응답 DTO입니다.
struct WeatherForecastAPIResponse: Decodable, Sendable {
    struct Current: Decodable, Sendable {
        let temperature: Double
        let windSpeed: Double
        let windDirection: Double

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case windSpeed = "wind_speed_10m"
            case windDirection = "wind_direction_10m"
        }
    }

    let current: Current
}
