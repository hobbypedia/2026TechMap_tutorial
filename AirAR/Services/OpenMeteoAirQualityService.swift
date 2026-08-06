import Foundation

/// Open-Meteo의 무료 Weather/Air Quality REST API에서 지정 좌표의 환경 데이터를 가져옵니다.
final class OpenMeteoAirQualityService: AirQualityServiceProtocol, @unchecked Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    /// 지정한 좌표의 현재 기온, 지상 바람, PM2.5와 UV Index를 병렬로 요청합니다.
    /// - Parameters:
    ///   - latitude: 조회할 위도입니다.
    ///   - longitude: 조회할 경도입니다.
    /// - Returns: 좌표와 측정 시각을 포함한 스냅샷입니다. 지역 이름은 위치 서비스 계층에서 보완합니다.
    /// - Throws: URL, HTTP, 응답, 디코딩, 네트워크 및 취소 오류를 구분해 던집니다.
    func fetchCurrentAirQuality(
        latitude: Double,
        longitude: Double
    ) async throws -> AirQualitySnapshot {
        do {
            let coordinateItems = [
                URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
                URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
                URLQueryItem(name: "timezone", value: "auto")
            ]
            let airURL = try makeURL(
                base: "https://air-quality-api.open-meteo.com/v1/air-quality",
                queryItems: coordinateItems + [URLQueryItem(name: "current", value: "pm2_5,uv_index")]
            )
            let weatherURL = try makeURL(
                base: "https://api.open-meteo.com/v1/forecast",
                queryItems: coordinateItems + [
                    URLQueryItem(
                        name: "current",
                        value: "temperature_2m,wind_speed_10m,wind_direction_10m"
                    ),
                    URLQueryItem(name: "wind_speed_unit", value: "ms")
                ]
            )

            async let airResponse: AirQualityAPIResponse = fetch(AirQualityAPIResponse.self, from: airURL)
            async let weatherResponse: WeatherForecastAPIResponse = fetch(WeatherForecastAPIResponse.self, from: weatherURL)
            let (air, weather) = try await (airResponse, weatherResponse)

            return AirQualitySnapshot(
                locationName: "현재 위치",
                measuredAt: air.current.time,
                temperature: weather.current.temperature,
                pm25: air.current.pm25,
                uvIndex: air.current.uvIndex,
                windSpeed: weather.current.windSpeed,
                windDirection: weather.current.windDirection
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

    private func makeURL(base: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: base) else {
            throw AirQualityServiceError.invalidURL
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw AirQualityServiceError.invalidURL
        }
        return url
    }

    private func fetch<Response: Decodable>(
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
            return try decoder.decode(type, from: data)
        } catch {
            throw AirQualityServiceError.decodingFailed
        }
    }
}
