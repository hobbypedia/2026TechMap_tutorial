import Foundation

struct AirQualitySnapshot: Equatable, Sendable {
    let locationName: String
    let measuredAt: String
    let temperature: Double
    let pm25: Double
    let uvIndex: Double
    let windSpeed: Double
    let windDirection: Double
    let sunrise: Date?
    let sunset: Date?

    func isSunVisible(at date: Date = Date()) -> Bool {
        guard let sunrise, let sunset else { return true }
        return date >= sunrise && date < sunset
    }
}
