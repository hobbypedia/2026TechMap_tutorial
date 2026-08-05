import XCTest
@testable import PohangAirAR

@MainActor
final class AirQualityViewModelTests: XCTestCase {
    func testInitialStateIsIdle() {
        let viewModel = AirQualityViewModel(service: MockAirQualityService(results: []))
        XCTAssertEqual(viewModel.loadState, .idle)
        XCTAssertNil(viewModel.snapshot)
    }

    func testLoadShowsLoadingThenLoaded() async {
        let expected = makeSnapshot()
        let service = MockAirQualityService(results: [.success(expected)], delayNanoseconds: 30_000_000)
        let viewModel = AirQualityViewModel(service: service)

        viewModel.load()
        XCTAssertEqual(viewModel.loadState, .loading)
        await waitUntil { viewModel.loadState == .loaded }

        XCTAssertEqual(viewModel.snapshot, expected)
    }

    func testFailureAndRetry() async {
        let expected = makeSnapshot()
        let service = MockAirQualityService(results: [.failure(.networkFailed), .success(expected)])
        let viewModel = AirQualityViewModel(service: service)

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
        let viewModel = AirQualityViewModel(service: service)

        viewModel.load()
        viewModel.load()
        await waitUntil { viewModel.loadState == .loaded }

        let requestCount = await service.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testRefreshIgnoresCancelledRequestResult() async {
        let stale = AirQualitySnapshot(locationName: "포항", measuredAt: "이전", temperature: 30, pm25: 99, uvIndex: 9)
        let fresh = AirQualitySnapshot(locationName: "포항", measuredAt: "최신", temperature: 26, pm25: 7, uvIndex: 2)
        let service = MockAirQualityService(
            results: [.success(stale), .success(fresh)],
            delayNanoseconds: 60_000_000,
            ignoresCancellation: true
        )
        let viewModel = AirQualityViewModel(service: service)

        viewModel.load()
        try? await Task.sleep(nanoseconds: 5_000_000)
        viewModel.refresh()
        await waitUntil { viewModel.loadState == .loaded }

        XCTAssertEqual(viewModel.snapshot, fresh)
    }

    private func makeSnapshot() -> AirQualitySnapshot {
        AirQualitySnapshot(locationName: "포항", measuredAt: "2026-08-04T12:00", temperature: 27, pm25: 8, uvIndex: 3)
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
        guard !results.isEmpty else { throw AirQualityServiceError.networkFailed }
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
