import Foundation

struct AirQualitySnapshot: Equatable, Sendable {
    let locationName: String
    let measuredAt: String
    let temperature: Double
    let pm25: Double?
    let uvIndex: Double
    let windSpeed: Double
    let windDirection: Double
    let attributionURL: URL?
    let attributionMarkURL: URL?
    let pm25SourceURL: URL?
    let pm25ModelSourceURL: URL?
}
