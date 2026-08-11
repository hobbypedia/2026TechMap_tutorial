private func request<Response: Decodable>(
    _ type: Response.Type,
    from url: URL
) async throws -> Response {
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse else {
        throw AirQualityServiceError.invalidResponse
    }
    guard (200...299).contains(http.statusCode) else {
        throw AirQualityServiceError.httpError(http.statusCode)
    }
    return try JSONDecoder().decode(type, from: data)
}

async let weather = request(OpenMeteoWeatherResponse.self, from: weatherURL)
async let air = request(OpenMeteoAirQualityResponse.self, from: airQualityURL)
let (weatherResponse, airResponse) = try await (weather, air)

let formatter = DateFormatter()
formatter.locale = Locale(identifier: "en_US_POSIX")
formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
formatter.timeZone = TimeZone(identifier: weatherResponse.timezone)
    ?? TimeZone(secondsFromGMT: weatherResponse.utcOffsetSeconds)

guard let sunriseText = weatherResponse.daily.sunrise.first,
      let sunsetText = weatherResponse.daily.sunset.first,
      let sunrise = formatter.date(from: sunriseText),
      let sunset = formatter.date(from: sunsetText) else {
    throw AirQualityServiceError.decodingFailed
}

return AirQualitySnapshot(
    locationName: "현재 위치",
    measuredAt: airResponse.current.time,
    temperature: weatherResponse.current.temperature,
    pm25: airResponse.current.pm25,
    uvIndex: airResponse.current.uvIndex,
    windSpeed: weatherResponse.current.windSpeed,
    windDirection: weatherResponse.current.windDirection,
    sunrise: sunrise,
    sunset: sunset
)
