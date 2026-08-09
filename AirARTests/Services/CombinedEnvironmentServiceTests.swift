import Foundation
import XCTest
@testable import AirAR

final class CombinedEnvironmentServiceTests: XCTestCase {
    override func tearDown() {
        PM25URLProtocolStub.handler = nil
        super.tearDown()
    }

    func testOpenMeteoProviderRequestsOnlyCurrentPM25() async throws {
        PM25URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.host, "air-quality-api.open-meteo.com")
            let url = try XCTUnwrap(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let query = Dictionary(
                uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) }
            )
            XCTAssertEqual(query["latitude"], "35.1796")
            XCTAssertEqual(query["longitude"], "129.0756")
            XCTAssertEqual(query["current"], "pm2_5")
            XCTAssertEqual(query["timezone"], "auto")
            return (200, Data(#"{"current":{"time":"2026-08-08T14:15","pm2_5":13.4}}"#.utf8))
        }

        let reading = try await makeOpenMeteoProvider()
            .currentPM25(latitude: 35.1796, longitude: 129.0756)

        XCTAssertEqual(reading.value, 13.4)
        XCTAssertEqual(reading.measuredAt, "2026-08-08T14:15")
        XCTAssertEqual(reading.sourceURL.host, "open-meteo.com")
        XCTAssertEqual(reading.modelSourceURL.host, "atmosphere.copernicus.eu")
    }

    func testOpenMeteoHTTPErrorKeepsStatusCode() async {
        PM25URLProtocolStub.handler = { _ in (503, Data()) }

        do {
            _ = try await makeOpenMeteoProvider().currentPM25(latitude: 0, longitude: 0)
            XCTFail("오류가 발생해야 합니다.")
        } catch let error as PM25ProviderError {
            XCTAssertEqual(error, .httpError(503))
        } catch {
            XCTFail("예상하지 못한 오류: \(error)")
        }
    }

    func testCombinedServiceMergesWeatherKitAndPM25() async throws {
        let service = CombinedEnvironmentService(
            weatherProvider: MockCombinedWeatherProvider(result: .success(makeWeather())),
            pm25Provider: MockPM25Provider(result: .success(makePM25()))
        )

        let snapshot = try await service.fetchCurrentAirQuality(latitude: 37.5, longitude: 127)

        XCTAssertEqual(snapshot.temperature, 27.6)
        XCTAssertEqual(snapshot.pm25, 13.4)
        XCTAssertEqual(snapshot.uvIndex, 5)
        XCTAssertEqual(snapshot.windSpeed, 4.2)
        XCTAssertEqual(snapshot.windDirection, 315)
        XCTAssertNotNil(snapshot.attributionURL)
        XCTAssertNotNil(snapshot.pm25SourceURL)
        XCTAssertNotNil(snapshot.pm25ModelSourceURL)
    }

    func testPM25FailureMapsToAirQualityError() async {
        let service = CombinedEnvironmentService(
            weatherProvider: MockCombinedWeatherProvider(result: .success(makeWeather())),
            pm25Provider: MockPM25Provider(result: .failure(.networkFailed))
        )

        await assertThrows(.airQualityFailed, service: service)
    }

    func testWeatherFailureMapsToWeatherKitError() async {
        let service = CombinedEnvironmentService(
            weatherProvider: MockCombinedWeatherProvider(result: .failure(.unavailable)),
            pm25Provider: MockPM25Provider(result: .success(makePM25()))
        )

        await assertThrows(.weatherKitFailed, service: service)
    }

    private func makeOpenMeteoProvider() -> OpenMeteoPM25Provider {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PM25URLProtocolStub.self]
        return OpenMeteoPM25Provider(session: URLSession(configuration: configuration))
    }

    private func makeWeather() -> WeatherKitConditions {
        WeatherKitConditions(
            measuredAt: Date(timeIntervalSince1970: 1_785_816_000),
            temperature: 27.6,
            uvIndex: 5,
            windSpeed: 4.2,
            windDirection: 315,
            attributionURL: URL(string: "https://weatherkit.apple.com/legal")!,
            attributionMarkURL: URL(string: "https://weatherkit.apple.com/mark")!
        )
    }

    private func makePM25() -> PM25Reading {
        PM25Reading(
            value: 13.4,
            measuredAt: "2026-08-08T14:15",
            sourceURL: URL(string: "https://open-meteo.com/en/docs/air-quality-api")!,
            modelSourceURL: URL(string: "https://atmosphere.copernicus.eu/")!
        )
    }

    private func assertThrows(
        _ expected: AirQualityServiceError,
        service: CombinedEnvironmentService
    ) async {
        do {
            _ = try await service.fetchCurrentAirQuality(latitude: 0, longitude: 0)
            XCTFail("오류가 발생해야 합니다.")
        } catch let error as AirQualityServiceError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("예상하지 못한 오류: \(error)")
        }
    }
}

private enum CombinedMockError: Error {
    case unavailable
}

private struct MockCombinedWeatherProvider: WeatherKitConditionsProviding {
    let result: Result<WeatherKitConditions, CombinedMockError>

    func currentConditions(latitude: Double, longitude: Double) async throws -> WeatherKitConditions {
        try result.get()
    }
}

private struct MockPM25Provider: PM25Providing {
    let result: Result<PM25Reading, PM25ProviderError>

    func currentPM25(latitude: Double, longitude: Double) async throws -> PM25Reading {
        try result.get()
    }
}

private final class PM25URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (statusCode, data) = try handler(request)
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                  ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
