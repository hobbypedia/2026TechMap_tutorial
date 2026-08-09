import CoreLocation
import Foundation
import WeatherKit

/// WeatherKit 타입을 앱 모델과 테스트 가능한 값으로 분리한 현재 기상 조건입니다.
struct WeatherKitConditions: Equatable, Sendable {
    let measuredAt: Date
    let temperature: Double
    let uvIndex: Double
    let windSpeed: Double
    let windDirection: Double
    let attributionURL: URL
    let attributionMarkURL: URL
}

/// WeatherKit 프레임워크 호출 경계를 추상화합니다.
protocol WeatherKitConditionsProviding: Sendable {
    func currentConditions(latitude: Double, longitude: Double) async throws -> WeatherKitConditions
}

/// Apple Weather의 현재 기상 조건과 필수 출처 정보를 가져옵니다.
struct AppleWeatherKitConditionsProvider: WeatherKitConditionsProviding {
    private let service: WeatherService

    init(service: WeatherService = .shared) {
        self.service = service
    }

    func currentConditions(
        latitude: Double,
        longitude: Double
    ) async throws -> WeatherKitConditions {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        async let current: CurrentWeather = service.weather(for: location, including: .current)
        async let attribution: WeatherAttribution = service.attribution
        let (weather, weatherAttribution) = try await (current, attribution)

        return WeatherKitConditions(
            measuredAt: weather.date,
            temperature: weather.temperature.converted(to: .celsius).value,
            uvIndex: Double(weather.uvIndex.value),
            windSpeed: weather.wind.speed.converted(to: .metersPerSecond).value,
            windDirection: weather.wind.direction.converted(to: .degrees).value,
            attributionURL: weatherAttribution.legalPageURL,
            attributionMarkURL: weatherAttribution.combinedMarkLightURL
        )
    }
}

/// URL을 직접 구성하지 않고 Apple WeatherKit Swift API로 현재 환경 데이터를 가져옵니다.
final class WeatherKitEnvironmentService: AirQualityServiceProtocol {
    private let provider: any WeatherKitConditionsProviding

    init(provider: any WeatherKitConditionsProviding = AppleWeatherKitConditionsProvider()) {
        self.provider = provider
    }

    func fetchCurrentAirQuality(
        latitude: Double,
        longitude: Double
    ) async throws -> AirQualitySnapshot {
        do {
            let conditions = try await provider.currentConditions(
                latitude: latitude,
                longitude: longitude
            )
            return AirQualitySnapshot(
                locationName: "현재 위치",
                measuredAt: conditions.measuredAt.ISO8601Format(),
                temperature: conditions.temperature,
                pm25: nil,
                uvIndex: conditions.uvIndex,
                windSpeed: conditions.windSpeed,
                windDirection: conditions.windDirection,
                attributionURL: conditions.attributionURL,
                attributionMarkURL: conditions.attributionMarkURL
            )
        } catch is CancellationError {
            throw AirQualityServiceError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw AirQualityServiceError.cancelled
        } catch {
            throw AirQualityServiceError.weatherKitFailed
        }
    }
}
