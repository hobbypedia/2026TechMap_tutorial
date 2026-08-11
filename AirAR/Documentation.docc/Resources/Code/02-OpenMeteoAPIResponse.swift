struct OpenMeteoAirQualityResponse: Decodable {
    struct Current: Decodable {
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

struct OpenMeteoWeatherResponse: Decodable {
    struct Current: Decodable {
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

    struct Daily: Decodable {
        let sunrise: [String]
        let sunset: [String]
    }

    let current: Current
    let daily: Daily
    let timezone: String
    let utcOffsetSeconds: Int

    enum CodingKeys: String, CodingKey {
        case current, daily, timezone
        case utcOffsetSeconds = "utc_offset_seconds"
    }
}
