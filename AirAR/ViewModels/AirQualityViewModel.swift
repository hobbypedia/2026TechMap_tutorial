import Combine
import Foundation

/// 현재 위치 확인, 환경 데이터 요청과 화면 상태를 관리합니다.
@MainActor
final class AirQualityViewModel: ObservableObject {
    @Published private(set) var loadState: AirQualityLoadState = .idle
    @Published private(set) var snapshot: AirQualitySnapshot?
    @Published private(set) var shouldShowLocationSettings = false

    private let service: any AirQualityServiceProtocol
    private let locationService: any LocationServiceProtocol
    private var loadTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(
        service: any AirQualityServiceProtocol = OpenMeteoAirQualityService(),
        locationService: (any LocationServiceProtocol)? = nil
    ) {
        self.service = service
        self.locationService = locationService ?? CoreLocationService()
    }

    /// View가 별도 포맷팅이나 상태 판정 없이 바로 표시할 수 있는 항목입니다.
    var metrics: [AirQualityMetricViewModel] {
        guard let snapshot else {
            return [
                placeholderMetric(id: .temperature, title: "온도", symbol: "thermometer.medium"),
                placeholderMetric(id: .pm25, title: "미세먼지", symbol: "aqi.medium"),
                placeholderMetric(id: .uvIndex, title: "UV", symbol: "sun.max.fill")
            ]
        }

        let pm25Level = AirQualityLevel.pm25(snapshot.pm25)
        let uvLevel = AirQualityLevel.uvIndex(snapshot.uvIndex)
        return [
            AirQualityMetricViewModel(
                id: .temperature,
                title: "온도",
                value: String(format: "%.1f°", snapshot.temperature),
                accessibilityValue: String(format: "섭씨 %.1f도", snapshot.temperature),
                symbol: "thermometer.medium",
                level: nil
            ),
            AirQualityMetricViewModel(
                id: .pm25,
                title: "미세먼지",
                value: String(format: "%.1f", snapshot.pm25),
                accessibilityValue: "\(pm25Level.title), "
                    + String(format: "%.1f 마이크로그램 퍼 세제곱미터", snapshot.pm25),
                symbol: "aqi.medium",
                level: pm25Level
            ),
            AirQualityMetricViewModel(
                id: .uvIndex,
                title: "UV",
                value: String(format: "%.1f", snapshot.uvIndex),
                accessibilityValue: "\(uvLevel.title), "
                    + String(format: "자외선 지수 %.1f", snapshot.uvIndex),
                symbol: "sun.max.fill",
                level: uvLevel
            )
        ]
    }

    var isLoading: Bool {
        loadState == .loading
    }

    var errorMessage: String? {
        guard case let .failed(message) = loadState else { return nil }
        return message
    }

    var locationName: String {
        if let snapshot {
            return snapshot.locationName
        }
        return isLoading ? "현재 위치 확인 중" : "현재 위치"
    }

    /// 최초 데이터를 불러옵니다. 이미 요청 중이면 중복 요청을 만들지 않습니다.
    func load() {
        guard loadTask == nil else { return }
        startLoad(cancellingCurrent: false)
    }

    /// 진행 중인 요청을 취소하고 최신 데이터를 다시 요청합니다.
    func refresh() {
        startLoad(cancellingCurrent: true)
    }

    /// 실패한 요청을 다시 시도합니다.
    func retry() {
        startLoad(cancellingCurrent: true)
    }

    /// 화면이 사라질 때 진행 중인 네트워크 작업을 정리합니다.
    func cancel() {
        loadTask?.cancel()
        locationService.cancel()
        loadTask = nil
    }

    private func startLoad(cancellingCurrent: Bool) {
        if cancellingCurrent {
            loadTask?.cancel()
            locationService.cancel()
        } else if loadTask != nil {
            return
        }

        requestGeneration += 1
        let generation = requestGeneration
        loadState = .loading
        shouldShowLocationSettings = false
        loadTask = Task { [weak self, service, locationService] in
            do {
                let location = try await locationService.requestCurrentLocation()
                let response = try await service.fetchCurrentAirQuality(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                let snapshot = AirQualitySnapshot(
                    locationName: location.displayName,
                    measuredAt: response.measuredAt,
                    temperature: response.temperature,
                    pm25: response.pm25,
                    uvIndex: response.uvIndex,
                    windSpeed: response.windSpeed,
                    windDirection: response.windDirection
                )
                guard !Task.isCancelled, self?.requestGeneration == generation else { return }
                self?.snapshot = snapshot
                self?.loadState = .loaded
            } catch let error as AirQualityServiceError where error == .cancelled {
                // 새로고침이나 화면 종료로 취소된 요청은 오류로 노출하지 않습니다.
            } catch is CancellationError {
                // 취소는 사용자에게 실패 상태로 표시하지 않습니다.
            } catch {
                guard !Task.isCancelled, self?.requestGeneration == generation else { return }
                if let locationError = error as? LocationServiceError {
                    self?.shouldShowLocationSettings = locationError == .permissionDenied
                        || locationError == .servicesDisabled
                }
                self?.loadState = .failed(
                    (error as? LocalizedError)?.errorDescription
                        ?? "환경 데이터를 불러오지 못했습니다."
                )
            }
            if self?.requestGeneration == generation {
                self?.loadTask = nil
            }
        }
    }

    private func placeholderMetric(
        id: AirQualityMetricViewModel.Kind,
        title: String,
        symbol: String
    ) -> AirQualityMetricViewModel {
        AirQualityMetricViewModel(
            id: id,
            title: title,
            value: "—",
            accessibilityValue: "불러오는 중",
            symbol: symbol,
            level: nil
        )
    }
}
