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

return AirQualitySnapshot(
    locationName: "현재 위치",
    measuredAt: airResponse.current.time,
    temperature: weatherResponse.current.temperature,
    pm25: airResponse.current.pm25,
    uvIndex: airResponse.current.uvIndex,
    windSpeed: weatherResponse.current.windSpeed,
    windDirection: weatherResponse.current.windDirection
)
