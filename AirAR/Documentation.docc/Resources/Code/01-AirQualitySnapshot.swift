import Foundation

struct AirQualitySnapshot: Equatable, Sendable {
    let locationName: String
    let measuredAt: String
    let temperature: Double
    let pm25: Double
    let uvIndex: Double
    let windSpeed: Double
    let windDirection: Double
    let sourceURL: URL?
    let airQualityModelSourceURL: URL?
}
