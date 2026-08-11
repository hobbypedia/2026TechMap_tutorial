import XCTest
@testable import AirAR

final class OpenMeteoAirQualityServiceTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }

    func testSuccessfulResponseMapsValues() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.scheme, "https")
            let components = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
            let query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) })
            XCTAssertEqual(query["latitude"], "35.1796")
            XCTAssertEqual(query["longitude"], "129.0756")
            XCTAssertEqual(query["timezone"], "auto")
            if request.url?.host == "api.open-meteo.com" {
                XCTAssertEqual(
                    query["current"],
                    "temperature_2m,wind_speed_10m,wind_direction_10m"
                )
                XCTAssertEqual(query["wind_speed_unit"], "ms")
                let json = #"{"current":{"temperature_2m":27.6,"wind_speed_10m":4.2,"wind_direction_10m":315}}"#
                return (200, Data(json.utf8))
            }
            XCTAssertTrue(request.url?.absoluteString.contains("current=pm2_5,uv_index") == true)
            let json = #"{"current":{"time":"2026-08-04T12:00","pm2_5":13.4,"uv_index":5.2}}"#
            return (200, Data(json.utf8))
        }

        let snapshot = try await makeService().fetchCurrentAirQuality(latitude: 35.1796, longitude: 129.0756)

        XCTAssertEqual(snapshot.locationName, "현재 위치")
        XCTAssertEqual(snapshot.measuredAt, "2026-08-04T12:00")
        XCTAssertEqual(snapshot.temperature, 27.6)
        XCTAssertEqual(snapshot.pm25, 13.4)
        XCTAssertEqual(snapshot.uvIndex, 5.2)
        XCTAssertEqual(snapshot.windSpeed, 4.2)
        XCTAssertEqual(snapshot.windDirection, 315)
    }

    func testMissingFieldThrowsDecodingError() async {
        URLProtocolStub.handler = { request in
            if request.url?.host == "api.open-meteo.com" {
                let json = #"{"current":{"temperature_2m":27.6,"wind_speed_10m":4.2,"wind_direction_10m":315}}"#
                return (200, Data(json.utf8))
            }
            return (200, Data(#"{"current":{"time":"2026-08-04T12:00","pm2_5":13.4}}"#.utf8))
        }
        await assertThrows(.decodingFailed) {
            _ = try await self.makeService().fetchCurrentAirQuality(latitude: 0, longitude: 0)
        }
    }

    func testInvalidJSONThrowsDecodingError() async {
        URLProtocolStub.handler = { request in
            if request.url?.host == "api.open-meteo.com" {
                let json = #"{"current":{"temperature_2m":27.6,"wind_speed_10m":4.2,"wind_direction_10m":315}}"#
                return (200, Data(json.utf8))
            }
            return (200, Data("not-json".utf8))
        }
        await assertThrows(.decodingFailed) {
            _ = try await self.makeService().fetchCurrentAirQuality(latitude: 0, longitude: 0)
        }
    }

    func testHTTPErrorKeepsStatusCode() async {
        URLProtocolStub.handler = { request in
            if request.url?.host == "api.open-meteo.com" {
                let json = #"{"current":{"temperature_2m":27.6,"wind_speed_10m":4.2,"wind_direction_10m":315}}"#
                return (200, Data(json.utf8))
            }
            return (503, Data())
        }
        await assertThrows(.httpError(503)) {
            _ = try await self.makeService().fetchCurrentAirQuality(latitude: 0, longitude: 0)
        }
    }

    private func makeService() -> OpenMeteoAirQualityService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return OpenMeteoAirQualityService(session: URLSession(configuration: configuration))
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

private final class URLProtocolStub: URLProtocol {
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
