import Foundation

/// Open-Meteo의 Weather와 Air Quality REST API에서 현재 환경 데이터를 가져옵니다.
final class OpenMeteoEnvironmentService: AirQualityServiceProtocol, @unchecked Sendable {
    static let weatherEndpoint = "https://api.open-meteo.com/v1/forecast"
    static let airQualityEndpoint = "https://air-quality-api.open-meteo.com/v1/air-quality"
    static let sourceURL = URL(string: "https://open-meteo.com/")!
    static let airQualityModelSourceURL = URL(string: "https://atmosphere.copernicus.eu/")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 같은 좌표를 사용하는 두 REST API GET 요청을 병렬 실행해 하나의 스냅샷으로 합칩니다.
    func fetchCurrentAirQuality(
        latitude: Double,
        longitude: Double
    ) async throws -> AirQualitySnapshot {
        do {
            let coordinateItems = [
                URLQueryItem(name: "latitude", value: String(latitude)),
                URLQueryItem(name: "longitude", value: String(longitude)),
                URLQueryItem(name: "timezone", value: "auto")
            ]
            let weatherURL = try makeURL(
                endpoint: Self.weatherEndpoint,
                queryItems: coordinateItems + [
                    URLQueryItem(
                        name: "current",
                        value: "temperature_2m,wind_speed_10m,wind_direction_10m"
                    ),
                    URLQueryItem(name: "daily", value: "sunrise,sunset"),
                    URLQueryItem(name: "forecast_days", value: "1"),
                    URLQueryItem(name: "wind_speed_unit", value: "ms")
                ]
            )
            let airQualityURL = try makeURL(
                endpoint: Self.airQualityEndpoint,
                queryItems: coordinateItems + [
                    URLQueryItem(name: "current", value: "pm2_5,uv_index")
                ]
            )

            async let weather: OpenMeteoWeatherResponse = request(
                OpenMeteoWeatherResponse.self,
                from: weatherURL
            )
            async let airQuality: OpenMeteoAirQualityResponse = request(
                OpenMeteoAirQualityResponse.self,
                from: airQualityURL
            )
            let (weatherResponse, airQualityResponse) = try await (weather, airQuality)
            let (sunrise, sunset) = try makeSunTimes(from: weatherResponse)

            return AirQualitySnapshot(
                locationName: "현재 위치",
                measuredAt: airQualityResponse.current.time,
                temperature: weatherResponse.current.temperature,
                pm25: airQualityResponse.current.pm25,
                uvIndex: airQualityResponse.current.uvIndex,
                windSpeed: weatherResponse.current.windSpeed,
                windDirection: weatherResponse.current.windDirection,
                sunrise: sunrise,
                sunset: sunset,
                sourceURL: Self.sourceURL,
                airQualityModelSourceURL: Self.airQualityModelSourceURL
            )
        } catch is CancellationError {
            throw AirQualityServiceError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw AirQualityServiceError.cancelled
        } catch let error as AirQualityServiceError {
            throw error
        } catch {
            throw AirQualityServiceError.networkFailed
        }
    }

    /// `timezone=auto`로 받은 현지 ISO 8601 문자열을 절대 시각으로 변환합니다.
    private func makeSunTimes(from response: OpenMeteoWeatherResponse) throws -> (Date, Date) {
        guard let sunriseText = response.daily.sunrise.first,
              let sunsetText = response.daily.sunset.first else {
            throw AirQualityServiceError.decodingFailed
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = TimeZone(identifier: response.timezone)
            ?? TimeZone(secondsFromGMT: response.utcOffsetSeconds)

        guard let sunrise = formatter.date(from: sunriseText),
              let sunset = formatter.date(from: sunsetText),
              sunrise < sunset else {
            throw AirQualityServiceError.decodingFailed
        }
        return (sunrise, sunset)
    }

    private func makeURL(endpoint: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: endpoint) else {
            throw AirQualityServiceError.invalidURL
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw AirQualityServiceError.invalidURL
        }
        return url
    }

    private func request<Response: Decodable>(
        _ type: Response.Type,
        from url: URL
    ) async throws -> Response {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AirQualityServiceError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AirQualityServiceError.httpError(httpResponse.statusCode)
        }
        do {
            // 두 요청이 동시에 완료돼도 Decoder 인스턴스를 공유하지 않습니다.
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AirQualityServiceError.decodingFailed
        }
    }
}
