import CoreLocation
import WeatherKit

let location = CLLocation(latitude: latitude, longitude: longitude)
async let current: CurrentWeather = WeatherService.shared.weather(
    for: location,
    including: .current
)
async let attribution: WeatherAttribution = WeatherService.shared.attribution
let (weather, weatherAttribution) = try await (current, attribution)

return AirQualitySnapshot(
    locationName: "현재 위치",
    measuredAt: weather.date.ISO8601Format(),
    temperature: weather.temperature.converted(to: .celsius).value,
    pm25: nil,
    uvIndex: Double(weather.uvIndex.value),
    windSpeed: weather.wind.speed.converted(to: .metersPerSecond).value,
    windDirection: weather.wind.direction.converted(to: .degrees).value,
    attributionURL: weatherAttribution.legalPageURL,
    attributionMarkURL: weatherAttribution.combinedMarkLightURL
)
