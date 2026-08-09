import Foundation
import XCTest
@testable import AirAR

final class WeatherKitEnvironmentServiceTests: XCTestCase {
    func testSuccessfulResponseMapsWeatherKitValues() async throws {
        let measuredAt = Date(timeIntervalSince1970: 1_785_816_000)
        let attributionURL = try XCTUnwrap(URL(string: "https://weatherkit.apple.com/legal-attribution.html"))
        let markURL = try XCTUnwrap(URL(string: "https://weatherkit.apple.com/assets/mark.png"))
        let provider = MockWeatherKitConditionsProvider(
            result: .success(
                WeatherKitConditions(
                    measuredAt: measuredAt,
                    temperature: 27.6,
                    uvIndex: 5,
                    windSpeed: 4.2,
                    windDirection: 315,
                    attributionURL: attributionURL,
                    attributionMarkURL: markURL
                )
            )
        )

        let snapshot = try await WeatherKitEnvironmentService(provider: provider)
            .fetchCurrentAirQuality(latitude: 35.1796, longitude: 129.0756)

        let coordinates = await provider.lastCoordinates
        XCTAssertEqual(coordinates?.latitude, 35.1796)
        XCTAssertEqual(coordinates?.longitude, 129.0756)
        XCTAssertEqual(snapshot.locationName, "현재 위치")
        XCTAssertEqual(snapshot.measuredAt, measuredAt.ISO8601Format())
        XCTAssertEqual(snapshot.temperature, 27.6)
        XCTAssertNil(snapshot.pm25)
        XCTAssertEqual(snapshot.uvIndex, 5)
        XCTAssertEqual(snapshot.windSpeed, 4.2)
        XCTAssertEqual(snapshot.windDirection, 315)
        XCTAssertEqual(snapshot.attributionURL, attributionURL)
        XCTAssertEqual(snapshot.attributionMarkURL, markURL)
    }

    func testProviderFailureMapsToWeatherKitError() async {
        let service = WeatherKitEnvironmentService(
            provider: MockWeatherKitConditionsProvider(result: .failure(.unavailable))
        )

        await assertThrows(.weatherKitFailed) {
            _ = try await service.fetchCurrentAirQuality(latitude: 0, longitude: 0)
        }
    }

    func testCancellationRemainsCancellation() async {
        let service = WeatherKitEnvironmentService(provider: CancellingWeatherKitConditionsProvider())

        await assertThrows(.cancelled) {
            _ = try await service.fetchCurrentAirQuality(latitude: 0, longitude: 0)
        }
    }

    private func assertThrows(
        _ expected: AirQualityServiceError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("오류가 발생해야 합니다.")
        } catch let error as AirQualityServiceError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("예상하지 못한 오류: \(error)")
        }
    }
}

private enum MockWeatherKitError: Error {
    case unavailable
}

private actor MockWeatherKitConditionsProvider: WeatherKitConditionsProviding {
    private let result: Result<WeatherKitConditions, MockWeatherKitError>
    private(set) var lastCoordinates: (latitude: Double, longitude: Double)?

    init(result: Result<WeatherKitConditions, MockWeatherKitError>) {
        self.result = result
    }

    func currentConditions(latitude: Double, longitude: Double) async throws -> WeatherKitConditions {
        lastCoordinates = (latitude, longitude)
        return try result.get()
    }
}

private struct CancellingWeatherKitConditionsProvider: WeatherKitConditionsProviding {
    func currentConditions(latitude: Double, longitude: Double) async throws -> WeatherKitConditions {
        throw CancellationError()
    }
}
