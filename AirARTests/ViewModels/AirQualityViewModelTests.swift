import XCTest
@testable import AirAR

@MainActor
final class AirQualityViewModelTests: XCTestCase {
    func testInitialStateIsIdle() {
        let viewModel = makeViewModel(service: MockAirQualityService(results: []))
        XCTAssertEqual(viewModel.loadState, .idle)
        XCTAssertNil(viewModel.snapshot)
    }

    func testLoadShowsLoadingThenLoaded() async {
        let expected = makeSnapshot()
        let service = MockAirQualityService(results: [.success(expected)], delayNanoseconds: 30_000_000)
        let viewModel = makeViewModel(service: service)

        viewModel.load()
        XCTAssertEqual(viewModel.loadState, .loading)
        await waitUntil { viewModel.loadState == .loaded }

        XCTAssertEqual(viewModel.snapshot, expected)
    }

    func testFailureAndRetry() async {
        let expected = makeSnapshot()
        let service = MockAirQualityService(results: [.failure(.weatherKitFailed), .success(expected)])
        let viewModel = makeViewModel(service: service)

        viewModel.load()
        await waitUntil {
            if case .failed = viewModel.loadState { return true }
            return false
        }
        viewModel.retry()
        await waitUntil { viewModel.loadState == .loaded }

        XCTAssertEqual(viewModel.snapshot, expected)
    }

    func testDuplicateLoadDoesNotStartSecondRequest() async {
        let service = MockAirQualityService(results: [.success(makeSnapshot())], delayNanoseconds: 80_000_000)
        let viewModel = makeViewModel(service: service)

        viewModel.load()
        viewModel.load()
        await waitUntil { viewModel.loadState == .loaded }

        let requestCount = await service.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testRefreshIgnoresCancelledRequestResult() async {
        let stale = AirQualitySnapshot(locationName: "서울특별시 종로구", measuredAt: "이전", temperature: 30, pm25: 99, uvIndex: 9)
        let fresh = AirQualitySnapshot(locationName: "서울특별시 종로구", measuredAt: "최신", temperature: 26, pm25: 7, uvIndex: 2)
        let service = MockAirQualityService(
            results: [.success(stale), .success(fresh)],
            delayNanoseconds: 60_000_000,
            ignoresCancellation: true
        )
        let viewModel = makeViewModel(service: service)

        viewModel.load()
        try? await Task.sleep(nanoseconds: 5_000_000)
        viewModel.refresh()
        await waitUntil { viewModel.loadState == .loaded }

        XCTAssertEqual(viewModel.snapshot, fresh)
    }

    func testLoadedSnapshotProducesFormattedMetricsAndLevels() async {
        let service = MockAirQualityService(results: [.success(makeSnapshot())])
        let viewModel = makeViewModel(service: service)

        viewModel.load()
        await waitUntil { viewModel.loadState == .loaded }

        XCTAssertEqual(viewModel.metrics.map(\.value), ["27.0°", "8.0", "3.0"])
        XCTAssertEqual(viewModel.metrics.map(\.level), [nil, .good, .good])
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testMissingPM25IsShownAsUnavailable() async {
        let snapshot = AirQualitySnapshot(
            locationName: "서울특별시 종로구",
            measuredAt: "2026-08-04T12:00:00Z",
            temperature: 27,
            uvIndex: 3
        )
        let viewModel = makeViewModel(
            service: MockAirQualityService(results: [.success(snapshot)])
        )

        viewModel.load()
        await waitUntil { viewModel.loadState == .loaded }

        XCTAssertEqual(viewModel.metrics.map(\.value), ["27.0°", "미제공", "3.0"])
        XCTAssertNil(viewModel.metrics[1].level)
    }

    func testCurrentLocationCoordinatesAreUsedAndNameOverridesAPIPlaceholder() async {
        let response = AirQualitySnapshot(
            locationName: "현재 위치",
            measuredAt: "2026-08-04T12:00",
            temperature: 27,
            pm25: 8,
            uvIndex: 3,
            windSpeed: 5.4,
            windDirection: 225
        )
        let service = MockAirQualityService(results: [.success(response)])
        let location = UserLocation(latitude: 35.1796, longitude: 129.0756, displayName: "부산광역시 중구")
        let viewModel = AirQualityViewModel(
            service: service,
            locationService: MockLocationService(result: .success(location))
        )

        viewModel.load()
        await waitUntil { viewModel.loadState == .loaded }

        let coordinates = await service.lastCoordinates
        XCTAssertEqual(coordinates?.latitude, location.latitude)
        XCTAssertEqual(coordinates?.longitude, location.longitude)
        XCTAssertEqual(viewModel.snapshot?.locationName, "부산광역시 중구")
        XCTAssertEqual(viewModel.snapshot?.windSpeed, 5.4)
        XCTAssertEqual(viewModel.snapshot?.windDirection, 225)
    }

    func testDeniedLocationPermissionShowsSettingsAction() async {
        let viewModel = AirQualityViewModel(
            service: MockAirQualityService(results: []),
            locationService: MockLocationService(result: .failure(.permissionDenied))
        )

        viewModel.load()
        await waitUntil {
            if case .failed = viewModel.loadState { return true }
            return false
        }

        XCTAssertTrue(viewModel.shouldShowLocationSettings)
        XCTAssertEqual(viewModel.errorMessage, LocationServiceError.permissionDenied.errorDescription)
    }

    private func makeViewModel(service: MockAirQualityService) -> AirQualityViewModel {
        AirQualityViewModel(
            service: service,
            locationService: MockLocationService(
                result: .success(
                    UserLocation(
                        latitude: 37.5665,
                        longitude: 126.9780,
                        displayName: "서울특별시 종로구"
                    )
                )
            )
        )
    }

    private func makeSnapshot() -> AirQualitySnapshot {
        AirQualitySnapshot(
            locationName: "서울특별시 종로구",
            measuredAt: "2026-08-04T12:00",
            temperature: 27,
            pm25: 8,
            uvIndex: 3,
            windSpeed: 3.5,
            windDirection: 90
        )
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let start = DispatchTime.now().uptimeNanoseconds
        while !condition(), DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), "제한 시간 안에 예상 상태가 되지 않았습니다.")
    }
}

private actor MockAirQualityService: AirQualityServiceProtocol {
    private var results: [Result<AirQualitySnapshot, AirQualityServiceError>]
    private let delayNanoseconds: UInt64
    private let ignoresCancellation: Bool
    private(set) var requestCount = 0
    private(set) var lastCoordinates: (latitude: Double, longitude: Double)?

    init(
        results: [Result<AirQualitySnapshot, AirQualityServiceError>],
        delayNanoseconds: UInt64 = 0,
        ignoresCancellation: Bool = false
    ) {
        self.results = results
        self.delayNanoseconds = delayNanoseconds
        self.ignoresCancellation = ignoresCancellation
    }

    func fetchCurrentAirQuality(latitude: Double, longitude: Double) async throws -> AirQualitySnapshot {
        requestCount += 1
        lastCoordinates = (latitude, longitude)
        guard !results.isEmpty else { throw AirQualityServiceError.weatherKitFailed }
        let result = results.removeFirst()
        if delayNanoseconds > 0 {
            if ignoresCancellation {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            } else {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            }
        }
        return try result.get()
    }
}

@MainActor
private final class MockLocationService: LocationServiceProtocol {
    private let result: Result<UserLocation, LocationServiceError>

    init(result: Result<UserLocation, LocationServiceError>) {
        self.result = result
    }

    func requestCurrentLocation() async throws -> UserLocation {
        try result.get()
    }

    func cancel() {}
}
