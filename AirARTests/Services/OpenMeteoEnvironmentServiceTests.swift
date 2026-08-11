import Foundation
import XCTest
@testable import AirAR

final class OpenMeteoEnvironmentServiceTests: XCTestCase {
    override func tearDown() {
        OpenMeteoURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testSuccessfulResponsesMapAllEnvironmentValues() async throws {
        OpenMeteoURLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.scheme, "https")
            let url = try XCTUnwrap(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let query = Dictionary(
                uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) }
            )
            XCTAssertEqual(query["latitude"], "35.1796")
            XCTAssertEqual(query["longitude"], "129.0756")
            XCTAssertEqual(query["timezone"], "auto")

            if request.url?.host == "api.open-meteo.com" {
                XCTAssertEqual(
                    query["current"],
                    "temperature_2m,wind_speed_10m,wind_direction_10m"
                )
                XCTAssertEqual(query["daily"], "sunrise,sunset")
                XCTAssertEqual(query["forecast_days"], "1")
                XCTAssertEqual(query["wind_speed_unit"], "ms")
                let json = #"{"timezone":"Asia/Seoul","utc_offset_seconds":32400,"current":{"time":"2026-08-09T18:45","temperature_2m":27.6,"wind_speed_10m":4.2,"wind_direction_10m":315},"daily":{"sunrise":["2026-08-09T05:40"],"sunset":["2026-08-09T19:25"]}}"#
                return (200, Data(json.utf8))
            }

            XCTAssertEqual(request.url?.host, "air-quality-api.open-meteo.com")
            XCTAssertEqual(query["current"], "pm2_5,uv_index")
            let json = #"{"current":{"time":"2026-08-09T18:45","pm2_5":13.4,"uv_index":5.2}}"#
            return (200, Data(json.utf8))
        }

        let snapshot = try await makeService().fetchCurrentAirQuality(
            latitude: 35.1796,
            longitude: 129.0756
        )

        XCTAssertEqual(snapshot.locationName, "현재 위치")
        XCTAssertEqual(snapshot.measuredAt, "2026-08-09T18:45")
        XCTAssertEqual(snapshot.temperature, 27.6)
        XCTAssertEqual(snapshot.pm25, 13.4)
        XCTAssertEqual(snapshot.uvIndex, 5.2)
        XCTAssertEqual(snapshot.windSpeed, 4.2)
        XCTAssertEqual(snapshot.windDirection, 315)
        let sunrise = try XCTUnwrap(snapshot.sunrise)
        let sunset = try XCTUnwrap(snapshot.sunset)
        XCTAssertEqual(
            sunrise,
            try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-08T20:40:00Z"))
        )
        XCTAssertEqual(
            sunset,
            try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-09T10:25:00Z"))
        )
        XCTAssertFalse(snapshot.isSunVisible(at: sunrise.addingTimeInterval(-1)))
        XCTAssertTrue(snapshot.isSunVisible(at: sunrise))
        XCTAssertTrue(snapshot.isSunVisible(at: sunset.addingTimeInterval(-1)))
        XCTAssertFalse(snapshot.isSunVisible(at: sunset))
        XCTAssertEqual(snapshot.sourceURL?.host, "open-meteo.com")
        XCTAssertEqual(snapshot.airQualityModelSourceURL?.host, "atmosphere.copernicus.eu")
    }

    func testMissingJSONFieldThrowsDecodingError() async {
        OpenMeteoURLProtocolStub.handler = { request in
            if request.url?.host == "api.open-meteo.com" {
                let json = #"{"timezone":"Asia/Seoul","utc_offset_seconds":32400,"current":{"time":"2026-08-09T18:45","temperature_2m":27.6,"wind_speed_10m":4.2,"wind_direction_10m":315},"daily":{"sunrise":["2026-08-09T05:40"],"sunset":["2026-08-09T19:25"]}}"#
                return (200, Data(json.utf8))
            }
            return (200, Data(#"{"current":{"time":"2026-08-09T18:45","pm2_5":13.4}}"#.utf8))
        }

        await assertThrows(.decodingFailed) {
            _ = try await self.makeService().fetchCurrentAirQuality(latitude: 0, longitude: 0)
        }
    }

    func testHTTPErrorKeepsStatusCode() async {
        OpenMeteoURLProtocolStub.handler = { request in
            if request.url?.host == "api.open-meteo.com" {
                let json = #"{"timezone":"Asia/Seoul","utc_offset_seconds":32400,"current":{"time":"2026-08-09T18:45","temperature_2m":27.6,"wind_speed_10m":4.2,"wind_direction_10m":315},"daily":{"sunrise":["2026-08-09T05:40"],"sunset":["2026-08-09T19:25"]}}"#
                return (200, Data(json.utf8))
            }
            return (503, Data())
        }

        await assertThrows(.httpError(503)) {
            _ = try await self.makeService().fetchCurrentAirQuality(latitude: 0, longitude: 0)
        }
    }

    func testCancelledURLRequestMapsToCancellation() async {
        OpenMeteoURLProtocolStub.handler = { _ in
            throw URLError(.cancelled)
        }

        await assertThrows(.cancelled) {
            _ = try await self.makeService().fetchCurrentAirQuality(latitude: 0, longitude: 0)
        }
    }

    private func makeService() -> OpenMeteoEnvironmentService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenMeteoURLProtocolStub.self]
        return OpenMeteoEnvironmentService(session: URLSession(configuration: configuration))
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

private final class OpenMeteoURLProtocolStub: URLProtocol {
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
