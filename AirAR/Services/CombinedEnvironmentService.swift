import Foundation

/// WeatherKit 기상 데이터와 Open-Meteo PM2.5를 병렬로 결합합니다.
final class CombinedEnvironmentService: AirQualityServiceProtocol {
    private let weatherProvider: any WeatherKitConditionsProviding
    private let pm25Provider: any PM25Providing

    init(
        weatherProvider: any WeatherKitConditionsProviding = AppleWeatherKitConditionsProvider(),
        pm25Provider: any PM25Providing = OpenMeteoPM25Provider()
    ) {
        self.weatherProvider = weatherProvider
        self.pm25Provider = pm25Provider
    }

    func fetchCurrentAirQuality(
        latitude: Double,
        longitude: Double
    ) async throws -> AirQualitySnapshot {
        do {
            async let weather = fetchWeather(
                latitude: latitude,
                longitude: longitude
            )
            async let pm25 = fetchPM25(
                latitude: latitude,
                longitude: longitude
            )
            let (conditions, pm25Reading) = try await (weather, pm25)

            return AirQualitySnapshot(
                locationName: "현재 위치",
                measuredAt: conditions.measuredAt.ISO8601Format(),
                temperature: conditions.temperature,
                pm25: pm25Reading.value,
                uvIndex: conditions.uvIndex,
                windSpeed: conditions.windSpeed,
                windDirection: conditions.windDirection,
                attributionURL: conditions.attributionURL,
                attributionMarkURL: conditions.attributionMarkURL,
                pm25SourceURL: pm25Reading.sourceURL,
                pm25ModelSourceURL: pm25Reading.modelSourceURL
            )
        } catch is CancellationError {
            throw AirQualityServiceError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw AirQualityServiceError.cancelled
        } catch let error as AirQualityServiceError {
            throw error
        } catch {
            throw AirQualityServiceError.weatherKitFailed
        }
    }

    private func fetchWeather(
        latitude: Double,
        longitude: Double
    ) async throws -> WeatherKitConditions {
        do {
            return try await weatherProvider.currentConditions(
                latitude: latitude,
                longitude: longitude
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AirQualityServiceError.weatherKitFailed
        }
    }

    private func fetchPM25(latitude: Double, longitude: Double) async throws -> PM25Reading {
        do {
            return try await pm25Provider.currentPM25(latitude: latitude, longitude: longitude)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AirQualityServiceError.airQualityFailed
        }
    }
}
